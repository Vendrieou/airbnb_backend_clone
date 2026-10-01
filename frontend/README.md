# Frontend (React + Vite) — Sewa Harian/Mingguan/Bulanan + Cicilan & Kanban Housekeeping

## Menjalankan (butuh Node.js >= 18)
```bash
cd frontend
npm install
npm run dev        # http://localhost:5173  (API di-proxy ke Rails :3000)
```
Rails harus jalan terpisah: `bin/rails server` (port 3000).

## Halaman
| Route | Fungsi |
|---|---|
| `/` | Cari paket sewa — filter harian/mingguan/bulanan + "bisa dicicil", modal booking dengan **preview estimasi cicilan live** (DP + angsuran) dari `GET /rental_plans/:id/installment_estimate` |
| `/bookings` | Daftar sewa saya (status & payment_status) |
| `/bookings/:id` | Detail sewa, **jadwal cicilan**, tombol bayar DP/angsuran (`POST /rental_bookings/:id/pay`), batalkan |
| `/housekeeping` | **Kanban board** draft→todo→in_progress→review→done; kartu oranye = task otomatis (checkout H-3); tombol 📷 upload bukti foto (`POST /housekeeping/tasks/:id/upload`) — wajib sebelum review/done; auto-refresh 15 dtk |

## Catatan
- Auth: token JWT dibaca dari `localStorage.token` dan dikirim sebagai `Authorization: Bearer` — tambahkan halaman login sesuai endpoint auth Rails kamu bila perlu.
- Build produksi: `npm run build` → taruh hasil `frontend/dist` di `public/` atau serve via nginx.
- Field JSON diasumsikan snake_case mengikuti serializer Rails; sesuaikan di `src/api/client.js` bila beda.
