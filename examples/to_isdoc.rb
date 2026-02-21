# frozen_string_literal: true

require "bundler/setup"
require "fazole"
require "json"
require "csv"

output_dir = File.expand_path("../data/output", __dir__)
json_files = Dir.glob(File.join(output_dir, "*.json")).sort
abort "No JSON files found in #{output_dir}" if json_files.empty?

json_files.each do |json_file|
  puts "Converting #{File.basename(json_file)}..."
  data = JSON.parse(File.read(json_file))
  xml = Fazole.to_isdoc(data)

  isdoc_file = json_file.sub(/\.json$/, ".isdoc")
  File.write(isdoc_file, xml)
  puts "  ISDOC -> #{File.basename(isdoc_file)}"
end

CSV_HEADERS = [
  "Soubor", "Typ dokladu", "Číslo faktury",
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

puts "  CSV  -> invoices.csv"
puts "\nDone. #{json_files.size} ISDOC + 1 CSV"
