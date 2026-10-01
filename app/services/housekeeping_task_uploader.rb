# frozen_string_literal: true
#
# Upload bukti kerja (image/file) ke kartu Kanban housekeeping.
# Menerima file langsung (melalui controller -> attach) atau URL hasil
# upload langsung ke storage (mis. presigned S3 / ActiveStorage upload).
class HousekeepingTaskUploader
  Result = Struct.new(:attachment, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  def initialize(task:, uploaded_file: nil, file_url: nil, filename: nil, content_type: nil, byte_size: nil, caption: nil, uploader: nil)
    @task = task
    @uploaded_file = uploaded_file
    @file_url = file_url
    @filename = filename
    @content_type = content_type
    @byte_size = byte_size
    @caption = caption
    @uploader = uploader
  end

  def call
    return Result.new(errors: ["Task sudah ditutup (#{task.status})"]) unless task.open?

    if uploaded_file.present?
      stored = store_uploaded_file
      return Result.new(errors: [stored]) if stored.is_a?(String)
      url, name, ctype, size = stored
    elsif file_url.present?
      url = file_url
      name = filename || File.basename(URI.parse(file_url).path rescue file_url)
      ctype = content_type
      size = byte_size
    else
      return Result.new(errors: ["File atau file_url wajib diisi"])
    end

    kind = HousekeepingTaskAttachment.kind_for(name)
    attachment = nil
    ActiveRecord::Base.transaction do
      attachment = task.attachments.create!(
        file_url: url,
        filename: name,
        content_type: ctype,
        file_size: size,
        kind: kind,
        caption: caption,
        uploaded_by: uploader
      )
      task.log_activity(uploader, "upload #{kind}: #{name}")
    end

    Result.new(attachment: attachment, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    Result.new(errors: [e.message])
  end

  private

  attr_reader :task, :uploaded_file, :file_url, :filename, :content_type, :byte_size, :caption, :uploader

  def store_uploaded_file
    io = uploaded_file.respond_to?(:tempfile) ? uploaded_file : uploaded_file.try(:open)
    name = uploaded_file.respond_to?(:original_filename) ? uploaded_file.original_filename : filename
    ctype = uploaded_file.respond_to?(:content_type) ? uploaded_file.content_type : content_type
    size = uploaded_file.respond_to?(:size) ? uploaded_file.size : byte_size

    ext = File.extname(name.to_s).delete('.').downcase
    unless HousekeepingTaskAttachment::IMAGE_EXTENSIONS.include?(ext) || ctype.to_s.start_with?('image/')
      return "Hanya image (jpg/jpeg/png/webp/gif/heic) yang diterima sebagai bukti"
    end
    if size.to_i > HousekeepingTaskAttachment::MAX_IMAGE_BYTES
      return "Ukuran image melebihi #{HousekeepingTaskAttachment::MAX_IMAGE_BYTES / 1.megabyte}MB"
    end

    key = "housekeeping/#{task.id}/#{SecureRandom.hex(8)}-#{name}"
    blob = ActiveStorage::Blob.create_and_upload!(io: io, filename: name, content_type: ctype) rescue nil
    if blob
      [blob.url, name, ctype, size]
    else
      # Fallback: simpan ke disk public/uploads bila ActiveStorage belum dikonfigurasi
      dir = Rails.root.join('public', 'uploads', 'housekeeping')
      FileUtils.mkdir_p(dir)
      safe_name = "#{SecureRandom.hex(8)}-#{File.basename(name.to_s)}"
      File.binwrite(dir.join(safe_name), io.read)
      ["/uploads/housekeeping/#{safe_name}", name, ctype, size]
    end
  end
end
