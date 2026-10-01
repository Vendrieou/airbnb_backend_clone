import React, { useEffect, useState, useCallback } from 'react';
import { listBoards, getBoard, advanceTask, uploadTaskImage } from '../api/client.js';

const COLUMNS = ['draft', 'todo', 'in_progress', 'review', 'done'];
const COL_LABEL = { draft: '📝 Draft', todo: '📋 To Do', in_progress: '🧹 Dikerjakan', review: '🔍 Review', done: '✅ Selesai' };

export default function HousekeepingBoardPage() {
  const [boards, setBoards] = useState([]);
  const [boardId, setBoardId] = useState(null);
  const [tasks, setTasks] = useState([]);
  const [err, setErr] = useState('');

  useEffect(() => {
    listBoards().then((d) => {
      const arr = Array.isArray(d) ? d : d.boards || d.data || [];
      setBoards(arr);
      if (arr[0]) setBoardId(arr[0].id);
    }).catch((e) => setErr(e.message));
  }, []);

  const load = useCallback(() => {
    if (!boardId) return;
    getBoard(boardId).then((d) => setTasks(d.tasks || d.board?.tasks || [])).catch((e) => setErr(e.message));
  }, [boardId]);

  // auto-refresh tiap 15 dtk: task baru dari scan checkout H-3 muncul otomatis
  useEffect(() => {
    if (!boardId) return;
    load();
    const t = setInterval(load, 15000);
    return () => clearInterval(t);
  }, [boardId, load]);

  const move = async (task) => {
    try { await advanceTask(task.id); load(); }
    catch (e) { setErr('❌ ' + (e.response?.data?.error || 'Gagal pindah kolom (review/done wajib upload foto?)')); }
  };

  const upload = async (task, file) => {
    try { await uploadTaskImage(task.id, file); load(); }
    catch (e) { setErr('❌ Upload gagal: ' + (e.response?.data?.error || e.message)); }
  };

  return (
    <div>
      <div className="card row">
        <strong>Kanban Housekeeping</strong>
        <select value={boardId || ''} onChange={(e) => setBoardId(Number(e.target.value))}>
          {boards.map((b) => <option key={b.id} value={b.id}>{b.name || `Board #${b.id}`}</option>)}
        </select>
        <span className="muted">Kartu oranye = tugas otomatis (checkout tidak diperpanjang setelah H-3)</span>
      </div>
      {err && <p className="muted" style={{ color: '#c0392b' }}>{err}</p>}

      <div className="kanban">
        {COLUMNS.map((col) => (
          <div className="column" key={col}>
            <h3>{COL_LABEL[col]} ({tasks.filter((t) => t.status === col).length})</h3>
            {tasks.filter((t) => t.status === col).map((t) => (
              <div key={t.id} className={`task ${t.source === 'auto_checkout' ? 'auto' : ''}`}>
                <b>{t.title}</b>
                <div className="muted">{t.room_label || t.property_name || ''} {t.due_date ? `· due ${t.due_date}` : ''}</div>
                {(t.attachments || []).slice(0, 3).map((a) => (
                  <img key={a.id} src={a.url} alt="" style={{ width: 48, height: 48, objectFit: 'cover', borderRadius: 6, margin: '4px 4px 0 0' }} />
                ))}
                <div className="row" style={{ marginTop: 6 }}>
                  {col !== 'done' && col !== 'cancelled' && (
                    <button className="secondary" onClick={() => move(t)}>→ {COL_LABEL[COLUMNS[COLUMNS.indexOf(col) + 1]]?.split(' ')[1] || 'Lanjut'}</button>
                  )}
                  {['in_progress', 'review'].includes(col) && (
                    <label className="secondary" style={{ background: '#e8ebf2', color: '#333', padding: '8px 12px', borderRadius: 8, cursor: 'pointer' }}>
                      📷 Foto
                      <input type="file" accept="image/*" hidden onChange={(e) => e.target.files[0] && upload(t, e.target.files[0])} />
                    </label>
                  )}
                </div>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
