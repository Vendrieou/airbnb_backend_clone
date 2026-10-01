# frozen_string_literal: true
#
# Notifikasi otomatis seputar task housekeeping:
#   - task baru dibuat oleh algoritma H+3 checkout
#   - task mendekati jatuh tempo (reminder)
#   - kartu pindah kolom / menunggu validasi foto
class HousekeepingNotifier
  class << self
    def notify_task_created(task)
      recipients(task).each do |user|
        deliver(user,
                title: "Task housekeeping baru: #{task.title}",
                body: "Kamar #{task.room.room_number} checkout tanpa perpanjangan (melewati H+3). " \
                      "Kartu draft sudah dibuat di board — mulai kerjakan dan upload foto bukti hingga kolom done.",
                kind: 'housekeeping_new')
      end
    end

    def notify_due_soon(task)
      recipients(task).each do |user|
        deliver(user,
                title: "Pengingat: #{task.title} jatuh tempo hari ini",
                body: "Selesaikan kartu di board housekeeping sebelum #{task.due_at&.strftime('%d %b %Y %H:%M')}.",
                kind: 'housekeeping_due')
      end
    end

    def notify_status_changed(task, actor)
      recipients(task).each do |user|
        next if user == actor
        deliver(user,
                title: "#{task.title} → #{task.status}",
                body: "Kartu dipindahkan ke kolom '#{task.status}'#{task.photo_count.positive? ? " (#{task.photo_count} foto)" : ''}.",
                kind: 'housekeeping_status')
      end
    end

    private

    def recipients(task)
      ids = [task.assigned_to_id, task.property.try(:host_id)].compact.uniq
      User.where(id: ids)
    rescue StandardError
      User.none
    end

    def deliver(user, title:, body:, kind:)
      Rails.logger.info("[HousekeepingNotifier][#{kind}] to=#{user.id}: #{title}")
      # Kanal WhatsApp out-of-app (provider via ENV["WHATSAPP_PROVIDER"], default: fake/log)
      WhatsappNotifier.notify(user, "*#{title}*\n#{body}") if defined?(WhatsappNotifier)
    rescue StandardError => e
      Rails.logger.warn("[HousekeepingNotifier] gagal: #{e.message}")
    end
  end
end
