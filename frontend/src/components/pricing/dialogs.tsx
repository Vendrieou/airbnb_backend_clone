import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import {
  CHANNELS, OUTLETS, PRODUCTS, TIERS, hppOf, pct, r100, rp, tierCalc, tone,
  type PriceRow, type Product, type Settings,
} from "@/lib/pricing";

export const toneCls = { ok: "text-ok", warn: "text-warn", bad: "text-bad" } as const;
const inp = "h-9 rounded-md border border-input bg-card px-2 text-sm num";

export function Modal({ open, onClose, title, children, wide }: { open: boolean; onClose: () => void; title: string; children: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current; if (!d) return;
    if (open && !d.open) d.showModal(); else if (!open && d.open) d.close();
  }, [open]);
  return (
    <dialog ref={ref} onClose={onClose} aria-label={title}
      className={`m-auto w-[calc(100%-1.5rem)] ${wide ? "max-w-5xl" : "max-w-3xl"} rounded-xl border border-border bg-card p-0 shadow-2xl`}>
      <div className="flex items-center justify-between border-b border-border px-5 py-3">
        <h2 className="font-semibold">{title}</h2>
        <button onClick={onClose} aria-label="Tutup" className="rounded-md px-2 py-1 text-muted-foreground hover:bg-accent">✕</button>
      </div>
      <div className="max-h-[75dvh] overflow-auto p-5">{open && children}</div>
    </dialog>
  );
}

export function HistDialog({ product, s, row, onClose }: { product: Product | null; s: Settings; row: PriceRow | null; onClose: () => void }) {
  const [loading, setLoading] = useState(true);
  useEffect(() => { setLoading(true); const t = setTimeout(() => setLoading(false), 400); return () => clearTimeout(t); }, [product]);
  const p = product;
  const acuanIdx = p ? (s.basis === "last" ? p.layers.length - 1 : -1) : -1;
  const lowest = row ? Math.min(...(row.hj.filter((h) => h != null) as number[])) : NaN;
  return (
    <Modal open={!!p} onClose={onClose} title={p ? `Riwayat Modal per PO — ${p.name}` : ""}>
      {p && (loading ? <p className="py-10 text-center text-muted-foreground" aria-live="polite">Memuat riwayat PO…</p> : (
        <div className="space-y-3">
          <p className="text-sm text-muted-foreground">PO terakhir <b className="num text-foreground">{rp(p.last)}</b> · Average sisa <b className="num text-foreground">{rp(p.std)}</b> · Acuan: {s.basis === "last" ? "PO terakhir" : "HPP average"}</p>
          <div className="overflow-x-auto"><table className="w-full text-sm num">
            <thead className="text-left text-muted-foreground"><tr className="border-b border-border">
              <th className="py-2">PO</th><th>Tanggal</th><th className="text-right">Qty</th><th className="text-right">Sisa</th><th className="text-right">Net/pcs</th><th className="text-right">vs HJ 1</th><th className="text-right">vs Terendah</th></tr></thead>
            <tbody>{p.layers.map((l, i) => {
              const h1 = row?.hj[0]; const m1 = h1 ? ((h1 - l.net) / h1) * 100 : NaN; const ml = ((lowest - l.net) / lowest) * 100;
              return (<tr key={l.po} className={`border-b border-border ${i === acuanIdx ? "bg-accent" : ""}`}>
                <td className="py-2 font-medium">{l.po}{i === acuanIdx && <span className="ml-1 text-xs text-accent-foreground">acuan</span>}</td>
                <td>{l.date}</td><td className="text-right">{l.qty}</td><td className="text-right">{l.sisa}</td><td className="text-right">{rp(l.net)}</td>
                <td className={`text-right ${toneCls[tone(m1)]}`}>{pct(m1)}</td><td className={`text-right ${toneCls[tone(ml)]}`}>{pct(ml)}</td></tr>);
            })}</tbody></table></div>
        </div>))}
    </Modal>
  );
}

type PermRow = { tier: number; hj: number; qty: number };

