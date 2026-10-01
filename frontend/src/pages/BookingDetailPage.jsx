import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { getRentalBooking, payRentalBooking, cancelRentalBooking, formatIDR } from '../api/client.js';

export default function BookingDetailPage() {
  const { id } = useParams();
  const [booking, setBooking] = useState(null);
  const [amount, setAmount] = useState('');
  const [msg, setMsg] = useState('');

  const reload = () => getRentalBooking(id).then((d) => setBooking(d.booking || d));
  useEffect(() => { reload(); }, [id]);

  if (!booking) return <p className="muted">Memuat…</p>;

  const pay = async () => {
    setMsg('');
    try {
      await payRentalBooking(id, { amount: Number(amount), payment_method: 'transfer' });
      setMsg('✅ Pembayaran dicatat.'); setAmount(''); reload();
    } catch (e) { setMsg('❌ ' + (e.response?.data?.error || e.message)); }
  };

  const cancel = async () => {
    if (!confirm('Batalkan sewa ini?')) return;
    await cancelRentalBooking(id); reload();
  };

  const inst = booking.installments || [];
  const nextUnpaid = inst.find((i) => i.status !== 'paid');

  return (
    <div>
      <div className="card">
        <h3>Sewa #{booking.id} — {booking.plan_name || ''}</h3>
        <p className="muted">{booking.start_date} → {booking.end_date} · status: <b>{booking.status}</b> · pembayaran: <b>{booking.payment_status}</b></p>
        <p style={{ fontSize: 20, marginTop: 8 }}>Total: <b>{formatIDR(booking.total_amount)}</b> · DP: {formatIDR(booking.upfront_amount)}</p>

        <div className="row" style={{ marginTop: 12 }}>
          <input type="number" placeholder={nextUnpaid ? `Bayar ${formatIDR(nextUnpaid.amount)}` : 'Jumlah'} value={amount} onChange={(e) => setAmount(e.target.value)} style={{ width: 180 }} />
          <button onClick={pay} disabled={!amount}>💳 Bayar {nextUnpaid ? `Angsuran #${nextUnpaid.number}` : 'DP / Pelunasan'}</button>
          {!['completed', 'cancelled'].includes(booking.status) && <button className="secondary" onClick={cancel}>Batalkan</button>}
        </div>
        <p className="muted">{msg}</p>
      </div>

      {inst.length > 0 && (
        <div className="card">
          <h4>Jadwal Cicilan</h4>
          <table>
            <thead><tr><th>#</th><th>Nominal</th><th>Jatuh Tempo</th><th>Status</th></tr></thead>
            <tbody>
              {inst.map((i) => (
                <tr key={i.id || i.number}>
                  <td>{i.number}</td><td>{formatIDR(i.amount)}</td><td>{i.due_date}</td>
                  <td>{i.status === 'paid' ? '✅ Lunas' : i.status === 'overdue' ? '⚠️ Terlambat' : '⏳ Pending'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
