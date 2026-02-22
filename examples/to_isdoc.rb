# frozen_string_literal: true

require 'bundler/setup'
require 'fazole'
require 'json'
require 'csv'
require 'caxlsx'

HEADERS = [
  'Původní soubor', 'Nový soubor', 'Typ dokladu', 'Číslo faktury',
  'Datum vystavení', 'DÚZP', 'Datum splatnosti',
  'Dodavatel', 'IČO dodavatele', 'DIČ dodavatele',
  'Ulice dodavatele', 'Město dodavatele', 'PSČ dodavatele',
  'Odběratel', 'IČO odběratele', 'DIČ odběratele',
  'Měna', 'Základ celkem', 'DPH celkem', 'Celkem s DPH', 'K úhradě',
  'Způsob platby', 'Variabilní symbol', 'Číslo účtu', 'IBAN',
  'Přenesená daň. povinnost', 'Zjednodušený daň. doklad',
  'Položka č.', 'Popis položky', 'Kód produktu', 'Množství', 'Jednotka',
  'Cena/ks bez DPH', 'Cena/ks s DPH', 'Základ', 'Sazba DPH %',
  'DPH', 'Celkem s DPH (řádek)', 'Spolehlivost extrakce'
].freeze

MONEY_COLS = [17, 18, 19, 20, 32, 33, 34, 36, 37].freeze
PCT_COLS = [35, 38].freeze

def invoice_rows(data, json_basename)
  inv = data['invoice']
  supplier = inv.dig('parties', 'supplier') || {}
  customer = inv.dig('parties', 'customer') || {}
  totals = inv.dig('money', 'totals') || {}
  payment = inv['payment'] || {}
  flags = inv['flags'] || {}
  dates = inv['dates'] || {}

  base = [
    data['_source_file'] || json_basename, json_basename,
    inv['document_type'], inv['supplier_invoice_number'],
    dates['issue_date'], dates['taxable_supply_date'], dates['due_date'],
    supplier['name'], supplier['ico'], supplier['dic'],
    supplier.dig('address', 'street'), supplier.dig('address', 'city'), supplier.dig('address', 'postal_code'),
    customer['name'], customer['ico'], customer['dic'],
    inv.dig('money', 'currency'), totals['net_total'], totals['vat_total'], totals['gross_total'], totals['amount_due'],
    payment['method'], payment['variable_symbol'], payment['account_number_local'], payment['iban'],
    flags['reverse_charge'], flags['simplified_tax_document']
  ]

  empty_base = [nil] * base.size
  items = inv['line_items'] || []
  rows = []

  if items.empty?
    rows << { base: base, line: [nil] * 11 + [inv.dig('extraction', 'confidence')], first: true }
  else
    items.each_with_index do |item, i|
      rows << {
        base: i.zero? ? base : empty_base,
        line: [
          item['position'], item['description'], item['product_code'],
          item['quantity'], item['unit'], item['unit_price_net'], item['unit_price_gross'],
          item['net_amount'], item['vat_rate'], item['vat_amount'], item['gross_amount'],
          i.zero? ? inv.dig('extraction', 'confidence') : nil
        ],
        first: i.zero?
      }
    end
  end

  rows
end

def generate_xlsx(xlsx_path, all_rows)
  pkg = Axlsx::Package.new
  wb = pkg.workbook

  header_style = wb.styles.add_style(
    bg_color: '1F4E79', fg_color: 'FFFFFF', b: true, sz: 10,
    alignment: { horizontal: :center, vertical: :center, wrap_text: true },
    border: { style: :thin, color: 'AAAAAA' }
  )
  invoice_style = wb.styles.add_style(
    bg_color: 'D6E4F0', sz: 9, b: true,
    border: { style: :thin, color: 'CCCCCC' }
  )
  invoice_money_style = wb.styles.add_style(
    bg_color: 'D6E4F0', sz: 9, b: true, format_code: '#,##0.00',
    border: { style: :thin, color: 'CCCCCC' }
  )
  invoice_pct_style = wb.styles.add_style(
    bg_color: 'D6E4F0', sz: 9, b: true, format_code: '0.0',
    border: { style: :thin, color: 'CCCCCC' }
  )
  line_style = wb.styles.add_style(
    sz: 9, border: { style: :thin, color: 'DDDDDD' }
  )
  line_money_style = wb.styles.add_style(
    sz: 9, format_code: '#,##0.00',
    border: { style: :thin, color: 'DDDDDD' }
  )
  line_pct_style = wb.styles.add_style(
    sz: 9, format_code: '0.0',
    border: { style: :thin, color: 'DDDDDD' }
  )

  wb.add_worksheet(name: 'Faktury') do |sheet|
    sheet.add_row HEADERS, style: header_style, height: 30

    all_rows.each do |row_data|
      values = row_data[:base] + row_data[:line]
      values = values.map.with_index do |v, col|
        if (MONEY_COLS.include?(col) || PCT_COLS.include?(col)) && v.is_a?(String) && v.match?(/\A-?\d/)
          v.to_f
        else
          v
        end
      end

      styles = if row_data[:first]
                 values.map.with_index do |_, col|
                   if MONEY_COLS.include?(col) then invoice_money_style
                   elsif PCT_COLS.include?(col) then invoice_pct_style
                   else invoice_style
                   end
                 end
               else
                 values.map.with_index do |_, col|
                   if MONEY_COLS.include?(col) then line_money_style
                   elsif PCT_COLS.include?(col) then line_pct_style
                   else line_style
                   end
                 end
               end
      sheet.add_row values, style: styles
    end

    sheet.auto_filter = 'A1:AM1'
    sheet.sheet_view.pane do |pane|
      pane.top_left_cell = 'A2'
      pane.state = :frozen
      pane.y_split = 1
    end

    sheet.column_widths(22, 30, 12, 16, 12, 12, 12, 25, 12, 14, 20, 14, 8, 20, 12, 14, 6, 12, 12, 12, 12, 12, 14, 18,
                        26, 8, 8, 6, 35, 12, 8, 6, 12, 12, 12, 8, 10, 12, 6)
  end

  pkg.serialize(xlsx_path)
end

# --- Main ---

output_dir = File.expand_path('../data/output', __dir__)
json_files = Dir.glob(File.join(output_dir, '*.json')).sort
abort "No JSON files found in #{output_dir}" if json_files.empty?

all_rows = []

json_files.each do |json_file|
  basename = File.basename(json_file, '.json')
  puts "Converting #{basename}..."
  data = JSON.parse(File.read(json_file))

  xml = Fazole.to_isdoc(data)
  File.write(json_file.sub(/\.json$/, '.isdoc'), xml)
  puts "  ISDOC -> #{basename}.isdoc"

  invoice_rows(data, basename).each { |row| all_rows << row }
end

csv_path = File.join(output_dir, 'invoices.csv')
CSV.open(csv_path, 'w', headers: HEADERS, write_headers: true) do |csv|
  all_rows.each { |row| csv << row[:base] + row[:line] }
end
puts '  CSV  -> invoices.csv'

xlsx_path = File.join(output_dir, 'invoices.xlsx')
generate_xlsx(xlsx_path, all_rows)
puts '  XLSX -> invoices.xlsx'

puts "\nDone. #{json_files.size} ISDOC + 1 CSV + 1 XLSX"
