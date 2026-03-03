# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'fazole'
require 'json'
require 'csv'
require 'fileutils'

# --- Configuration ---

Fazole.configure do |config|
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY')
end

source_dir = File.expand_path('../data/source', __dir__)
input_csv = File.join(source_dir, 'contacts_sample.csv')
abort "Input file not found: #{input_csv}" unless File.exist?(input_csv)

output_dir = File.expand_path('../data/output', __dir__)
FileUtils.mkdir_p(output_dir)

# --- Read input CSV ---

companies = CSV.read(input_csv, headers: true).map do |row|
  { company_name: row['company_name'], ico: row['ico'] }
end

abort 'No companies found in input CSV' if companies.empty?
puts "Found #{companies.size} company/companies to look up.\n\n"

# --- Find contacts ---

results = companies.each_with_index.map do |company, i|
  puts "#{i + 1}/#{companies.size} Looking up: #{company[:company_name]} (IČO #{company[:ico]})..."

  result = Fazole.find_contact(company_name: company[:company_name], ico: company[:ico])
  puts "  -> Found #{(result['contacts'] || []).size} contact(s), confidence: #{result['confidence']}"
  result
rescue Fazole::Error => e
  puts "  !! Error: #{e.message}"
  { 'company_name' => company[:company_name], 'ico' => company[:ico],
    'contacts' => [], 'sources' => [], 'confidence' => 0.0, 'error' => e.message }
ensure
  sleep 2 if i < companies.size - 1 # rate limiting
end

# --- Output JSON ---

json_output = JSON.pretty_generate(results)

json_path = File.join(output_dir, 'contacts.json')
File.write(json_path, json_output)
puts "\n#{json_output}"
puts "\n-> #{json_path}"
