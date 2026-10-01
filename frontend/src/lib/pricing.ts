// ── Master data & kalkulasi harga (contoh domain pricing; ganti dengan API kamu) ──
export type PoLayer = { po: string; date: string; qty: number; sisa: number; net: number };
export type Product = { id: number; name: string; sku: string; bc: string; last: number; std: number; layers: PoLayer[] };
export type Tier = { key: number; label: string; name: string; min: number };
export type PriceRow = { outlet: string; product_id: number; hj: (number | null)[] };
export type Settings = { basis: "last" | "avg"; beban: number; komisi: number; channel: string };
export type Calc = { omset: number; beban: number; hppEff: number; gross: number; laba: number; net: number };

export const CHANNELS = ["Semua", "Offline", "Online", "Reseller"];
export const OUTLETS = ["Pusat", "Cabang A", "Cabang B", "Gudang"];
export const TIERS: Tier[] = [
  { key: 0, label: "HJ 1", name: "Normal", min: 1 },
  { key: 1, label: "HJ 2", name: "Member", min: 5 },
  { key: 2, label: "HJ 3", name: "Distributor", min: 20 },
  { key: 3, label: "HJ 4", name: "Sub-Dist", min: 50 },
  { key: 4, label: "HJ 5", name: "Project", min: 100 },
];

const mk = (id: number, name: string, sku: string, bc: string, last: number, std: number): Product => ({
  id, name, sku, bc, last, std,
  layers: [
    { po: `PO-${id}01`, date: "2026-06-10", qty: 200, sisa: 40, net: Math.round(last * 0.97) },
    { po: `PO-${id}02`, date: "2026-07-15", qty: 300, sisa: 120, net: Math.round(std) },
    { po: `PO-${id}03`, date: "2026-09-01", qty: 250, sisa: 250, net: last },
  ],
});

export const PRODUCTS: Product[] = [
  mk(1, "Kopi Bubuk 250g", "KPI-250", "8991001", 42000, 40500),
  mk(2, "Gula Aren 1kg", "GLA-1K", "8991002", 28000, 26800),
  mk(3, "Teh Celup isi 25", "TEH-25", "8991003", 19500, 18900),
  mk(4, "Santan Kara 65ml", "STN-65", "8991004", 9800, 9400),
];

export const r100 = (n: number) => Math.round(n / 100) * 100;

const grid: Record<string, (number | null)[]> = {
  Pusat:     [null, null, null, null, null],
  "Cabang A": [null, null, null, null, null],
  "Cabang B": [null, null, null, null, null],
  Gudang:    [null, null, null, null, null],
};
PRODUCTS.forEach((p, i) => {
  OUTLETS.forEach((o, j) => {
    grid[o][i] = r100(p.last * (1.25 - i * 0.02 - j * 0.01));
  });
});
// sengaja: satu margin tipis & satu rugi utk demo warna
grid["Cabang B"][3] = r100(PRODUCTS[3].last * 1.02);
grid.Gudang[2] = r100(PRODUCTS[2].last * 0.95);

// state sederhana di module (demo) — bisa diganti fetch ke backend
const rows: PriceRow[] = [];
OUTLETS.forEach((o) => PRODUCTS.forEach((p, i) => rows.push({ outlet: o, product_id: p.id, hj: [
  grid[o][i], r100(grid[o][i]! * 0.97), r100(grid[o][i]! * 0.93), r100(grid[o][i]! * 0.9), r100(grid[o][i]! * 0.86),
] })));

export function getRow(outlet: string, pid: number): PriceRow {
  return rows.find((r) => r.outlet === outlet && r.product_id === pid)!;
}
export function setRow(outlet: string, pid: number, hj: (number | null)[], applyAll: boolean) {
  rows.forEach((r) => { if (r.product_id === pid && (applyAll || r.outlet === outlet)) r.hj = [...hj]; });
}

export const hppOf = (p: Product, basis: Settings["basis"]) => (basis === "last" ? p.last : p.std);
export const rp = (n?: number | null) =>
  n == null || isNaN(n) ? "—" : "Rp" + Math.round(n).toLocaleString("id-ID");
export const pct = (n: number) => (isNaN(n) ? "—" : (n >= 0 ? "+" : "") + n.toFixed(1) + "%");
export type Tone = "ok" | "warn" | "bad";
export const tone = (n: number): Tone => (n < 0 ? "bad" : n < 5 ? "warn" : "ok");

export function tierCalc(hj: number | null | undefined, hpp: number, s: Settings, reseller?: boolean): Calc | null {
  if (hj == null) return null;
  const beban = hj * (s.beban / 100);
  const kom = (reseller ?? s.channel === "Reseller") ? hj * (s.komisi / 100) : 0;
  const hppEff = hpp + beban;
  const laba = hj - hppEff - kom;
  return { omset: hj, beban, hppEff, gross: ((hj - hppEff) / hj) * 100, laba, net: (laba / hj) * 100 };
}
