import React, { useEffect, useState } from 'react';
import { listRentalPlans, installmentEstimate, createRentalBooking, formatIDR, PERIOD_LABEL } from '../api/client.js';

export default function RentalPlansPage() {
  const [period, setPeriod] = useState('');
  const [onlyInstallment, setOnlyInstallment] = useState(false);
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState(null); // plan yg dibuka form bookingnya

  useEffect(() => {
    setLoading(true);
    listRentalPlans({ period: period || undefined, installments: onlyInstallment ? 'true' : undefined })
      .then((d) => setPlans(Array.isArray(d) ? d : d.data || d.rental_plans || []))
      .finally(() => setLoading(false));
  }, [period, onlyInstallment]);

  return (
    <div>
      <div className="card row">
        <strong>Periode sewa:</strong>
        {['', 'daily', 'weekly', 'monthly'].map((p) => (
          <button key={p} className={period === p ? '' : 'secondary'} onClick={() => setPeriod(p)}>
            {p === '' ? 'Semua' : PERIOD_LABEL[p]}
          </button>
        ))}
        <label className="row">
          <input type="checkbox" checked={onlyInstallment} onChange={(e) => setOnlyInstallment(e.target.checked)} />
          Bisa dicicil saja
        </label>
      </div>

      {loading && <p className="muted">Memuat paket sewa…</p>}
      <div className="grid">
        {!loading && plans.map((plan) => (
          <div className="card" key={plan.id}>
            <span className={`badge ${plan.period}`}>{PERIOD_LABEL[plan.period]}</span>
            {plan.installment_enabled && <span className="badge cicil">💳 Cicilan {plan.installment_count}x</span>}
            <h3 style={{ margin: '8px 0' }}>{plan.name}</h3>
            <p style={{ fontSize: 22, fontWeight: 700 }}>{formatIDR(plan.price)}</p>
            <p className="muted">per {plan.period === 'daily' ? 'hari' : plan.period === 'weekly' ? 'minggu' : 'bulan'}</p>
            <button onClick={() => setSelected(plan)}>Sewa Sekarang</button>
          </div>
        ))}
      </div>

      {selected && <BookingModal plan={selected} onClose={() => setSelected(null)} />}
    </div>
  );
}

function BookingModal({ plan, onClose }) {
  const [startDate, setStartDate] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [installments, setInstallments] = useState(plan.installment_enabled);
  const [estimate, setEstimate] = useState(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    if (!startDate) return;
    installmentEstimate(plan.id, { start_date: startDate, quantity })
      .then(setEstimate).catch(() => setEstimate(null));
  }, [plan.id, startDate, quantity]);

  const submit = async () => {
    setBusy(true); setMsg('');
    try {
      const key = crypto.randomUUID();
      const res = await createRentalBooking(plan.id, {
        start_date: startDate, quantity, pay_in_installments: installments,
      }, key);
      setMsg('✅ Booking dibuat! Cek halaman "Sewa Saya".');
      setTimeout(onClose, 1500);
    } catch (e) {
      setMsg('❌ ' + (e.response?.data?.error || e.message));
    } finally { setBusy(false); }
  };

  return (
    <div className="card" style={{ border: '2px solid #1f5bd8' }}>
      <h3>Booking: {plan.name}</h3>
      <div className="row" style={{ marginTop: 10 }}>
        <label>Tanggal mulai <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} /></label>
        <label>Jumlah ({plan.period === 'daily' ? 'hari' : plan.period === 'weekly' ? 'minggu' : 'bulan'})
          <input type="number" min="1" value={quantity} onChange={(e) => setQuantity(+e.target.value)} style={{ width: 70 }} />
        </label>
        {plan.installment_enabled && (
          <label><input type="checkbox" checked={installments} onChange={(e) => setInstallments(e.target.checked)} /> Bayar dicicil</label>
        )}
      </div>

      {estimate && (
        <table style={{ marginTop: 12 }}>
          <tbody>
            <tr><td>Total</td><td><b>{formatIDR(estimate.total_amount)}</b></td></tr>
            {installments && <>
              <tr><td>Uang muka (DP)</td><td>{formatIDR(estimate.upfront_amount)}</td></tr>
              {(estimate.installments || []).map((i) => (
                <tr key={i.number}><td>Angsuran #{i.number}</td><td>{formatIDR(i.amount)} — jatuh tempo {i.due_date}</td></tr>
              ))}
            </>}
          </tbody>
        </table>
      )}
      <p className="muted">{msg}</p>
      <div className="row" style={{ marginTop: 10 }}>
        <button onClick={submit} disabled={!startDate || busy}>{busy ? 'Memproses…' : 'Konfirmasi Booking'}</button>
        <button className="secondary" onClick={onClose}>Batal</button>
      </div>
    </div>
  );
}
