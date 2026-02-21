# frozen_string_literal: true

module Fazole
  class Configuration
    attr_accessor :gemini_api_key, :model

    def initialize
      @model = "gemini-3-flash-preview"
    end

    def apply!
      RubyLLM.configure do |config|
        config.gemini_api_key = gemini_api_key
      end
    end
  end
end
