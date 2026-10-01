# frozen_string_literal: true
#
# Master data tambahan + integrasi smart lock (7EVEN KEY / TTLOCK):
# - hotels.host_id            : pemilik data ( utk otorisasi UI master data )
# - rooms.grid_row/grid_col   : posisi unit pada grid floor-plan di UI
# - smart_lock_devices        : perangkat lock per kamar + master config
# - door_master_keys          : master key (RFID card / PIN induk)
# - door_temporary_keys       : temporary key / passcode utk guest & staf
class CreateMasterDataAndSmartLocks < ActiveRecord::Migration[7.1]
  def change
    add_column :hotels, :host_id, :bigint unless column_exists?(:hotels, :host_id)
    add_index :hotels, :host_id unless index_exists?(:hotels, :host_id)

    add_column :rooms, :grid_row, :integer, default: 1 unless column_exists?(:rooms, :grid_row)
    add_column :rooms, :grid_col, :integer, default: 1 unless column_exists?(:rooms, :grid_col)

    create_table :smart_lock_devices do |t|
      t.references :room, null: false, foreign_key: true, index: { unique: true }
      t.string :brand, null: false, default: "seven_key" # seven_key | ttlock
      t.string :device_type, null: false, default: "door_lock"
      t.string :device_name
      t.string :device_trid                     # TTLOCK: custom ID device
      t.string :device_pass_code                # TTLOCK: passcode pairing (6 digit)
      t.string :device_api_key                  # TTLOCK: serverKey device (rahasia!)
      t.string :mac_address                    # 7EVEN KEY: MAC perangkat
      t.string :firmware_version
      t.integer :battery_level                  # 0..100
      t.boolean :online, default: false, null: false
      t.string :status, default: "unpaired", null: false # unpaired, paired, offline, error
      # ---- Master config (passcode master / admin lock) ----
      t.string :master_passcode                 # disimpan terenkripsi (attr_encrypted-style via KMS di prod)
      t.string :master_passcode_changed_at
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :smart_lock_devices, :device_trid, unique: true
    add_index :smart_lock_devices, :mac_address

    create_table :door_master_keys do |t|
      t.references :smart_lock_device, null: false, foreign_key: true
      t.string :key_type, null: false           # rfid_card | pin | fingerprint | app_ble
      t.string :identifier                      # no. kartu / label jari
      t.string :pin_code                        # utk key_type=pin (terenkripsi di aplikasi)
      t.string :name, null: false               # "Kartu Admin Lobi", "PIN Ibu Host"
      t.date :valid_from
      t.date :expires_on
      t.boolean :active, default: true, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :door_master_keys, [:smart_lock_device_id, :key_type, :identifier],
              unique: true, name: "idx_master_keys_unique_per_device"

    create_table :door_temporary_keys do |t|
      t.references :smart_lock_device, null: false, foreign_key: true
      t.references :booking, null: true, foreign_key: true
      t.references :rental_booking, null: true, foreign_key: true
      t.references :user, null: true, foreign_key: true   # utk staff/housekeeper key
      t.string :kind, default: "passcode", null: false    # passcode | ic_card | fingerprint
      t.string :passcode                                  # passcode generated (terenkripsi di aplikasi)
      t.string :ic_card_number                            # utk kind=ic_card
      t.string :label                                     # "Guest Check-in 12 Okt"
      t.datetime :start_at, null: false
      t.datetime :end_at, null: false
      t.integer :times_limit                              # maks buka pintu (TTLOCK timesLimit)
      t.integer :times_used, default: 0, null: false
      t.string :status, default: "pending", null: false   # pending|active|synced|expired|revoked|failed
      t.string :remote_key_id                             # id key di server TTLOCK/7EVEN
      t.datetime :synced_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :door_temporary_keys, :passcode
    add_index :door_temporary_keys, [:smart_lock_device_id, :status]
  end
end
