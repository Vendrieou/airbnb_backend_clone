# frozen_string_literal: true
#
# Housekeeping: algoritma auto-notif + task kerja untuk housekeeper
# (kamar checkout & tidak diperpanjang setelah H-3) dan Kanban board
# draft -> todo -> in_progress -> review -> done dengan upload image bukti.
class CreateHousekeepingBoardsAndTasks < ActiveRecord::Migration[8.1]
  def change
    # Papan Kanban per property/hotel
    create_table :housekeeping_boards do |t|
      t.references :property, null: false, foreign_key: true
      t.references :hotel, foreign_key: true, null: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :housekeeping_boards, [:property_id, :hotel_id], unique: true

    # Kartu tugas housekeeping (dibuat otomatis oleh H+3 scan atau manual)
    create_table :housekeeping_tasks do |t|
      t.references :room, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.references :hotel, foreign_key: true, null: true
      t.references :housekeeping_board, foreign_key: true, null: true
      t.references :last_booking, foreign_key: { to_table: :bookings }, null: true
      t.references :assigned_to, foreign_key: { to_table: :users }, null: true
      t.references :created_by, foreign_key: { to_table: :users }, null: true

      t.string :title, null: false
      t.text :description
      t.string :task_type, null: false, default: 'cleaning' # cleaning, deep_cleaning, linen_change, inspection, maintenance_follow_up
      t.string :priority, null: false, default: 'medium'    # low, medium, high, urgent
      t.string :status, null: false, default: 'draft'       # draft, todo, in_progress, review, done, cancelled
      t.datetime :due_at
      t.datetime :completed_at
      t.string :triggered_by, default: 'manual' # manual, auto_h3_checkout

      t.timestamps
    end
    add_index :housekeeping_tasks, :status
    add_index :housekeeping_tasks, :due_at
    add_index :housekeeping_tasks, :last_booking_id, unique: true, where: "last_booking_id IS NOT NULL"
    add_index :housekeeping_tasks, [:housekeeping_board_id, :status]
    add_index :housekeeping_tasks, [:room_id, :status]

    # Upload bukti kerja (image/foto atau file lain) per kartu
    create_table :housekeeping_task_attachments do |t|
      t.references :housekeeping_task, null: false, foreign_key: true
      t.references :uploaded_by, foreign_key: { to_table: :users }, null: true
      t.string :file_url, null: false
      t.string :filename
      t.string :content_type
      t.bigint :file_size
      t.string :kind, null: false, default: 'image' # image, file
      t.string :caption

      t.timestamps
    end
    add_index :housekeeping_task_attachments, [:housekeeping_task_id, :kind]

    # Audit trail pergerakan kartu & notifikasi
    create_table :housekeeping_activities do |t|
      t.references :housekeeping_task, foreign_key: true, null: true
      t.references :user, foreign_key: true, null: true
      t.string :action, null: false

      t.timestamps
    end
    add_index :housekeeping_activities, :created_at

    # Hotel terhubung ke property yang mengoperasikannya
    add_reference :hotels, :property, foreign_key: true
  end
end
