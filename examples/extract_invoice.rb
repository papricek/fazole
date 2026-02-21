# frozen_string_literal: true

require "bundler/setup"
require "dotenv/load"
require "fazole"
require "json"

Fazole.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY")
end

source_dir = File.expand_path("../data/source", __dir__)
requirements = File.read(File.join(source_dir, "requirements.yml"))

images = Dir.glob(File.join(source_dir, "*.{jpeg,jpg,png,gif,webp}")).sort
abort "No images found in #{source_dir}" if images.empty?

output_dir = File.join(source_dir, "..", "output")
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

results = images.map do |image|
  puts "Processing #{File.basename(image)}..."
  json = Fazole.extract(image: image, requirements: requirements)

  basename = File.basename(image, File.extname(image))
  output_file = File.join(output_dir, "#{basename}.json")
  File.write(output_file, JSON.pretty_generate(json))
  puts "  -> #{output_file}"

  json
end

puts "\nExtracted #{results.size} invoice(s)."
