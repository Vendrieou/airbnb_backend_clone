import { useState } from "react";
import {
  OUTLETS, PRODUCTS, TIERS, getRow, setRow, hppOf, rp, pct, tierCalc, tone,
  type PriceRow, type Product, type Settings,
} from "@/lib/pricing";
import { HistDialog, PromoDialog, CustomDialog, toneCls } from "@/components/pricing/dialogs";

export default function PricingMatrixPage() {
  const [s, setS] = useState<Settings>({ basis: "last", beban: 2.5, komisi: 10, channel: "Offline" });
  const [q, setQ] = useState("");
  const [histP, setHistP] = useState<Product | null>(null);
  const [histRow, setHistRow] = useState<PriceRow | null>(null);
  const [promoCtx, setPromoCtx] = useState<{ product: Product; outlet: string } | null>(null);
  const [customOpen, setCustomOpen] = useState(false);
  const [customP, setCustomP] = useState<Product | null>(null);
  const [tick, setTick] = useState(0); // force re-render after edits (module-state demo)

  const list = PRODUCTS.filter((p) => !q || p.name.toLowerCase().includes(q.toLowerCase()) || p.sku.toLowerCase().includes(q.toLowerCase()));

  return (
    <div className="p-4">
      <div className="mb-3 flex flex-wrap items-center gap-3">
        <h1 className="text-lg font-semibold">Matriks Harga</h1>
        <label className="flex items-center gap-1 text-sm">Acuan HPP
          <select aria-label="Acuan HPP" className="h-8 rounded-md border border-input bg-card px-2 text-sm" value={s.basis} onChange={(e) => setS({ ...s, basis: e.target.value as Settings["basis"] })}>
            <option value="last">PO terakhir</option><option value="avg">Average sisa</option>
          </select></label>
        <input aria-label="Cari produk" className="h-8 rounded-md border border-input bg-card px-2 text-sm" placeholder="Cari produk…" value={q} onChange={(e) => setQ(e.target.value)} />
        <button onClick={() => { setCustomP(null); setCustomOpen(true); }} className="ml-auto rounded-md bg-primary px-3 py-1.5 text-sm font-medium text-primary-foreground">+ Atur Harga</button>
      </div>
      <div key={tick} className="overflow-x-auto">
        <table className="w-full min-w-[900px] text-sm num">
          <thead className="text-left text-xs text-muted-foreground"><tr className="border-b border-border">
            <th className="py-2">Produk</th>{OUTLETS.map((o) => <th key={o} className="text-right">{o}</th>)}<th></th></tr></thead>
          <tbody>{list.map((p) => { const hpp = hppOf(p, s.basis); return (
            <tr key={p.id} className="border-b border-border align-top">
              <td className="py-2"><div className="font-medium">{p.name}</div><div className="text-xs text-muted-foreground">{p.sku} · HPP {rp(hpp)}</div></td>
              {OUTLETS.map((o) => { const row = getRow(o, p.id); return (
                <td key={o} className="text-right">
                  <div className="grid grid-cols-5 gap-1">{row.hj.map((h, t) => { const c = tierCalc(h, hpp, s); return (
                    <button key={t} title={`${TIERS[t].label} ${rp(h)} · ${c ? pct(c.net) : "—"}`}
                      onClick={() => { setCustomP(p); setCustomOpen(true); }}
                      className={`rounded px-1 py-0.5 text-[11px] ${c ? (c.net < 0 ? "bg-bad-bg text-bad" : c.net < 5 ? "bg-warn-bg text-warn" : "bg-ok-bg text-ok") : "bg-none-bg text-muted-foreground"}`}>
                      {h == null ? "—" : `${Math.round(h / 1000)}k`}<br />{c ? <span className={toneCls[tone(c.net)]}>{c.net.toFixed(0)}%</span> : ""}
                    </button>); })}</div></td>); })}
              <td className="text-right whitespace-nowrap">
                <button className="rounded-md border border-border px-2 py-1 text-xs hover:bg-accent" onClick={() => { setHistP(p); setHistRow(getRow(OUTLETS[0], p.id)); }}>Riwayat</button>
                <button className="ml-1 rounded-md border border-border px-2 py-1 text-xs hover:bg-accent" onClick={() => setPromoCtx({ product: p, outlet: OUTLETS[0] })}>Permutasi</button>
              </td></tr>); })}</tbody>
        </table>
      </div>
      <HistDialog product={histP} s={s} row={histRow} onClose={() => setHistP(null)} />
      <PromoDialog ctx={promoCtx} s={s} setS={setS} getRow={getRow} onClose={() => setPromoCtx(null)} />
      <CustomDialog open={customOpen} initialProduct={customP} s={s} getRow={getRow} onClose={() => setCustomOpen(false)}
        onSubmit={(pid, outs, hj) => { outs.forEach((o) => setRow(o, pid, hj, false)); setTick((t) => t + 1); setCustomOpen(false); }} />
    </div>
  );
}
