# frozen_string_literal: true

require "json"

module Fazole
  class ContactFinder
    def initialize(company_name:, ico:, model:)
      @company_name = company_name
      @ico = ico
      @model = model
    end

    def call
      chat = RubyLLM.chat(model: @model)
        .with_params(tools: [{ google_search: {} }])
      response = chat.ask(prompt)
      JSON.parse(extract_json(response.content))
    rescue JSON::ParserError => e
      raise ExtractionError, "Failed to parse LLM response as JSON: #{e.message}"
    end

    private

    def prompt
      <<~PROMPT
        Vyhledej kontaktní údaje firmy "#{@company_name}" s IČO #{@ico}.
        Najdi telefonní číslo a email jednatele nebo někoho z vedení této firmy.

        Vrať POUZE validní JSON, bez markdown, bez komentářů, bez textu před ani za JSON.
        Přesný formát:

        {
          "company_name": "string, oficiální název firmy",
          "ico": "string, IČO firmy",
          "contacts": [
            {
              "name": "string, celé jméno osoby",
              "role": "string, pozice ve firmě (jednatel, ředitel, člen představenstva, ...)",
              "phone": "string nebo null, telefonní číslo v mezinárodním formátu (+420...)",
              "email": "string nebo null, emailová adresa"
            }
          ],
          "sources": ["string, URL stránek ze kterých údaje pochází"],
          "confidence": "number, 0.0–1.0, spolehlivost nalezených údajů"
        }

        Pravidla:
        - Vrať POUZE JSON objekt, nic jiného.
        - Telefonní čísla v mezinárodním formátu (+420 xxx xxx xxx).
        - Pokud údaj nelze najít, použij null.
        - V contacts uveď jen osoby, u kterých jsi našel alespoň telefon nebo email.
        - V sources uveď konkrétní URL stránek, ze kterých jsi čerpal.
      PROMPT
    end

    def extract_json(text)
      # Strip markdown code fences if present
      if text =~ /```(?:json)?\s*\n?(.*?)\n?\s*```/m
        $1.strip
      else
        text.strip
      end
    end
  end
end
