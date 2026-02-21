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

def unique_path(dir, basename, ext)
  path = File.join(dir, "#{basename}#{ext}")
  n = 1
  while File.exist?(path)
    path = File.join(dir, "#{basename}-#{n}#{ext}")
    n += 1
  end
  path
end

CSV_HEADERS = [
  "Původní soubor", "Nový soubor", "Typ dokladu", "Číslo faktury",
  "Datum vystavení", "DÚZP", "Datum splatnosti",
  "Dodavatel", "IČO dodavatele", "DIČ dodavatele",
  "Ulice dodavatele", "Město dodavatele", "PSČ dodavatele",
  "Odběratel", "IČO odběratele", "DIČ odběratele",
  "Měna", "Základ celkem", "DPH celkem", "Celkem s DPH", "K úhradě",
  "Způsob platby", "Variabilní symbol", "Číslo účtu", "IBAN",
  "Přenesená daň. povinnost", "Zjednodušený daň. doklad",
  "Položka č.", "Popis položky", "Kód produktu", "Množství", "Jednotka",
  "Cena/ks bez DPH", "Cena/ks s DPH", "Základ", "Sazba DPH %",
  "DPH", "Celkem s DPH (řádek)", "Spolehlivost extrakce"
].freeze

Fazole.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY")
end

source_dir = File.expand_path("../data/source", __dir__)
requirements = File.read(File.join(source_dir, "requirements.yml"))

sources = Dir.glob(File.join(source_dir, "*.{jpeg,jpg,png,gif,webp,pdf}")).sort
abort "No files found in #{source_dir}" if sources.empty?

output_dir = File.join(source_dir, "..", "output")
FileUtils.rm_rf(output_dir)
Dir.mkdir(output_dir)

entries = sources.map do |source_file|
  original_name = File.basename(source_file)
  puts "Processing #{original_name}..."
  json = Fazole.extract(image: source_file, requirements: requirements)

  basename = output_basename(json["invoice"] || json)
  ext = File.extname(source_file)

  json_path = unique_path(output_dir, basename, ".json")
  actual_basename = File.basename(json_path, ".json")

  FileUtils.cp(source_file, File.join(output_dir, "#{actual_basename}#{ext}"))
  File.write(json_path, JSON.pretty_generate(json))
  puts "  -> #{actual_basename}.json"

  { original: original_name, basename: actual_basename, json_path: json_path }
end

puts "\nExtracted #{entries.size} invoice(s)."

# Generate ISDOC XML files
entries.each do |entry|
  data = JSON.parse(File.read(entry[:json_path]))
  xml = Fazole.to_isdoc(data)
  isdoc_path = entry[:json_path].sub(/\.json$/, ".isdoc")
  File.write(isdoc_path, xml)
  puts "  ISDOC -> #{entry[:basename]}.isdoc"
end

# Generate CSV summary
csv_path = File.join(output_dir, "invoices.csv")
CSV.open(csv_path, "w", headers: CSV_HEADERS, write_headers: true) do |csv|
  entries.each do |entry|
    data = JSON.parse(File.read(entry[:json_path]))
    inv = data["invoice"]
    supplier = inv.dig("parties", "supplier") || {}
    customer = inv.dig("parties", "customer") || {}
    totals = inv.dig("money", "totals") || {}
    payment = inv["payment"] || {}
    flags = inv["flags"] || {}
    dates = inv["dates"] || {}

    base = [
      entry[:original], entry[:basename],
      inv["document_type"], inv["supplier_invoice_number"],
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

puts "  CSV  -> invoices.csv"
puts "\nDone. #{entries.size} originals + #{entries.size} JSON + #{entries.size} ISDOC + 1 CSV"
