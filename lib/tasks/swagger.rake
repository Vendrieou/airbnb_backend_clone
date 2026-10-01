# frozen_string_literal: true

namespace :swagger do
  desc "Generate public/swagger/openapi.yaml dari swagger/swagger.yaml (source of truth)"
  task :generate, [:format] => :environment do |_t, args|
    format = (args[:format] || "yaml").to_s
    src = Rails.root.join("swagger", "swagger.yaml")
    out_dir = Rails.root.join("public", "swagger")
    FileUtils.mkdir_p(out_dir)

    spec = YAML.load_file(src)

    case format
    when "json"
      File.write(out_dir.join("openapi.json"), JSON.pretty_generate(spec))
      puts "Wrote public/swagger/openapi.json"
    else
      FileUtils.cp(src, out_dir.join("openapi.yaml"))
      puts "Wrote public/swagger/openapi.yaml"
    end
  end

  desc "Validasi struktur OpenAPI spec (syntax + referensi $ref internal)"
  task validate: :environment do
    spec = YAML.load_file(Rails.root.join("swagger", "swagger.yaml"))
    errors = []

    # Kumpulkan semua $ref yang dipakai
    refs = []
    walk = ->(node) do
      case node
      when Hash then node.each { |k, v| k == "$ref" ? refs << v : walk.call(v) }
      when Array then node.each { |v| walk.call(v) }
      end
    end
    walk.call(spec)

    resolve = lambda do |ref|
      return nil unless ref.start_with?("#/")

      ref.delete_prefix("#/").split("/").reduce(spec) do |memo, key|
        memo.is_a?(Hash) ? memo[key] : nil
      end
    end

    refs.uniq.each do |ref|
      errors << "Unresolved $$ref: #{ref}" if resolve.call(ref).nil?
    end

    # Setiap path harus punya minimal 1 operation dengan operationId unik
    ids = []
    spec.fetch("paths", {}).each do |path, ops|
      ops.each_key do |verb|
        next unless %w[get post put patch delete].include?(verb)

        op = ops[verb]
        errors << "Missing operationId: #{verb.upcase} #{path}" unless op["operationId"]
        ids << op["operationId"]
      end
    end
    dupes = ids.select { |i| ids.count(i) > 1 }.uniq
    errors << "Duplicate operationIds: #{dupes.join(', ')}" if dupes.any?

    if errors.empty?
      puts "OK: #{spec['paths'].size} paths, #{refs.uniq.size} refs, all valid."
    else
      errors.each { |e| puts "ERROR: #{e}" }
      exit 1
    end
  end
end
