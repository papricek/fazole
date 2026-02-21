# frozen_string_literal: true

require "bundler/setup"
require "dotenv/load"
require "fazole"
require "json"

TRANSLITERATION = {
  "á" => "a", "č" => "c", "ď" => "d", "é" => "e", "ě" => "e", "í" => "i",
  "ň" => "n", "ó" => "o", "ř" => "r", "š" => "s", "ť" => "t", "ú" => "u",
  "ů" => "u", "ý" => "y", "ž" => "z",
  "Á" => "a", "Č" => "c", "Ď" => "d", "É" => "e", "Ě" => "e", "Í" => "i",
  "Ň" => "n", "Ó" => "o", "Ř" => "r", "Š" => "s", "Ť" => "t", "Ú" => "u",
  "Ů" => "u", "Ý" => "y", "Ž" => "z", "ö" => "o", "ü" => "u", "ä" => "a",
  "ß" => "ss"
}.freeze

def parameterize(string)
  result = string.to_s.downcase
  result = result.gsub(/[#{TRANSLITERATION.keys.join}]/i) { |c| TRANSLITERATION[c] || TRANSLITERATION[c.downcase] || c }
  result = result.gsub(/[^a-z0-9\-_]+/, "-")
  result = result.gsub(/-{2,}/, "-")
  result.sub(/^-/, "").sub(/-$/, "")
end

def output_basename(invoice)
  supplier = invoice.dig("parties", "supplier", "name")
  gross = invoice.dig("money", "totals", "gross_total")
  vs = invoice.dig("payment", "variable_symbol") || invoice["supplier_invoice_number"]

  gross = gross.to_f.round.to_s if gross
  parts = [parameterize(supplier), gross, parameterize(vs)].compact.reject(&:empty?)
  parts.join("-")
end

Fazole.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY")
end

source_dir = File.expand_path("../data/source", __dir__)
requirements = File.read(File.join(source_dir, "requirements.yml"))

images = Dir.glob(File.join(source_dir, "*.{jpeg,jpg,png,gif,webp,pdf}")).sort
abort "No files found in #{source_dir}" if images.empty?

output_dir = File.join(source_dir, "..", "output")
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

results = images.map do |image|
  puts "Processing #{File.basename(image)}..."
  json = Fazole.extract(image: image, requirements: requirements)

  basename = output_basename(json["invoice"] || json)
  output_file = File.join(output_dir, "#{basename}.json")
  n = 1
  while File.exist?(output_file)
    output_file = File.join(output_dir, "#{basename}-#{n}.json")
    n += 1
  end
  File.write(output_file, JSON.pretty_generate(json))
  puts "  -> #{output_file}"

  json
end

puts "\nExtracted #{results.size} invoice(s)."
