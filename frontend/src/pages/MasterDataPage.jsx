import React, { useEffect, useMemo, useState, useCallback } from 'react';
import {
  getFloorGrid, createFloor, deleteFloor, createRoom, getRoom, updateRoom,
  getRoomSmartLock, installSmartLock, pairSmartLock, refreshSmartLock,
  setMasterPasscode, addMasterKey, revokeMasterKey, generateTempKey, revokeTempKey,
} from '../api/client.js';

// ===== helpers =====
const STATUS_COLOR = {
  available: '#22c55e', occupied: '#3b82f6', maintenance: '#f59e0b', out_of_order: '#ef4444',
};
const toLocalInput = (d) => {
  const p = new Date(d);
  const pad = (n) => String(n).padStart(2, '0');
  return `${p.getFullYear()}-${pad(p.getMonth() + 1)}-${pad(p.getDate())}T${pad(p.getHours())}:${pad(p.getMinutes())}`;
};

// ===== Modal Edit Detail Unit + Setup Smart Lock =====
function RoomDetailModal({ roomId, onClose, onChanged }) {
  const [room, setRoom] = useState(null);
  const [lock, setLock] = useState(null);
  const [tab, setTab] = useState('unit'); // unit | master_config | master_key | temp_key
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState(null);
  // form install device
  const [dev, setDev] = useState({ brand: 'seven_key', device_name: '', mac_address: '', device_trid: '', device_pass_code: '', device_api_key: '' });
  // form master config
  const [masterPin, setMasterPin] = useState('');
  // form master key
  const [mk, setMk] = useState({ key_type: 'rfid_card', name: '', identifier: '', pin_code: '', expires_on: '' });
  // form temp key
  const now = new Date();
  const tomorrowNoon = new Date(now.getTime() + 864e5);
  const [tk, setTk] = useState({ label: 'Guest', start_at: toLocalInput(now), end_at: toLocalInput(tomorrowNoon), times_limit: 20, kind: 'passcode' });
  const [lastCode, setLastCode] = useState(null);

  const reload = useCallback(async () => {
    const [r, l] = await Promise.all([getRoom(roomId), getRoomSmartLock(roomId)]);
    setRoom(r); setLock(l);
  }, [roomId]);
  useEffect(() => { reload().catch(e => setMsg({ err: e.message })); }, [reload]);

  const act = async (fn, okText) => {
    setBusy(true); setMsg(null);
    try { await fn(); if (okText) setMsg({ ok: okText }); await reload(); onChanged?.(); }
    catch (e) { setMsg({ err: e.response?.data?.error || e.response?.data?.errors?.join(', ') || e.message }); }
    finally { setBusy(false); }
  };

  if (!room) return <div className="modal-backdrop" onClick={onClose}><div className="modal">Memuat unit…</div></div>;

  const tabs = [
    ['unit', '🛏️ Data Unit'],
    ['master_config', '⚙️ Master Config'],
    ['master_key', '🗝️ Master Key'],
    ['temp_key', '🎟️ Temporary Key'],
  ];

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal modal-lg" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <h3>Edit Detail Unit — Kamar {room.room_number} <small>L{room.floor_number ?? '-'}</small></h3>
          <button className="btn-icon" onClick={onClose}>✕</button>
        </div>
        <div className="tabs">
          {tabs.map(([k, lbl]) => (
            <button key={k} className={`tab ${tab === k ? 'active' : ''}`} onClick={() => setTab(k)}>{lbl}</button>
          ))}
        </div>
        {msg && <div className={msg.ok ? 'flash ok' : 'flash err'}>{msg.ok || msg.err}</div>}

        {/* ---------- TAB 1: data unit ---------- */}
        {tab === 'unit' && (
          <div className="tab-body grid2">
            <label>Nomor Unit
              <input value={room.room_number} onChange={(e) => setRoom({ ...room, room_number: e.target.value })} />
            </label>
            <label>Status
              <select value={room.status} onChange={(e) => setRoom({ ...room, status: e.target.value })}>
                {Object.keys(STATUS_COLOR).map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </label>
            <label>Baris Grid <input type="number" min="1" value={room.grid_row} onChange={(e) => setRoom({ ...room, grid_row: +e.target.value })} /></label>
            <label>Kolom Grid <input type="number" min="1" value={room.grid_col} onChange={(e) => setRoom({ ...room, grid_col: +e.target.value })} /></label>
            <button disabled={busy} className="btn primary"
              onClick={() => act(() => updateRoom(room.id, { room_number: room.room_number, status: room.status, grid_row: room.grid_row, grid_col: room.grid_col }), 'Unit tersimpan.')}>
              💾 Simpan Unit
            </button>
          </div>
        )}

        {/* ---------- TAB 2: master config (device + pairing + master passcode) ---------- */}
        {tab === 'master_config' && (
          <div className="tab-body">
            {!lock ? (
              <div className="grid2">
                <h4>📱 Pasang Smart Lock (7EVEN KEY / TTLOCK)</h4>
                <label>Merek
                  <select value={dev.brand} onChange={(e) => setDev({ ...dev, brand: e.target.value })}>
                    <option value="seven_key">7EVEN KEY</option>
                    <option value="ttlock">TTLOCK</option>
                  </select>
                </label>
                <label>Nama Device <input placeholder="Lock Kamar 101" value={dev.device_name} onChange={(e) => setDev({ ...dev, device_name: e.target.value })} /></label>
                {dev.brand === 'seven_key' ? (
                  <label>MAC Address
                    <input placeholder="AA:BB:CC:DD:EE:FF" value={dev.mac_address} onChange={(e) => setDev({ ...dev, mac_address: e.target.value })} />
                  </label>
                ) : (
                  <>
                    <label>Device TRID <input value={dev.device_trid} onChange={(e) => setDev({ ...dev, device_trid: e.target.value })} /></label>
                    <label>Passcode Pairing <input maxLength="6" value={dev.device_pass_code} onChange={(e) => setDev({ ...dev, device_pass_code: e.target.value })} /></label>
                    <label>Server Key <input value={dev.device_api_key} onChange={(e) => setDev({ ...dev, device_api_key: e.target.value })} /></label>
                  </>
                )}
                <button disabled={busy} className="btn primary"
                  onClick={() => act(() => installSmartLock(roomId, dev), 'Device tersimpan. Jangan lupa Pairing.')}>
                  ➕ Simpan Device
                </button>
              </div>
            ) : (
              <div>
                <div className="lock-card">
                  <div><b>{lock.device_name || `Lock #${lock.id}`}</b> · {lock.brand === 'ttlock' ? 'TTLOCK' : '7EVEN KEY'}</div>
                  <div className="muted small">
                    {lock.mac_address || lock.device_trid} · Baterai: {lock.battery_level ?? '?'}% · {lock.online ? '🟢 online' : '⚪ offline'} · status: <b>{lock.status}</b>
                  </div>
                  <div className="row gap mt">
                    <button disabled={busy} className="btn" onClick={() => act(() => pairSmartLock(lock.id), 'Pairing berhasil ✔')}>🔗 Pairing</button>
                    <button disabled={busy} className="btn" onClick={() => act(() => refreshSmartLock(lock.id), 'Status disinkronkan.')}>🔄 Refresh</button>
                  </div>
                </div>
                <div className="grid2 mt">
                  <h4>Master Passcode (PIN Induk Lock)</h4>
                  <label>PIN baru (4–10 digit)
                    <input type="password" pattern="\d{4,10}" value={masterPin} onChange={(e) => setMasterPin(e.target.value)} />
                  </label>
                  <button disabled={busy || masterPin.length < 4} className="btn primary"
                    onClick={() => act(() => setMasterPasscode(lock.id, masterPin).then(() => setMasterPin('')), 'Master passcode dikirim ke lock.')}>
                    🔐 Set Master Passcode
                  </button>
                  <div className="muted small">Status saat ini: {lock.master_passcode_set ? '✅ sudah diset' : '❌ belum diset'}</div>
                </div>
              </div>
            )}
          </div>
        )}

        {/* ---------- TAB 3: master keys ---------- */}
        {tab === 'master_key' && (
          <div className="tab-body">
            {!lock ? <p className="muted">Pasang smart lock dulu di tab Master Config.</p> : (<>
              <div className="grid2">
                <label>Tipe Key
                  <select value={mk.key_type} onChange={(e) => setMk({ ...mk, key_type: e.target.value })}>
                    <option value="rfid_card">RFID Card</option>
                    <option value="pin">PIN</option>
                    <option value="fingerprint">Fingerprint</option>
                    <option value="app_ble">App BLE</option>
                  </select>
                </label>
                <label>Nama <input placeholder="Kartu Admin Lobi" value={mk.name} onChange={(e) => setMk({ ...mk, name: e.target.value })} /></label>
                {mk.key_type !== 'pin' && (
                  <label>Identifier (no. kartu) <input value={mk.identifier} onChange={(e) => setMk({ ...mk, identifier: e.target.value })} /></label>
                )}
                {mk.key_type === 'pin' && (
                  <label>PIN Code <input type="password" value={mk.pin_code} onChange={(e) => setMk({ ...mk, pin_code: e.target.value })} /></label>
                )}
                <label>Valid s/d <input type="date" value={mk.expires_on} onChange={(e) => setMk({ ...mk, expires_on: e.target.value })} /></label>
                <button disabled={busy || !mk.name} className="btn primary"
                  onClick={() => act(() => addMasterKey(lock.id, mk), 'Master key ditambahkan.')}>➕ Tambah Master Key</button>
              </div>
              <table className="tbl mt">
                <thead><tr><th>Nama</th><th>Tipe</th><th>ID</th><th>Exp</th><th>Status</th><th></th></tr></thead>
                <tbody>
                  {(lock.master_keys || []).map((k) => (
                    <tr key={k.id}>
                      <td>{k.name}</td><td>{k.key_type}</td><td>{k.identifier || k.pin_code_masked}</td>
                      <td>{k.expires_on || '-'}</td>
                      <td>{k.active ? '🟢 aktif' : '🔴 revoked'}</td>
                      <td>{k.active && <button disabled={busy} className="btn danger sm" onClick={() => act(() => revokeMasterKey(lock.id, k.id), 'Key dicabut.')}>Cabut</button>}</td>
                    </tr>
                  ))}
                  {!(lock.master_keys || []).length && <tr><td colSpan="6" className="muted">Belum ada master key.</td></tr>}
                </tbody>
              </table>
            </>)}
          </div>
        )}

        {/* ---------- TAB 4: temporary key / passcode generated ---------- */}
        {tab === 'temp_key' && (
          <div className="tab-body">
            {!lock ? <p className="muted">Pasang smart lock dulu di tab Master Config.</p> : (<>
              <div className="grid2">
                <label>Label <input value={tk.label} onChange={(e) => setTk({ ...tk, label: e.target.value })} /></label>
                <label>Jenis
                  <select value={tk.kind} onChange={(e) => setTk({ ...tk, kind: e.target.value })}>
                    <option value="passcode">Passcode (generated)</option>
                    <option value="ic_card">IC Card</option>
                  </select>
                </label>
                <label>Mulai <input type="datetime-local" value={tk.start_at} onChange={(e) => setTk({ ...tk, start_at: e.target.value })} /></label>
                <label>Selesai <input type="datetime-local" value={tk.end_at} onChange={(e) => setTk({ ...tk, end_at: e.target.value })} /></label>
                <label>Maks. buka pintu <input type="number" min="1" value={tk.times_limit} onChange={(e) => setTk({ ...tk, times_limit: +e.target.value })} /></label>
                <button disabled={busy} className="btn primary"
                  onClick={() => act(async () => {
                    const res = await generateTempKey(lock.id, {
                      ...tk, start_at: new Date(tk.start_at).toISOString(), end_at: new Date(tk.end_at).toISOString(),
                    });
                    setLastCode(res.temporary_key?.passcode || null);
                  }, 'Temporary key dibuat & disinkron ke lock.')}>
                  ⚡ Generate Temporary Key
                </button>
              </div>
              {lastCode && (
                <div className="passcode-box">
                  <div className="muted small">Passcode generated (aktif sesuai window):</div>
                  <div className="passcode">{lastCode}</div>
                  <div className="muted small">Bagikan via chat/WA ke guest 📲</div>
                </div>
              )}
              <table className="tbl mt">
                <thead><tr><th>Label</th><th>Window</th><th>Passcode</th><th>Pakai</th><th>Status</th><th></th></tr></thead>
                <tbody>
                  {(lock.temporary_keys || []).map((k) => (
                    <tr key={k.id}>
                      <td>{k.label}</td>
                      <td className="small">{new Date(k.start_at).toLocaleString('id-ID', { hour12: false })} → {new Date(k.end_at).toLocaleString('id-ID', { hour12: false })}</td>
                      <td><code>{k.passcode || k.ic_card_number || '••••••'}</code></td>
                      <td>{k.times_used}{k.times_limit ? `/${k.times_limit}` : ''}</td>
                      <td>{k.status}</td>
                      <td>{['active', 'synced'].includes(k.status) && <button disabled={busy} className="btn danger sm" onClick={() => act(() => revokeTempKey(lock.id, k.id), 'Passcode dicabut.')}>Cabut</button>}</td>
                    </tr>
                  ))}
                  {!(lock.temporary_keys || []).length && <tr><td colSpan="6" className="muted">Belum ada temporary key.</td></tr>}
                </tbody>
              </table>
            </>)}
          </div>
        )}
      </div>
    </div>
  );
}

