# frozen_string_literal: true

require 'json'

module Fazole
  class Extractor
    def initialize(image:, requirements:, model:)
      @image = image.to_s
      @requirements = requirements
      @model = model
    end

    def call
      response = RubyLLM.chat(model: @model).ask(prompt, with: @image)
      JSON.parse(response.content)
    rescue JSON::ParserError => e
      raise ExtractionError, "Failed to parse LLM response as JSON: #{e.message}"
    end

    private

    def prompt
      <<~PROMPT
        You are an invoice data extraction assistant. Extract structured data from the attached invoice image.

        Follow this schema exactly (return valid JSON matching this YAML specification):

        #{@requirements}

        Rules:
        - Return ONLY valid JSON, no markdown fences, no commentary.
        - Use null for fields you cannot determine from the image.
        - Use decimal strings for all monetary amounts (e.g. "1451.40", not 1451.4).
        - Dates must be ISO-8601 format.
        - Set extraction.status to "parsed" and provide confidence scores.
      PROMPT
    end
  end
end
