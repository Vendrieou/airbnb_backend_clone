import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { listMyRentalBookings, formatIDR } from '../api/client.js';

const STATUS = {
  pending_payment: ['Menunggu Pembayaran', '#e67e22'],
  confirmed: ['Terkonfirmasi', '#1f5bd8'],
  active: ['Sedang Berlangsung', '#1c7d3e'],
  completed: ['Selesai', '#77808d'],
  cancelled: ['Dibatalkan', '#c0392b'],
};

export default function MyBookingsPage() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    listMyRentalBookings()
      .then((d) => setRows(Array.isArray(d) ? d : d.data || d.rental_bookings || []))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p className="muted">Memuat…</p>;
  if (!rows.length) return <div className="card">Belum ada sewa. <Link to="/"><b>Cari paket sewa →</b></Link></div>;

  return (
    <div className="card">
      <h3>Sewa Saya</h3>
      <table>
        <thead><tr><th>Paket</th><th>Tanggal</th><th>Total</th><th>Pembayaran</th><th>Status</th><th /></tr></thead>
        <tbody>
          {rows.map((b) => {
            const [label, color] = STATUS[b.status] || [b.status, '#333'];
            return (
              <tr key={b.id}>
                <td>{b.plan_name || `#${b.rental_plan_id}`}</td>
                <td>{b.start_date} → {b.end_date}</td>
                <td>{formatIDR(b.total_amount)}</td>
                <td>{b.payment_status}</td>
                <td><span style={{ color, fontWeight: 600 }}>{label}</span></td>
                <td><Link to={`/bookings/${b.id}`}><button className="secondary">Detail & Cicilan</button></Link></td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
