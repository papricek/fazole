# Invoice Data Extraction

Extract structured JSON data from invoice/receipt images using Google Gemini.

## Setup

1. Install dependencies:

```bash
bin/setup
```

2. Add your Gemini API key to `.env`:

```
GEMINI_API_KEY=your-key-here
```

## Library Usage

```ruby
require "fazole"

Fazole.configure do |config|
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY")
  config.model = "gemini-3-flash-preview" # optional, this is the default
end

requirements = File.read("data/source/requirements.yml")
result = Fazole.extract(image: "path/to/invoice.jpeg", requirements: requirements)

result["parties"]["supplier"]["name"] # => "Acme Corp"
```

## Example Script

1. Place invoice images (JPEG, PNG, GIF, WEBP) into `data/source/`.
2. Run the extraction:

```bash
bundle exec ruby examples/extract_invoice.rb
```

Each image is processed separately. Output JSON files are written to `data/output/`, one per image, named after the source file (e.g. `receipt.jpeg` -> `receipt.json`).

## How it works

The library reads a YAML requirements file that defines the full invoice schema (parties, dates, payment, VAT breakdown, line items, etc.). Each image is sent to `gemini-3-flash-preview` along with the schema, and the model returns structured JSON matching the specification.

## Schema

The output follows the structure defined in `data/source/requirements.yml`. Key sections:

| Section | Description |
|---------|-------------|
| `parties` | Supplier and customer details (name, IČO, DIČ, address) |
| `dates` | Issue date, DÚZP, due date |
| `payment` | Method, bank account, variable symbol, paid status |
| `money` | Currency, totals, VAT breakdown by rate |
| `line_items` | Individual items with quantities, prices, VAT |
| `flags` | Reverse charge, simplified tax document, intra-EU, etc. |
| `extraction` | Parse status and per-field confidence scores |

## Example

```
$ bundle exec ruby examples/extract_invoice.rb
Processing receipt.jpeg...
  -> data/output/receipt.json

Extracted 1 invoice(s).
```
