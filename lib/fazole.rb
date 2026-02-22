# frozen_string_literal: true

require 'ruby_llm'

require_relative 'fazole/version'
require_relative 'fazole/configuration'
require_relative 'fazole/extractor'
require_relative 'fazole/isdoc_builder'

module Fazole
  class Error < StandardError; end
  class ExtractionError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      configuration.apply!
    end

    def extract(image:, requirements:)
      Extractor.new(image: image, requirements: requirements, model: configuration.model).call
    end

    def to_isdoc(invoice_data)
      IsdocBuilder.new(invoice_data).call
    end
  end
end
