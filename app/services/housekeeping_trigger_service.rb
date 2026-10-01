# frozen_string_literal: true
#
# Algoritma auto-trigger task housekeeping.
#
# Aturan (business rule):
#   1. Ambil booking terakhir sebuah kamar (via room_type property).
#   2. Hitung "H+3" = end_date + grace_period_days (default 3 hari).
#      Jika hari ini sudah lewat H+3 DAN tidak ada booking lanjutan yang
#      overlap/menyambung dengan end_date lama -> tamu dianggap
#      CHECKOUT & TIDAK DIPERPANJANG.
#   3. Maka otomatis:
#        - buat kartu HousekeepingTask di kolom 'draft' pada Kanban board
#          properti tersebut,
#        - kirim notifikasi ke housekeeper & host,
#        - set kamar ke status 'maintenance' agar tidak terjual sebelum bersih.
#   4. Idempotent: satu booking hanya memicu satu task (uniqueness last_booking_id).
class HousekeepingTriggerService
  DEFAULT_GRACE_DAYS = 3

  Result = Struct.new(:tasks_created, :rooms_scanned, :notified, keyword_init: true) do
    def success?
      errors.empty?
    end

    def errors
      []
    end
  end

  attr_reader :grace_period_days

  def initialize(grace_period_days: DEFAULT_GRACE_DAYS, dry_run: false)
    @grace_period_days = grace_period_days.to_i.positive? ? grace_period_days.to_i : DEFAULT_GRACE_DAYS
    @dry_run = dry_run
  end

  # Scan semua kamar aktif; cocok untuk cron harian.
  def scan_all!
    tasks = []
    Room.joins(room_type: { hotel: [] }).distinct.find_each do |room|
      t = evaluate_room(room)
      tasks << t if t
    end
    Result.new(tasks_created: tasks, rooms_scanned: Room.count)
  end

  # Evaluasi satu kamar. Mengembalikan HousekeepingTask jika trigger terpenuhi.
  def evaluate_room(room)
    last = last_finished_booking(room)
    return nil unless last

    threshold = last.end_date + grace_period_days # H-3 selesai -> lewat tanggal ini = kedaluwarsa perpanjangan
    return nil unless Date.today > threshold

    # Tidak diperpanjang? Cek booking lain yang menyambung/overlap setelah checkout.
    return nil if extended_or_rebooked?(room, last)

    create_task_for_checkout(room, last)
  end

  private

  def last_finished_booking(room)
    scope = Booking.where("end_date < ?", Date.today)
    if (pid = property_id_for(room))
      scope = scope.where(property_id: pid)
    end
    scope.order(end_date: :desc).first
  end

  def property_id_for(room)
    room.room_type.hotel&.property_id
  rescue StandardError
    nil
  end

  # Ada booking lanjutan yang menyambung/overlap dengan tanggal checkout?
  def extended_or_rebooked?(room, last_booking)
    Booking.where("start_date <= ? AND end_date > ?", last_booking.end_date, last_booking.end_date)
            .where.not(id: last_booking.id)
            .exists?
  end

  def create_task_for_checkout(room, last_booking)
    return nil if HousekeepingTask.exists?(last_booking_id: last_booking.id)

    board = board_for(room)
    task = nil

    begin
      ActiveRecord::Base.transaction do
        task = HousekeepingTask.create!(
          room: room,
          property: board.property,
          hotel: board.hotel,
          board: board,
          last_booking: last_booking,
          title: "Beres-beres Kamar #{room.room_number} (checkout #{last_booking.end_date})",
          description: "Tamu checkout dan tidak memperpanjang sewa setelah H+#{grace_period_days}. " \
                       "Pindahkan kartu melalui kolom board sampai 'done' dengan melampirkan foto bukti.",
          task_type: 'cleaning',
          priority: 'high',
          status: 'draft',
          due_at: Time.current.end_of_day,
          triggered_by: 'auto_h3_checkout'
        )
        task.log_activity(nil, "dibuat otomatis (algoritma H+#{grace_period_days} checkout)")
        room.mark_for_maintenance!("Menunggu housekeeping ##{task.id}") unless room.available?
      end
    rescue ActiveRecord::RecordNotUnique
      # Idempoten bila scan berjalan paralel untuk booking yang sama.
      return nil
    end

    HousekeepingNotifier.notify_task_created(task)
    task
  end

  def board_for(room)
    hotel = room.room_type.hotel
    property = hotel&.property || Property.first
    raise BookingError, "Belum ada property untuk board housekeeping" unless property

    HousekeepingBoard.find_or_create_by!(property: property, hotel: hotel) do |b|
      b.name = "Housekeeping - #{property.name}"
    end
  end
end