// ===== Main page: GRID floor plan per lantai =====
export default function MasterDataPage() {
  const [hotelId, setHotelId] = useState(Number(localStorage.getItem('hotelId')) || 1);
  const [data, setData] = useState(null);
  const [err, setErr] = useState(null);
  const [activeFloor, setActiveFloor] = useState(null);
  const [editRoomId, setEditRoomId] = useState(null);
  const [showAddFloor, setShowAddFloor] = useState(false);
  const [showAddRoom, setShowAddRoom] = useState(false);
  const [floorForm, setFloorForm] = useState({ floor_number: '', floor_name: '' });
  const [roomForm, setRoomForm] = useState({ room_number: '', room_type_id: 1, status: 'available' });

  const load = useCallback(() => {
    getFloorGrid(hotelId).then((d) => {
      setData(d);
      setActiveFloor((cur) => cur ?? d.floors[0]?.id ?? null);
    }).catch((e) => setErr(e.response?.data?.error || e.message));
  }, [hotelId]);
  useEffect(() => { setData(null); setActiveFloor(null); load(); }, [load]);

  const floors = data?.floors || [];
  const floor = useMemo(() => floors.find((f) => f.id === activeFloor), [floors, activeFloor]);
  const maxCol = Math.max(8, ...(floor?.rooms || []).map((r) => r.grid_col || 1));
  const maxRow = Math.max(1, ...(floor?.rooms || []).map((r) => r.grid_row || 1));

  const submitFloor = async () => {
    try { await createFloor(hotelId, floorForm); setShowAddFloor(false); setFloorForm({ floor_number: '', floor_name: '' }); load(); }
    catch (e) { setErr(e.response?.data?.errors?.join(', ') || e.message); }
  };
  const submitRoom = async () => {
    try { await createRoom(hotelId, { ...roomForm, floor_id: activeFloor }); setShowAddRoom(false); setRoomForm({ room_number: '', room_type_id: 1, status: 'available' }); load(); }
    catch (e) { setErr(e.response?.data?.errors?.join(', ') || e.message); }
  };
  const removeFloor = async (f) => {
    if (!confirm(`Hapus lantai ${f.floor_number}?`)) return;
    try { await deleteFloor(f.id); load(); } catch (e) { alert(e.response?.data?.error || e.message); }
  };

  return (
    <div>
      <div className="page-head row between">
        <h2>🗂️ Master Data — Floor &amp; Unit Kamar</h2>
        <label className="inline">Hotel ID
          <input type="number" min="1" value={hotelId} onChange={(e) => setHotelId(+e.target.value)} style={{ width: 70 }} />
        </label>
      </div>
      {err && <div className="flash err" onClick={() => setErr(null)}>{err}</div>}

      {/* Tab lantai + tombol tambah floor */}
      <div className="floor-tabs">
        {floors.map((f) => (
          <button key={f.id} className={`floor-tab ${activeFloor === f.id ? 'active' : ''}`} onClick={() => setActiveFloor(f.id)}>
            L{f.floor_number}{f.floor_name ? ` · ${f.floor_name}` : ''} <span className="pill">{f.rooms_count}</span>
          </button>
        ))}
        <button className="floor-tab add" onClick={() => setShowAddFloor(true)}>＋ Tambah Floor</button>
      </div>

      {floor && (
        <div className="row between mt">
          <div className="legend">
            {Object.entries(STATUS_COLOR).map(([s, c]) => <span key={s}><i style={{ background: c }} /> {s.replace('_', ' ')}</span>)}
            <span>🔒 = punya smart lock</span>
          </div>
          <div className="row gap">
            <button className="btn sm" onClick={() => removeFloor(floor)}>🗑 Hapus Floor</button>
            <button className="btn primary sm" onClick={() => setShowAddRoom(true)}>＋ Tambah Unit di Lantai {floor.floor_number}</button>
          </div>
        </div>
      )}

      {/* GRID SYSTEM unit kamar */}
      {floor ? (
        <div className="room-grid" style={{ gridTemplateColumns: `repeat(${maxCol}, minmax(96px, 1fr))`, gridTemplateRows: `repeat(${maxRow}, minmax(96px, auto))` }}>
          {floor.rooms.map((r) => (
            <div key={r.id} className={`room-cell ${r.needs_housekeeping ? 'dirty' : ''}`}
              style={{ gridColumn: r.grid_col, gridRow: r.grid_row, borderTopColor: STATUS_COLOR[r.status] || '#999' }}
              title={`${r.room_type || ''} · klik utk edit detail`}
              onClick={() => setEditRoomId(r.id)}>
              <div className="rc-num">{r.room_number} {r.has_lock ? '🔒' : ''}</div>
              <div className="rc-type">{r.room_type || '-'}</div>
              <div className="rc-status" style={{ color: STATUS_COLOR[r.status] }}>{r.status.replace('_', ' ')}</div>
              {r.needs_housekeeping && <div className="rc-hk">🧹 HK</div>}
            </div>
          ))}
          {!floor.rooms.length && <div className="muted empty-cell">Belum ada unit di lantai ini. Klik "＋ Tambah Unit".</div>}
        </div>
      ) : <p className="muted">{data ? 'Belum ada lantai. Klik "＋ Tambah Floor".' : 'Memuat…'}</p>}

      {/* Modal tambah floor */}
      {showAddFloor && (
        <div className="modal-backdrop" onClick={() => setShowAddFloor(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h3>Tambah Floor</h3>
            <label>No. Lantai <input type="number" min="0" value={floorForm.floor_number} onChange={(e) => setFloorForm({ ...floorForm, floor_number: e.target.value })} /></label>
            <label>Nama (opsional) <input placeholder="Lantai Garden" value={floorForm.floor_name} onChange={(e) => setFloorForm({ ...floorForm, floor_name: e.target.value })} /></label>
            <div className="row gap mt">
              <button className="btn primary" disabled={!floorForm.floor_number} onClick={submitFloor}>Simpan</button>
              <button className="btn" onClick={() => setShowAddFloor(false)}>Batal</button>
            </div>
          </div>
        </div>
      )}

      {/* Modal tambah unit */}
      {showAddRoom && (
        <div className="modal-backdrop" onClick={() => setShowAddRoom(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h3>Tambah Unit di Lantai {floor?.floor_number}</h3>
            <label>Nomor Unit <input placeholder="101" value={roomForm.room_number} onChange={(e) => setRoomForm({ ...roomForm, room_number: e.target.value })} /></label>
            <label>Room Type ID <input type="number" min="1" value={roomForm.room_type_id} onChange={(e) => setRoomForm({ ...roomForm, room_type_id: +e.target.value })} /></label>
            <label>Status
              <select value={roomForm.status} onChange={(e) => setRoomForm({ ...roomForm, status: e.target.value })}>
                {Object.keys(STATUS_COLOR).map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </label>
            <div className="muted small">Posisi grid otomatis diisi kolom berikutnya.</div>
            <div className="row gap mt">
              <button className="btn primary" disabled={!roomForm.room_number} onClick={submitRoom}>Simpan</button>
              <button className="btn" onClick={() => setShowAddRoom(false)}>Batal</button>
            </div>
          </div>
        </div>
      )}

      {/* Modal edit detail unit + setup smart lock */}
      {editRoomId && <RoomDetailModal roomId={editRoomId} onClose={() => setEditRoomId(null)} onChanged={load} />}
    </div>
  );
}
