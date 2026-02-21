# frozen_string_literal: true

require "bundler/setup"
require "dotenv/load"
require "ruby_llm"
require "json"

RubyLLM.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY")
end

source_dir = File.expand_path("../data/source", __dir__)
requirements = File.read(File.join(source_dir, "requirements.yml"))

images = Dir.glob(File.join(source_dir, "*.{jpeg,jpg,png,gif,webp}")).sort
abort "No images found in #{source_dir}" if images.empty?

prompt = <<~PROMPT
  You are an invoice data extraction assistant. Extract structured data from the attached invoice image.

  Follow this schema exactly (return valid JSON matching this YAML specification):

  #{requirements}

  Rules:
  - Return ONLY valid JSON, no markdown fences, no commentary.
  - Use null for fields you cannot determine from the image.
  - Use decimal strings for all monetary amounts (e.g. "1451.40", not 1451.4).
  - Dates must be ISO-8601 format.
  - Set extraction.status to "parsed" and provide confidence scores.
PROMPT

output_dir = File.join(source_dir, "..", "output")
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

results = images.map do |image|
  puts "Processing #{File.basename(image)}..."
  chat = RubyLLM.chat(model: "gemini-3-flash-preview")
  response = chat.ask(prompt, with: image)
  json = JSON.parse(response.content)

  basename = File.basename(image, File.extname(image))
  output_file = File.join(output_dir, "#{basename}.json")
  File.write(output_file, JSON.pretty_generate(json))
  puts "  -> #{output_file}"

  json
end

puts "\nExtracted #{results.size} invoice(s)."
