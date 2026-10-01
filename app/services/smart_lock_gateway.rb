# frozen_string_literal: true
#
# Gateway integrasi smart lock. Provider dipilih via ENV:
#   SMART_LOCK_PROVIDER = fake (default dev/test) | ttlock | seven_key
#
# TTLOCK cloud API (https://developer.ttlock.com):
#   - control/addPasscode : passcode temporer (ekey "passcode" type 6)
#   - control/deletePasscode
#   - ekey/add            : IC card / fingerprint / keyboard key
# 7EVEN KEY: REST per-vendor — endpoint & auth disesuaikan dgn kontrak device.
#
# Mode "fake" tidak memanggil jaringan; cukup log + sukseskan operasi supaya
# UI master data bisa dipakai tanpa perangkat fisik.
class SmartLockGateway
  class Error < StandardError; end

  attr_reader :device

  def initialize(device)
    @device = device
  end

  def provider
    ENV.fetch("SMART_LOCK_PROVIDER", "fake")
  end

  # ---- Pairing perangkat ke akun cloud ----
  def pair!
    case provider
    when "ttlock"  then ttlock_api("device/bind", lockPassCode: device.device_pass_code)
    when "seven_key" then seven_key_api("/device/pair", mac: device.mac_address)
    else fake("pair device #{device.id} (#{device.brand})")
    end
    device.update!(status: "paired", online: true, last_synced_at: Time.current)
  end

  # ---- Master config: set/ganti PIN induk (master passcode) ----
  def set_master_passcode!(plain_code)
    raise Error, "passcode harus 4-10 digit" unless plain_code.to_s.match?(/\A\d{4,10}\z/)
    case provider
    when "ttlock" then ttlock_api("control/setPasscode", editMode: 1, passcode: plain_code)
    when "seven_key" then seven_key_api("/lock/master-pin", pin: plain_code)
    else fake("set master passcode device #{device.id}")
    end
    device.update!(master_passcode: plain_code, master_passcode_changed_at: Time.current.iso8601)
  end

  # ---- Temporary key: push passcode/IC key ke lock ----
  def add_key!(temp_key)
    result =
      case provider
      when "ttlock"
        ttlock_api("control/addPasscode",
                   passcode: temp_key.passcode,
                   startDate: (temp_key.start_at.to_f * 1000).to_i,
                   endDate: (temp_key.end_at.to_f * 1000).to_i,
                   timesLimit: temp_key.times_limit || 0)
      when "seven_key"
        seven_key_api("/temp-key/add",
                      code: temp_key.passcode,
                      valid_from: temp_key.start_at.iso8601,
                      valid_to: temp_key.end_at.iso8601)
      else
        fake("add temp key #{temp_key.id} to device #{device.id}")
      end
    device.mark_synced!
    result || { "ok" => true }
  end

  # ---- Cabut key (temporary maupun master) dari lock ----
  def delete_key!(key)
    case provider
    when "ttlock"
      ttlock_api("control/deletePasscode", passcodeId: key.remote_key_id.presence || key.passcode)
    when "seven_key"
      seven_key_api("/temp-key/delete", key_id: key.try(:remote_key_id) || key.id)
    else
      fake("delete key #{key.id} from device #{device.id}")
    end
  end

  # ---- Refresh status (baterai/online) ----
  def refresh_status!
    case provider
    when "ttlock"
      res = ttlock_api("device/detail", lockData: device.device_trid)
      device.update!(battery_level: res["batteryLock"]&.to_i, online: res["gateway"] != nil) if res
    when "seven_key"
      res = seven_key_api("/device/status", mac: device.mac_address)
      device.update!(battery_level: res["battery"]&.to_i, online: !!res["online"]) if res
    else
      device.update!(online: true)
    end
    device.update!(last_synced_at: Time.current)
  end

  private

  def fake(msg)
    Rails.logger.info("[SmartLockGateway:fake] #{msg}")
    { "ok" => true, "fake" => true }
  end

  def ttlock_api(path, params)
    base = ENV.fetch("TTLOCK_API_BASE", "https://api.silesia.ttlock.com/v3")
    query = params.merge(
      clientID: ENV.fetch("TTLOCK_CLIENT_ID", ""),
      accessToken: ENV.fetch("TTLOCK_ACCESS_TOKEN", ""),
      lockId: device.device_trid,
      serverKey: device.device_api_key,
      nojson: 0
    )
    uri = URI("#{base}/#{path}")
    uri.query = URI.encode_www_form(query)
    res = Net::HTTP.get_response(uri)
    raise Error, "TTLOCK HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
    body = JSON.parse(res.body)
    raise Error, "TTLOCK error #{body['error'] || body['result']}" if body["error"]
    body
  end

  def seven_key_api(path, payload)
    base = ENV.fetch("SEVENKEY_API_BASE", "https://api.7evenkey.com")
    uri = URI("#{base}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json",
                              "Authorization" => "Bearer #{ENV.fetch('SEVENKEY_API_TOKEN', '')}")
    req.body = payload.to_json
    res = http.request(req)
    raise Error, "7EVEN KEY HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body)
  rescue Errno::ECONNREFUSED, SocketError => e
    raise Error, "7EVEN KEY unreachable: #{e.message}"
  end
end
