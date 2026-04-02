# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fazole is a Ruby gem that extracts structured invoice data from images using Google Gemini's vision API, then generates ISDOC 6.0.2 XML documents, CSV, and XLSX reports. Designed for Czech/Slovak accounting with full VAT, reverse charge, and IBAN support.

- **Ruby >= 3.2.0**
- **LLM:** Google Gemini via `ruby_llm` gem
- **Input:** Invoice images (JPEG, PNG, GIF, WEBP, PDF)
- **Output:** Structured JSON, ISDOC XML, CSV, XLSX

## Commands

```bash
bin/setup            # Install dependencies
bin/console          # IRB session with gem loaded
bundle exec rake     # Run default tasks (currently empty)
```

## Configuration

```ruby
Fazole.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY")
  config.model = "gemini-3-flash-preview"  # optional, this is the default
end
```

Environment variables: `GEMINI_API_KEY` (required), `FAZOLE_MODEL` (optional override).

## Architecture

| File | Responsibility |
|------|----------------|
| `lib/fazole.rb` | Main module; `configure`, `extract`, `to_isdoc` class methods |
| `lib/fazole/configuration.rb` | API key and model config; applies via `RubyLLM.configure` |
| `lib/fazole/extractor.rb` | Sends invoice image to Gemini, validates JSON response |
| `lib/fazole/isdoc_builder.rb` | Builds ISDOC 6.0.1 XML — VAT breakdown, party structure, IBAN computation from Czech account number + bank code, 88-entry Czech bank code→BIC mapping |
| `lib/fazole/version.rb` | Version constant (0.1.0) |

### Public API

```ruby
# Extract invoice data from image
data = Fazole.extract(image: "path/to/invoice.pdf", requirements: "requirements/dph.yml")

# Convert extracted data to ISDOC XML
xml = Fazole.to_isdoc(data)
```

### Extraction Schema

`requirements/dph.yml` (148 lines) defines the full invoice structure for LLM extraction:
- 10 sections: identity, parties, dates, payment, money, line items, accounting, FX, compliance flags, extraction metadata
- Full Czech/EU VAT support with rate breakdown
- ISDOC-compliant party structure with IČO/DIČ
- Confidence scores and extraction warnings per field

### Error Classes

- `Fazole::Error` — base error
- `Fazole::ExtractionError` — raised when JSON parsing fails from LLM response

## Dependencies

| Gem | Purpose |
|-----|---------|
| `ruby_llm` | Gemini API integration |
| `builder` | XML generation |
| `caxlsx` | XLSX generation |
| `csv` | CSV handling |

Dev: `dotenv`, `rubocop-rails-omakase`

## Examples

Three scripts in `examples/`:
- `extract_invoice.rb` — full workflow: read images → extract → JSON + ISDOC + CSV + XLSX
- `to_isdoc.rb` — batch-convert pre-extracted JSON → ISDOC XML
- `gemini_test.rb` — API connectivity test

Test data: 14 Czech invoice PDFs in `data/source/`.

## Code Style

- `frozen_string_literal: true` everywhere
- Follow `rubocop-rails-omakase` style guide
- Double quotes for strings
- No test framework configured yet
