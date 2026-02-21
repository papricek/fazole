# frozen_string_literal: true

require "bundler/setup"
require "dotenv/load"
require "fazole"
require "json"
require "csv"
require "fileutils"

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
FileUtils.rm_rf(output_dir)
Dir.mkdir(output_dir)

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

# Generate ISDOC XML files
json_files = Dir.glob(File.join(output_dir, "*.json")).sort
json_files.each do |json_file|
  data = JSON.parse(File.read(json_file))
  xml = Fazole.to_isdoc(data)
  isdoc_file = json_file.sub(/\.json$/, ".isdoc")
  File.write(isdoc_file, xml)
  puts "  ISDOC -> #{File.basename(isdoc_file)}"
end

# Generate CSV summary
CSV_HEADERS = %w[
  source_file document_type supplier_invoice_number issue_date taxable_supply_date due_date
  supplier_name supplier_ico supplier_dic supplier_street supplier_city supplier_postal_code
  customer_name customer_ico customer_dic
  currency net_total vat_total gross_total amount_due
  payment_method variable_symbol account_number_local iban
  reverse_charge simplified_tax_document
  line_position line_description line_product_code line_quantity line_unit
  line_unit_price_net line_unit_price_gross line_net_amount line_vat_rate line_vat_amount line_gross_amount
  extraction_confidence
].freeze

csv_path = File.join(output_dir, "invoices.csv")
CSV.open(csv_path, "w", headers: CSV_HEADERS, write_headers: true) do |csv|
  json_files.each do |json_file|
    data = JSON.parse(File.read(json_file))
    inv = data["invoice"]
    supplier = inv.dig("parties", "supplier") || {}
    customer = inv.dig("parties", "customer") || {}
    totals = inv.dig("money", "totals") || {}
    payment = inv["payment"] || {}
    flags = inv["flags"] || {}
    dates = inv["dates"] || {}

    base = [
      File.basename(json_file), inv["document_type"], inv["supplier_invoice_number"],
      dates["issue_date"], dates["taxable_supply_date"], dates["due_date"],
      supplier["name"], supplier["ico"], supplier["dic"],
      supplier.dig("address", "street"), supplier.dig("address", "city"), supplier.dig("address", "postal_code"),
      customer["name"], customer["ico"], customer["dic"],
      inv.dig("money", "currency"), totals["net_total"], totals["vat_total"], totals["gross_total"], totals["amount_due"],
      payment["method"], payment["variable_symbol"], payment["account_number_local"], payment["iban"],
      flags["reverse_charge"], flags["simplified_tax_document"]
    ]

    items = inv["line_items"] || []
    if items.empty?
      csv << base + [nil] * 11 + [inv.dig("extraction", "confidence")]
    else
      items.each do |item|
        csv << base + [
          item["position"], item["description"], item["product_code"],
          item["quantity"], item["unit"], item["unit_price_net"], item["unit_price_gross"],
          item["net_amount"], item["vat_rate"], item["vat_amount"], item["gross_amount"],
          inv.dig("extraction", "confidence")
        ]
      end
    end
  end
end

puts "  CSV  -> #{File.basename(csv_path)}"
puts "\nDone. #{json_files.size} JSON + #{json_files.size} ISDOC + 1 CSV"
