import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { createConsumer } from '@rails/actioncable';
import {
  getConversation, listConversations, sendMessage, markConversationRead,
  toggleWhatsappSync, waLink,
} from '../api/client.js';

// Centang status pengiriman ala WhatsApp: ✓ pending/sent, ✓✓ delivered, ✓✓ biru read
function Ticks({ status }) {
  if (status === 'read') return <span className="wa-ticks wa-ticks-read">✓✓</span>;
  if (status === 'delivered') return <span className="wa-ticks">✓✓</span>;
  if (status === 'sent') return <span className="wa-ticks">✓</span>;
  if (status === 'failed') return <span className="wa-ticks wa-ticks-fail">!</span>;
  return <span className="wa-ticks wa-ticks-muted">🕐</span>;
}

const fmtTime = (iso) =>
  new Date(iso).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });

export default function ChatPage() {
  const { id } = useParams();
  const nav = useNavigate();
  const [list, setList] = useState([]);
  const [conv, setConv] = useState(null);
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState('');
  const [peerTyping, setPeerTyping] = useState(false);
  const bottomRef = useRef(null);
  const typingTimer = useRef(null);

  // muat daftar percakapan
  useEffect(() => { listConversations().then(setList).catch(() => setList([])); }, [id]);

  // muat satu percakapan + tandai dibaca
  useEffect(() => {
    if (!id) return;
    let alive = true;
    getConversation(id).then((d) => {
      if (!alive) return;
      setConv(d.conversation);
      setMessages(d.messages || []);
      markConversationRead(id).catch(() => {});
    }).catch(() => setConv(null));
    return () => { alive = false; };
  }, [id]);

  // subscribe ActionCable utk realtime (pesan baru, centang, typing, read receipt)
  useEffect(() => {
    if (!id || !conv) return;
    const token = localStorage.getItem('token');
    const cable = createConsumer(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/cable?token=${token || ''}`);
    cableRef.current = null;
    const sub = cable.subscriptions.create(
      { channel: 'ConversationChannel', id: Number(id) },
      {
        received(payload) {
          if (payload.type === 'message.created' && payload.message) {
            const m = payload.message;
            setMessages((prev) => (prev.some((x) => x.id === m.id || (m.client_message_id && x.client_message_id === m.client_message_id))
              ? prev.map((x) => (x.id === m.id ? { ...x, ...m } : x))
              : [...prev, { mine: false, status: 'pending', ...m }]));
            setPeerTyping(false);
          } else if (payload.type === 'message.status') {
            setMessages((prev) => prev.map((x) =>
              x.id === payload.message_id ? { ...x, status: payload.status } : x));
          } else if (payload.type === 'typing') {
            if (String(payload.user_id) !== String(localStorage.getItem('userId'))) {
              setPeerTyping(payload.is_typing !== false);
            }
          } else if (payload.type === 'messages.read') {
            setMessages((prev) => prev.map((x) => (x.mine ? { ...x, status: 'read' } : x)));
          }
        },
      }
    );
    cableRef.current = sub;
    return () => { cableRef.current = null; cable.subscriptions.remove(sub); };
  }, [id, conv?.id]);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages, peerTyping]);

  const grouped = useMemo(() => messages, [messages]);

  const cableRef = useRef(null);
  const sendTyping = (isTyping) => {
    // broadcast lewat kanal ActionCable -> lawan bicara melihat "sedang mengetik…"
    try { cableRef.current?.perform('typing', { is_typing: isTyping }); } catch { /* noop */ }
  };

  const onDraftChange = (e) => {
    setDraft(e.target.value);
    clearTimeout(typingTimer.current);
    sendTyping(true);
    typingTimer.current = setTimeout(() => sendTyping(false), 1500);
  };

  const send = async (e) => {
    e.preventDefault();
    const body = draft.trim();
    if (!body || !conv) return;
    setDraft('');
    const clientMessageId = (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random());
    // optimistic bubble (satu centang jam) lalu diganti saat broadcast masuk
    setMessages((prev) => [...prev, {
      id: `tmp-${clientMessageId}`, client_message_id: clientMessageId,
      body, mine: true, status: 'pending', created_at: new Date().toISOString(),
    }]);
    try {
      const m = await sendMessage(conv.id, body, clientMessageId);
      setMessages((prev) => prev.map((x) => (x.client_message_id === clientMessageId ? { ...x, ...m } : x)));
    } catch {
      setMessages((prev) => prev.map((x) => (x.client_message_id === clientMessageId ? { ...x, status: 'failed' } : x)));
    }
  };

  const openWa = () => {
    const link = conv?.other_participant?.wa_link || waLink(conv?.other_participant?.phone);
    if (link) window.open(link, '_blank');
    else alert('Lawan bicara belum punya nomor WhatsApp.');
  };

  return (
    <div className="chat-layout">
      {/* Sidebar daftar chat */}
      <aside className="chat-sidebar">
        <h3>💬 Chat</h3>
        {list.length === 0 && <p className="muted">Belum ada percakapan. Buka sewa saya → Chat dengan host.</p>}
        {list.map((c) => (
          <button key={c.id}
                  className={`chat-item ${String(c.id) === String(id) ? 'active' : ''}`}
                  onClick={() => nav(`/chat/${c.id}`)}>
            <div className="chat-item-top">
              <strong>{c.other_participant?.name || 'Pengguna'}</strong>
              <small>{c.last_message_at ? fmtTime(c.last_message_at) : ''}</small>
            </div>
            <div className="chat-item-sub">
              <span className="muted">{c.last_message?.body || '—'}</span>
              {c.unread_count > 0 && <span className="badge wa-badge">{c.unread_count}</span>}
            </div>
            <small className="muted">{c.property?.name}</small>
          </button>
        ))}
      </aside>

      {/* Panel chat utama */}
      <section className="chat-main">
        {!conv ? (
          <div className="chat-empty"><p className="muted">Pilih percakapan untuk mulai chat 😊</p></div>
        ) : (
          <>
            <header className="chat-header">
              <div>
                <strong>{conv.other_participant?.name || 'Lawan bicara'}</strong>
                <div className="muted small">
                  {peerTyping ? <em className="wa-typing">sedang mengetik…</em> : conv.other_participant?.phone || ''}
                </div>
              </div>
              <div className="chat-actions">
                <label className="wa-toggle" title="Salinan pesan dikirim ke WhatsApp lawan bicara">
                  <input type="checkbox" checked={conv.whatsapp_enabled !== false}
                         onChange={async () => {
                           const updated = await toggleWhatsappSync(conv.id);
                           setConv((c) => ({ ...c, whatsapp_enabled: updated.whatsapp_enabled }));
                         }} /> WA sync
                </label>
                <button className="btn btn-wa" onClick={openWa}>Buka WhatsApp ↗</button>
              </div>
            </header>

            <div className="chat-bubbles">
              {grouped.map((m) => (
                <div key={m.id} className={`bubble-row ${m.mine ? 'mine' : 'theirs'}`}>
                  <div className={`bubble ${m.mine ? 'bubble-mine' : 'bubble-theirs'} ${m.message_type === 'system' ? 'bubble-system' : ''}`}>
                    <span>{m.body}</span>
                    <span className="bubble-meta">
                      {fmtTime(m.created_at)} {m.mine && <Ticks status={m.status} />}
                    </span>
                  </div>
                </div>
              ))}
              {peerTyping && <div className="bubble-row theirs"><div className="bubble bubble-theirs wa-dots"><span/><span/><span/></div></div>}
              <div ref={bottomRef} />
            </div>

            <form className="chat-input" onSubmit={send}>
              <input value={draft} onChange={onDraftChange} placeholder="Ketik pesan…" disabled={conv.status === 'blocked'} />
              <button type="submit" className="btn btn-primary" disabled={!draft.trim() || conv.status === 'blocked'}>Kirim ➤</button>
            </form>
          </>
        )}
      </section>
    </div>
  );
}
