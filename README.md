# SewaKu — Property Management & Rental Platform

Platform **sewa properti harian/mingguan/bulanan dengan cicilan**, housekeeping otomatis, smart lock (7Even Key / TTLock), chat ala WhatsApp, dan master data kamar berbasis grid — dibangun dengan **Ruby on Rails 8** (API + Solid Queue/Cable/Cache) di backend dan **React + Vite + Tailwind** di frontend.

---

## 🧭 Daftar Isi
- [Aplikasi Overview](#application-overview)
- [Fitur Utama](#fitur-utama)
- [Arsitektur & Struktur Folder](#arsitektur)
- [Menjalankan Aplikasi](#menjalankan)
- [Dokumentasi API (Swagger)](#swagger)
- [Alur Kerja Otomatis](#otomasi)
- [Environment Variables](#env)
- [Status & Catatan](#status)

---

<a name="application-overview"></a>
## Application Overview

Sistem PMS + rental marketplace dua sisi (host & guest):

| Layer | Teknologi |
|---|---|
| Backend API | Ruby on Rails 8, JWT auth, ActionCable |
| Background jobs | Solid Queue (`rental_installment_due_check_job`, `housekeeping_trigger_service`, `message_whatsapp_delivery_job`) |
| Realtime | Solid Cable (channel `ConversationChannel`: kirim pesan, typing, read-receipt) |
| Frontend | React 19 + Vite, Tailwind (design-token oklch light/dark), 46 komponen shadcn/Radix di `src/components/ui` |
| Dokumentasi | OpenAPI 3.0.3 statis (`swagger/swagger.yaml` → `public/swagger`) |

---

<a name="fitur-utama"></a>
## Fitur Utama

### 1. 💰 Sewa Harian / Mingguan / Bulanan + Cicilan
Model: `RentalPlan`, `RentalBooking`, `RentalInstallmentPlan`, `RentalInstallment`, `RentalPayment`
Services: `RentalBookingCreator`, `RentalInstallmentPayer`
- Paket sewa per facility dengan `period = daily | weekly | monthly` (+ validasi kelipatan periode: mingguan ×7 malam, bulanan ×30).
- Skema cicilan: DP (`upfront_percent`) + N angsuran rata (`installment_count`, interval hari), cicilan terakhir menyerap sisa pembulatan.
- Status booking: `pending_payment → confirmed → active → completed / cancelled`; payment status: `unpaid → down_payment_paid → partially_paid → paid / overdue`.
- Idempotency key pada create booking; row-lock plan saat cek bentrok tanggal.
- Endpoint: `GET /rental_plans?period=&installments=true`, `POST /rental_plans/:id/installment_estimate` (preview DP + tabel angsuran), `POST /rental_bookings/:id/pay`, `.../cancel`.
- Frontend: `RentalPlansPage` (filter periode + estimator cicilan), `MyBookingsPage`, `BookingDetailPage` (jadwal angsuran + tombol bayar).

### 2. 🧹 Housekeeping — Auto Notif, Auto Task & Kanban Board
Model: `HousekeepingBoard`, `HousekeepingTask`, `HousekeepingActivity`, `HousekeepingTaskAttachment`
Services: `HousekeepingTriggerService`, `HousekeepingNotifier`, `HousekeepingTaskUploader`
- **Algoritma auto-trigger**: scan harian — kamar yang sudah checkout **tidak diperpanjang setelah H+3** → otomatis dibuatkan task di kolom **`draft`** Kanban board (`source: auto_checkout`) + notifikasi housekeeper/host.
- Alur Kanban: `draft → todo → in_progress → review → done` (bisa `move/advance/assign/cancel`).
- **Wajib upload foto** ≥1 sebelum pindah ke `review`/`done` — `POST /housekeeping/tasks/:id/upload` (multipart image).
- Setelah task `done` dan tidak ada task aktif lain, status kamar kembali `available`.
- Frontend: `HousekeepingBoardPage` (drag antar kolom, dialog upload).

### 3. 🏢 Master Data — Grid Floor & Unit Kamar
Controllers: `master_data/floors`, `master_data/rooms`, `master_data/smart_locks`
- CRUD **floor** dan **unit kamar** langsung dari UI; tampilan **grid system** per lantai (klik unit → detail).
- Frontend: `MasterDataPage` — tambah floor/unit inline, panel detail unit berisi setup smart lock.

### 4. 🔐 Smart Lock (7Even Key / TTLock)
Model: `SmartLockDevice`, `DoorMasterKey`, `DoorTemporaryKey`
Services: `SmartLockGateway`, `TemporaryKeyGenerator`
Di halaman detail unit tersedia:
- **Master Config** — pairing device, firmware, mode (`PATCH .../master_config`).
- **Master Key** — daftar/tambah/revoke kunci permanen (`POST/DELETE .../master_keys`).
- **Temporary Key** — passcode ter-generate otomatis untuk tamu (masa aktif mengikuti tanggal booking, bisa di-regenerate).
- Gateway pluggable: mode simulasi (dev) atau adapter TTLock/7Even via ENV.

### 5. 💬 Chat ala WhatsApp (in-app + integrasi WA asli)
Model: `Conversation`, `Message` (status `pending→sent→delivered→read/failed`, centang ✓/✓✓/biru)
Services/Jobs: `WhatsappGateway` (fake/fonnte/wablas), `MessageWhatsappDeliveryJob`, `WhatsappNotifier`, `WhatsappWebhooksController`
- Realtime via ActionCable: optimistic send (`client_message_id` dedup), indikator *typing*, read-receipt multi-perangkat.
- Salinan chat otomatis terkirim ke WhatsApp lawan bicara; webhook provider memperbarui centang real.
- Toggle sinkron WA per conversation + tombol "Buka WhatsApp ↗" (wa.me deep-link, 08xx→62xx).
- Notifikasi WA bertemplate Bahasa Indonesia: konfirmasi booking+cicilan, struk pembayaran, pengingat angsuran **H-3/hari-H/mingguan saat overdue** (anti-spam `reminder_sent_at`).
- Frontend: `ChatPage` (`/chat`, `/chat/:id`).

### 6. 📊 Pricing Matrix (komponen `components/pricing`)
- `Modal`, `HistDialog` (riwayat modal per PO), `PromoDialog` (simulasi permutasi beban/komisi/HPP efektif), `CustomDialog` (atur harga: nominal / diskon % / template margin %, validasi Lolos/Ditolak).
- Data & helper: `src/lib/pricing.ts` (`CHANNELS, OUTLETS, PRODUCTS, TIERS, hppOf, tierCalc, …`).
- Halaman demo: `/pricing`.

### 7. 🧩 Design System & UI Kit
- **46 komponen shadcn/Radix** di `frontend/src/components/ui` (accordion…tooltip, termasuk calendar, carousel, chart, drawer, input-otp, sidebar, sonner, dsb.).
- Token warna **oklch** light/dark (`--ok/--warn/--bad/--none-bg`, chart, sidebar), dark mode class-based, `prefers-reduced-motion`.
- Halaman smoke-test semua komponen: `/ui-kit`.

### 8. Modul pendukung lama (tetap aktif)
Facility booking + review, wishlist, portal dashboard host/guest, payment/invoice, geolocation, Stripe webhook.

---

<a name="arsitektur"></a>
## Arsitektur & Struktur Folder

```
workspace/
├── app/
│   ├── models/            # rental_*, housekeeping_*, door_*_key, smart_lock_device, conversation, message, …
│   ├── services/          # RentalBookingCreator, RentalInstallmentPayer, HousekeepingTriggerService,
│   │                      # TemporaryKeyGenerator, SmartLockGateway, WhatsappGateway/Notifier, …
│   ├── controllers/
│   │   ├── rental_plans / rental_bookings / housekeeping/* / master_data/* / conversations / whatsapp_webhooks
│   │   └── portals, facilities, bookings, payments, wishlists, reviews, …
│   ├── channels/          # ConversationChannel (kirim, typing, read)
│   └── jobs/              # RentalInstallmentDueCheckJob, MessageWhatsappDeliveryJob
├── config/routes.rb       # seluruh endpoint REST
├── db/migrate/            # incl. 20261001120000 (rental), 20261001140000 (WA fields), master data & housekeeping
├── swagger/swagger.yaml   # SOURCE OF TRUTH OpenAPI 3.0.3
├── public/swagger/        # Swagger UI statis + openapi.json/yaml hasil generate
├── lib/tasks/swagger.rake # bin/rails swagger:generate / swagger:validate
└── frontend/              # React + Vite (proxy /api-ish + /cable ke :3000)
    ├── src/components/ui/        # 46 komponen shadcn/Radix
    ├── src/components/pricing/dialogs.tsx
    ├── src/pages/                # RentalPlans, MyBookings, BookingDetail, HousekeepingBoard,
    │                             # MasterData, Chat, PricingMatrix, UiKit
    ├── src/lib/{pricing.ts,utils.ts} · src/api/client.js · src/styles.css + index.css
    └── vite.config.js            # proxy /conversations, /cable (ws), dll.
```

---

<a name="menjalankan"></a>
## Menjalankan Aplikasi

### Backend (Rails 8)
```bash
bundle install
bin/rails db:migrate
bin/rails server            # http://localhost:3000
bin/rails swagger:generate && bin/rails swagger:validate
```

### Frontend (React + Vite)
```bash
cd frontend
npm install
npm run dev                 # http://localhost:5173 (proxy API & /cable ke :3000)
npm run build               # produksi → dist/
```

### Job terjadwal
- `RentalInstallmentDueCheckJob` — harian: tandai angsuran `overdue`, auto-activate/complete booking.
- `HousekeepingTriggerService` (via scheduler/`GoodJob`-style cron) — harian 06:00: auto-task checkout H+3.
- `MessageWhatsappDeliveryJob` — antrean kirim salinan chat ke WA.

---

<a name="swagger"></a>
## Dokumentasi API (Swagger Product Portal)

- Buka **http://localhost:3000/swagger** (Swagger UI: filter, try-it-out, deep-link, topbar portal).
- Edit spec hanya di `swagger/swagger.yaml`, lalu `bin/rails swagger:generate` (sinkron ke `public/swagger/openapi.{yaml,json}`) dan `bin/rails swagger:validate`.
- Cakupan tag: **RentalPlans** (incl. `/availability`, `/installment_estimate`), **RentalBookings** (book/pay/cancel), **FacilityBookings**, **Housekeeping** (Kanban + upload multipart), **MasterData** (floors/units/smartlock master config/master key/temporary key), **Chat/Conversations** (+ `POST /webhooks/whatsapp`), **Portals**. Auth global `bearerAuth` (JWT).
- Import ke Postman / generate SDK dari `public/swagger/openapi.json`. Detail: `SWAGGER_DOCS.md`.

---

<a name="otomasi"></a>
## Alur Kerja Otomatis (ringkas)

```
Checkout H+3 tanpa perpanjangan ──▶ task Kanban 'draft' + notif WA housekeeper/host
Kamar selesai dibersihkan (done + foto) ──▶ kamar 'available' kembali
Booking dibuat ──▶ WA: konfirmasi + skema cicilan
Bayar DP/angsuran ──▶ WA struk + booking auto-confirm/activate
Angsuran H-3 / hari-H / overdue mingguan ──▶ WA reminder (anti-spam)
Pesan chat in-app ──▶ salinan WA + centang status realtime
```

---

<a name="env"></a>
## Environment Variables

| Var | Fungsi |
|---|---|
| `WHATSAPP_PROVIDER` | `fake` (default dev/test) \| `fonnte` \| `wablas` |
| `FONNTE_TOKEN`, `WABLAS_URL`, `WABLAS_KEY` | kredensial gateway WA |
| `WHATSAPP_WEBHOOK_TOKEN` | verifikasi `POST /webhooks/whatsapp` |
| `SMARTLOCK_PROVIDER` | `simulate` \| `ttlock` \| `seveneven` (+ token terkait) |
| `APP_URL` | base URL utk wa.me link & asset webhook |
| `STRIPE_*` | payment gateway lama |

---

<a name="status"></a>
## Status & Catatan

- ✅ Frontend build tervalidasi: `tsc --noEmit` exit 0, `vite build` sukses, 46 komponen UI + `components/pricing` lengkap.
- ⚠️ Jalankan `bin/rails db:migrate` di lingkungan development (migration baru: rental tables, WA fields di `messages`, master data & housekeeping boards).
- ⚠️ Untuk WA produksi: siapkan akun Fonnte/Wablas + callback URL; user perlu kolom `phone`.
- 📄 Panduan lama tetap tersedia: `FACILITY_BOOKING_COMPLETE_GUIDE.md`, `MESSAGING_FEATURE.md`, `PAYMENT_FEATURE.md`, `PORTAL_DASHBOARD_FEATURE.md`, `SWAGGER_DOCS.md`.