export function PromoDialog({ ctx, s, setS, getRow, onClose }: {
  ctx: { product: Product; outlet: string } | null; s: Settings; setS: (s: Settings) => void;
  getRow: (o: string, id: number) => PriceRow; onClose: () => void;
}) {
  const [rows, setRows] = useState<PermRow[]>([]);
  const [reseller, setReseller] = useState(s.channel === "Reseller");
  useEffect(() => {
    if (!ctx) return;
    const r = getRow(ctx.outlet, ctx.product.id);
    setRows(TIERS.filter((t) => r.hj[t.key] != null).map((t) => ({ tier: t.key, hj: r.hj[t.key]!, qty: t.min })));
    setReseller(s.channel === "Reseller");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ctx]);
  if (!ctx) return <Modal open={false} onClose={onClose} title="">{null}</Modal>;
  const hpp = hppOf(ctx.product, s.basis);
  let cumB = 0, cumQ = 0, totO = 0, totK = 0;
  const calc = rows.map((r) => {
    const omset = r.hj * r.qty; const beban = omset * (s.beban / 100); const kom = reseller ? omset * (s.komisi / 100) : 0;
    cumB += beban; cumQ += r.qty; totO += omset; totK += kom;
    const hppEff = hpp + (cumQ ? cumB / cumQ : 0);
    const komU = reseller ? r.hj * (s.komisi / 100) : 0;
    const laba = r.hj - hppEff - komU;
    return { omset, beban, kom, cumB, hppEff, gross: ((r.hj - hppEff) / r.hj) * 100, laba, net: (laba / r.hj) * 100 };
  });
  const upd = (i: number, k: keyof PermRow, v: number) => setRows(rows.map((r, j) => (j === i ? { ...r, [k]: v } : r)));
  return (
    <Modal wide open onClose={onClose} title={`Lihat Perhitungan — ${ctx.product.name} · ${ctx.outlet}`}>
      <div className="space-y-4">
        <div className="flex flex-wrap items-end gap-3 text-sm">
          <label className="flex flex-col gap-1">Beban permutasi (%)<input aria-label="Beban permutasi persen" type="number" step="0.1" className={inp} value={s.beban} onChange={(e) => setS({ ...s, beban: +e.target.value })} /></label>
          <label className="flex flex-col gap-1">Komisi reseller (%)<input aria-label="Komisi reseller persen" type="number" step="0.1" className={inp} value={s.komisi} onChange={(e) => setS({ ...s, komisi: +e.target.value })} /></label>
          <label className="flex h-9 items-center gap-2"><input type="checkbox" checked={reseller} onChange={(e) => setReseller(e.target.checked)} /> Channel Reseller</label>
          <span className="ml-auto text-muted-foreground">HPP dasar ({s.basis === "last" ? "PO terakhir" : "average"}): <b className="num text-foreground">{rp(hpp)}</b></span>
        </div>
        <div className="overflow-x-auto"><table className="w-full min-w-[900px] text-sm num">
          <thead className="text-left text-xs text-muted-foreground"><tr className="border-b border-border">
            <th className="py-2">Tingkat</th><th>Harga jual</th><th>Qty</th><th className="text-right">Omset</th><th className="text-right">Beban {s.beban}%</th><th className="text-right">Σ Beban</th>
            <th className="text-right">HPP efektif</th>{reseller && <th className="text-right">Komisi {s.komisi}%</th>}<th className="text-right">Margin kotor</th><th className="text-right">Laba/unit</th><th className="text-right">Margin bersih</th><th></th></tr></thead>
          <tbody>{rows.map((r, i) => { const c = calc[i]; return (
            <tr key={i} className="border-b border-border">
              <td className="py-1.5"><select aria-label="Tingkat harga" className={inp} value={r.tier} onChange={(e) => upd(i, "tier", +e.target.value)}>{TIERS.map((t) => <option key={t.key} value={t.key}>{t.label} {t.name}</option>)}</select></td>
              <td><input aria-label="Harga jual" type="number" className={`${inp} w-28`} value={r.hj} onChange={(e) => upd(i, "hj", +e.target.value)} /></td>
              <td><input aria-label="Qty permutasi" type="number" className={`${inp} w-20`} value={r.qty} onChange={(e) => upd(i, "qty", +e.target.value)} /></td>
              <td className="text-right">{rp(r100(c.omset))}</td><td className="text-right">{rp(r100(c.beban))}</td><td className="text-right">{rp(r100(c.cumB))}</td>
              <td className="text-right font-medium">{rp(r100(c.hppEff))}</td>{reseller && <td className="text-right">{rp(r100(c.kom))}</td>}
              <td className={`text-right ${toneCls[tone(c.gross)]}`}>{pct(c.gross)}</td><td className={`text-right ${toneCls[tone(c.net)]}`}>{rp(r100(c.laba))}</td>
              <td className={`text-right font-semibold ${toneCls[tone(c.net)]}`}>{pct(c.net)}</td>
              <td><button aria-label="Hapus baris" onClick={() => setRows(rows.filter((_, j) => j !== i))} className="px-2 text-bad">✕</button></td></tr>); })}</tbody>
          <tfoot><tr className="font-semibold"><td className="py-2" colSpan={3}>
            <button onClick={() => setRows([...rows, { tier: 0, hj: rows[0]?.hj ?? r100(hpp * 1.2), qty: 1 }])} className="rounded-md border border-border px-3 py-1 text-sm hover:bg-accent">+ Tambah baris</button></td>
            <td className="text-right">{rp(r100(totO))}</td><td className="text-right" colSpan={3}>{rp(r100(cumB))}</td>{reseller && <td className="text-right">{rp(r100(totK))}</td>}<td colSpan={4}></td></tr></tfoot>
        </table></div>
        <div>
          <h3 className="mb-2 text-sm font-semibold">Dampak per cabang (HJ 1–5, margin bersih)</h3>
          <div className="grid gap-2 sm:grid-cols-2">{OUTLETS.map((o) => { const row = getRow(o, ctx.product.id); return (
            <div key={o} className="rounded-lg border border-border p-3 text-sm"><div className="mb-1 font-medium">{o}</div>
              <div className="grid grid-cols-5 gap-1 num">{row.hj.map((h, t) => { const c = tierCalc(h, hpp, s, reseller); return (
                <div key={t} className={`rounded px-1 py-0.5 text-center text-xs ${c ? (c.net < 0 ? "bg-bad-bg text-bad" : c.net < 5 ? "bg-warn-bg text-warn" : "bg-ok-bg text-ok") : "bg-none-bg text-muted-foreground"}`}>
                  {TIERS[t].label}<br />{c ? pct(c.net) : "—"}</div>); })}</div></div>); })}</div>
        </div>
      </div>
    </Modal>
  );
}

