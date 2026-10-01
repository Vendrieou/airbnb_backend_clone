# Swagger / OpenAPI API Docs

Struktur dokumentasi API mengikuti pola **Swagger Product Portal** (swagger.io):
satu spec OpenAPI 3.0 sebagai *source of truth*, di-serve lewat Swagger UI, dan
bisa di-generate/validasi via Rake task.

## 📁 Struktur folder

```
swagger/
  swagger.yaml            # SOURCE OF TRUTH — OpenAPI 3.0.3 spec
public/swagger/           # Di-serve statis oleh Rails (tanpa gem tambahan)
  index.html              # Swagger UI (CDN swagger-ui-dist@5) + topbar portal
  openapi.yaml            # hasil generate dari rake task
  openapi.json            # versi JSON (untuk tooling/postman/openapi-generator)
lib/tasks/
  swagger.rake            # rails swagger:generate / swagger:validate
```

## 🚀 Cara pakai

1. **Buka UI docs** (setelah `bin/rails server`):
   - `http://localhost:3000/swagger/index.html` → Swagger UI interaktif (Try-it-out, filter, deep-linking)
   - `http://localhost:3000/swagger/openapi.yaml` → raw spec
2. **Edit spec** hanya di `swagger/swagger.yaml`, lalu sinkronkan:
   ```bash
   bin/rails swagger:generate          # salin ke public/swagger/openapi.yaml
   bin/rails "swagger:generate[json]"  # juga hasilkan openapi.json
   bin/rails swagger:validate          # cek $ref unresolved & operationId duplikat
   ```
3. **Import ke Postman / generate client SDK**:
   ```bash
   npx openapi-generator-cli generate -i swagger/swagger.yaml -g ruby -o generated/stayhub-client
   ```

## 🧭 Isi spec (25 paths, 27 operations, 15 schemas)

| Tag | Endpoint utama |
|---|---|
| **RentalPlans** | `GET /rental_plans?period=daily\|weekly\|monthly&installments=true`, `POST /facilities/:id/rental_plans`, `GET /rental_plans/:id/availability`, `GET /rental_plans/:id/installment_estimate` |
| **RentalBookings** | `POST /rental_plans/:id/bookings` (`pay_in_installments`), `GET /rental_bookings/:id` (+jadwal angsuran), `POST .../pay`, `POST .../cancel` |
| **FacilityBookings** | `GET /facilities`, `POST /facilities/:id/bookings`, cancel/approve/reject |
| **Housekeeping** | boards & tasks Kanban `draft → todo → in_progress → review → done`, `POST /housekeeping/tasks/:id/upload` (multipart image), move/advance/assign/cancel. Didokumentasikan juga auto-task checkout H+3 tanpa perpanjangan |
| **Portals** | `GET /portals/host_dashboard`, `GET /portals/guest_dashboard` |

Skema penting: `RentalPlan` (periode + config cicilan), `InstallmentEstimate`
(DP + tabel angsuran), `RentalBooking` (status & payment_status), `TaskStatus`
(enum kolom Kanban), `HousekeepingTask` (`source: manual|auto_checkout`,
`requires_image_to_advance`), `TaskAttachment` (bukti foto).

Autentikasi didokumentasikan sebagai `bearerAuth` (JWT) global; tiap request
terproteksi memakai header `Authorization: Bearer <token>`.

## 🔁 Opsi upgrade (bila ingin auto-sync dari kode)

Saat ini spec ditulis tangan (zero-dependency). Kalau nanti ingin spec
di-generate otomatis dari controller, tambahkan gem:

```ruby
group :development do
  gem "rswag-api"
  gem "rswag-ui"
  gem "rswag-specs", group: :test
end
```

lalu mount `Rswag::Api::Engine` / `Rswag::Ui::Engine` di `routes.rb` dan tulis
request spec per controller. Struktur file `swagger/swagger.yaml` tetap bisa
dipakai sebagai baseline karena formatnya sudah OpenAPI 3 standar.
