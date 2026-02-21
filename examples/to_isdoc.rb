# frozen_string_literal: true

require "bundler/setup"
require "fazole"
require "json"

output_dir = File.expand_path("../data/output", __dir__)
json_files = Dir.glob(File.join(output_dir, "*.json")).sort
abort "No JSON files found in #{output_dir}" if json_files.empty?

json_files.each do |json_file|
  puts "Converting #{File.basename(json_file)}..."
  data = JSON.parse(File.read(json_file))
  xml = Fazole.to_isdoc(data)

  isdoc_file = json_file.sub(/\.json$/, ".isdoc")
  File.write(isdoc_file, xml)
  puts "  -> #{isdoc_file}"
end

puts "\nConverted #{json_files.size} file(s) to ISDOC."