type Mode = "nominal" | "diskon" | "margin";
export function CustomDialog({ open, initialProduct, s, getRow, onClose, onSubmit }: {
  open: boolean; initialProduct: Product | null; s: Settings; getRow: (o: string, id: number) => PriceRow;
  onClose: () => void; onSubmit: (pid: number, outlets: string[], hj: (number | null)[], channel: string) => void;
}) {
  const [pid, setPid] = useState<number | null>(null);
  const [q, setQ] = useState(""); const [showList, setShowList] = useState(false);
  const [outs, setOuts] = useState<string[]>([OUTLETS[0]]);
  const [channel, setChannel] = useState(s.channel === "Semua" ? "Offline" : s.channel);
  const [mode, setMode] = useState<Mode>("nominal");
  const [vals, setVals] = useState<string[]>(["", "", "", "", ""]);
  useEffect(() => { if (open) { setPid(initialProduct?.id ?? null); setQ(initialProduct?.name ?? ""); setVals(["", "", "", "", ""]); } }, [open, initialProduct]);
  const p = PRODUCTS.find((x) => x.id === pid) ?? null;
  const list = useMemo(() => { const t = q.toLowerCase(); return PRODUCTS.filter((x) => x.name.toLowerCase().includes(t) || x.sku.toLowerCase().includes(t) || x.bc.includes(t)).slice(0, 8); }, [q]);
  const hpp = p ? hppOf(p, s.basis) : 0;
  const cur = p ? getRow(outs[0] ?? OUTLETS[0], p.id) : null;
  const sx = { ...s, channel };
  const newHj = TIERS.map((t, i) => {
    const v = parseFloat(vals[i]); if (!p || isNaN(v)) return cur?.hj[i] ?? null;
    if (mode === "nominal") return r100(v);
    if (mode === "diskon") return cur?.hj[i] != null ? r100(cur.hj[i]! * (1 - v / 100)) : null;
    const k = channel === "Reseller" ? s.komisi : 0; return r100(hpp / (1 - (v + s.beban + k) / 100));
  });
  const calcs = newHj.map((h) => tierCalc(h, hpp, sx));
  const rejected = calcs.some((c) => c && c.net < 0) || !p || outs.length === 0;
  return (
    <Modal wide open={open} onClose={onClose} title="Atur Harga">
      <div className="space-y-4 text-sm">
        <div className="relative">
          <label className="mb-1 block font-medium" htmlFor="cb">Produk</label>
          <input id="cb" role="combobox" aria-expanded={showList} aria-controls="cb-list" className={`${inp} w-full`} placeholder="Cari nama / SKU / barcode"
            value={q} onChange={(e) => { setQ(e.target.value); setShowList(true); }} onFocus={() => setShowList(true)} onBlur={() => setTimeout(() => setShowList(false), 150)} />
          {showList && <ul id="cb-list" role="listbox" className="absolute z-10 mt-1 w-full rounded-md border border-border bg-popover shadow-lg">
            {list.map((x) => <li key={x.id} role="option" aria-selected={x.id === pid} onMouseDown={() => { setPid(x.id); setQ(x.name); setShowList(false); }}
              className="cursor-pointer px-3 py-2 hover:bg-accent">{x.name} <span className="text-xs text-muted-foreground">{x.sku}</span></li>)}</ul>}
        </div>
        <div className="flex flex-wrap gap-4">
          <fieldset><legend className="mb-1 font-medium">Outlet</legend><div className="flex flex-wrap gap-2">{OUTLETS.map((o) => (
            <label key={o} className="flex items-center gap-1 rounded-md border border-border px-2 py-1"><input type="checkbox" checked={outs.includes(o)}
              onChange={(e) => setOuts(e.target.checked ? [...outs, o] : outs.filter((x) => x !== o))} />{o}</label>))}</div></fieldset>
          <label className="flex flex-col gap-1 font-medium">Channel<select className={inp} value={channel} onChange={(e) => setChannel(e.target.value)}>{CHANNELS.map((c) => <option key={c}>{c}</option>)}</select></label>
        </div>
        <div role="radiogroup" aria-label="Cara isi harga" className="flex gap-2">{([["nominal", "Nominal tetap"], ["diskon", "Diskon %"], ["margin", "Template margin %"]] as [Mode, string][]).map(([m, l]) => (
          <button key={m} role="radio" aria-checked={mode === m} onClick={() => setMode(m)}
            className={`rounded-md border px-3 py-1.5 ${mode === m ? "border-primary bg-accent text-accent-foreground" : "border-border"}`}>{l}</button>))}</div>
        {p && <div className="overflow-x-auto"><table className="w-full min-w-[720px] num">
          <thead className="text-left text-xs text-muted-foreground"><tr className="border-b border-border"><th className="py-2">Tingkat</th><th>Harga sekarang</th><th>Input</th><th className="text-right">Harga baru</th><th className="text-right">HPP efektif</th><th className="text-right">Margin bersih</th><th className="text-right">Validasi</th></tr></thead>
          <tbody>{TIERS.map((t, i) => { const c = calcs[i]; return (
            <tr key={t.key} className="border-b border-border"><td className="py-1.5">{t.label} · {t.name} <span className="text-xs text-muted-foreground">≥{t.min}</span></td>
              <td>{rp(cur?.hj[i])}</td>
              <td><input aria-label={`Input ${t.label}`} type="number" className={`${inp} w-28`} placeholder={mode === "nominal" ? "Rp" : "%"} value={vals[i]} onChange={(e) => setVals(vals.map((v, j) => (j === i ? e.target.value : v)))} /></td>
              <td className="text-right font-medium">{rp(newHj[i])}</td><td className="text-right">{c ? rp(r100(c.hppEff)) : "—"}</td>
              <td className={`text-right ${c ? toneCls[tone(c.net)] : ""}`}>{c ? pct(c.net) : "—"}</td>
              <td className="text-right">{c ? (c.net < 0 ? <span className="rounded bg-bad-bg px-2 py-0.5 text-xs text-bad">Ditolak</span> : <span className="rounded bg-ok-bg px-2 py-0.5 text-xs text-ok">Lolos</span>) : <span className="text-xs text-muted-foreground">Belum di-set</span>}</td></tr>); })}</tbody></table></div>}
        <div className="flex items-center justify-end gap-2 border-t border-border pt-3">
          <span className="mr-auto text-muted-foreground" aria-live="polite">{!p ? "Pilih produk dahulu." : rejected ? "Ada tingkat harga yang rugi — perbaiki sebelum mengajukan." : `Siap diajukan untuk ${outs.length} outlet.`}</span>
          <button onClick={onClose} className="rounded-md border border-border px-4 py-2">Batal</button>
          <button disabled={rejected} onClick={() => p && onSubmit(p.id, outs, newHj, channel)} className="rounded-md bg-primary px-4 py-2 font-medium text-primary-foreground disabled:opacity-50">Ajukan approval</button>
        </div>
      </div>
    </Modal>
  );
}
