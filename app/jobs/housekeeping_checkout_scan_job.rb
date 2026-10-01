# frozen_string_literal: true
#
# Jalankan harian (cron/GoodJob/recurring.yml):
#   HousekeepingCheckoutScanJob.perform_later
#
# Algoritma: untuk setiap kamar, jika booking terakhir sudah checkout DAN
# tidak diperpanjang setelah H-3 (end_date + 3 hari terlewat), otomatis
# buat kartu HousekeepingTask di kolom 'draft' pada Kanban board + kirim
# notifikasi ke housekeeper/host.
class HousekeepingCheckoutScanJob < ApplicationJob
  queue_as :default

  def perform(grace_days: HousekeepingTriggerService::DEFAULT_GRACE_DAYS)
    result = HousekeepingTriggerService.new(grace_period_days: grace_days).scan_all!

    # Pengingat task yang jatuh tempo hari ini
    HousekeepingTask.open.due_before(Date.today).find_each do |task|
      HousekeepingNotifier.notify_due_soon(task)
    end

    Rails.logger.info(
      "[HousekeepingCheckoutScanJob] rooms=#{result.rooms_scanned} tasks_created=#{result.tasks_created.size}"
    )
    result
  end
end
