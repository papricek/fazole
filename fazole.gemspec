# frozen_string_literal: true

require_relative "lib/fazole/version"

Gem::Specification.new do |spec|
  spec.name = "fazole"
  spec.version = Fazole::VERSION
  spec.authors = ["Papricek"]
  spec.email = ["patrikjira@gmail.com"]

  spec.summary = "Extract structured invoice data from images and generate ISDOC XML"
  spec.description = "Fazole extracts invoice data from images via Gemini API and generates ISDOC 6.0.2 XML."
  spec.homepage = "https://github.com/papricek/fazole"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/papricek/fazole"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_llm"
  spec.add_dependency "builder"
  spec.add_dependency "caxlsx"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
