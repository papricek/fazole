# frozen_string_literal: true

require "builder"
require "bigdecimal"
require "bigdecimal/util"
require "digest"

module Fazole
  class IsdocBuilder
    NAMESPACE = "http://isdoc.cz/namespace/2013"
    VERSION = "6.0.2"
    VAT_CALCULATION_METHOD = "0"
    PAYMENT_MEANS_CODE = "42"

    DOCUMENT_TYPE_MAP = {
      "received_invoice" => "1",
      "issued_invoice" => "1",
      "credit_note" => "2",
      "advance_invoice" => "4",
      "proforma" => "6",
      "receipt" => "7",
      "other" => "1"
    }.freeze

    UNIT_CODE_MAP = {
      "pcs" => "C62", "ks" => "C62", "piece" => "C62", "pieces" => "C62",
      "L" => "LTR", "l" => "LTR", "liter" => "LTR", "litre" => "LTR",
      "kg" => "KGM", "g" => "GRM",
      "m" => "MTR", "km" => "KMT",
      "m2" => "MTK", "m3" => "MTQ",
      "h" => "HUR", "hod" => "HUR",
      "kWh" => "KWH", "kwh" => "KWH", "MWh" => "MWH", "mwh" => "MWH",
      "den" => "DAY", "day" => "DAY",
      "month" => "MON", "mesic" => "MON"
    }.freeze

    BANKS = {
      "0100" => { name: "Komerční banka", bic: "KOMBCZPP" },
      "0300" => { name: "ČSOB", bic: "CEKOCZPP" },
      "0600" => { name: "MONETA Money Bank", bic: "AGBACZPP" },
      "0710" => { name: "Česká národní banka", bic: "CNBACZPP" },
      "0800" => { name: "Česká spořitelna", bic: "GIBACZPX" },
      "2010" => { name: "Fio banka", bic: "FIOBCZPP" },
      "2020" => { name: "MUFG Bank", bic: "BOTKCZPP" },
      "2030" => { name: "Citfin", bic: "CITFCZPP" },
      "2060" => { name: "Citfin", bic: "CITFCZPP" },
      "2070" => { name: "Moravský Peněžní Ústav – spořitelní družstvo", bic: "MPUBCZPP" },
      "2100" => { name: "Hypoteční banka", bic: "HYPOCSPP" },
      "2200" => { name: "Peněžní dům", bic: "PENECZPP" },
      "2220" => { name: "Artesa", bic: "ARTTCZPP" },
      "2240" => { name: "Poštovní spořitelna", bic: "POBNCZPP" },
      "2250" => { name: "Banka CREDITAS", bic: "CTASCZ22" },
      "2260" => { name: "NEY spořitelní družstvo", bic: "YNEYCZPP" },
      "2310" => { name: "ZUNO BANK", bic: "ZUNOCZPP" },
      "2600" => { name: "Citibank", bic: "CITICZPX" },
      "2700" => { name: "UniCredit Bank Czech Republic and Slovakia", bic: "BACXCZPP" },
      "3030" => { name: "Air Bank", bic: "AIRACZPP" },
      "3050" => { name: "BNP Paribas Personal Finance SA", bic: "CCCZCZPP" },
      "3060" => { name: "PKO BP", bic: "BPKOCZPP" },
      "3500" => { name: "ING Bank", bic: "INGBCZPP" },
      "4000" => { name: "Expobank CZ", bic: "EXPNCZPP" },
      "4300" => { name: "Českomoravská záruční a rozvojová banka", bic: "CMZRCZP1" },
      "5500" => { name: "Raiffeisenbank", bic: "RZBCCZPP" },
      "5800" => { name: "J&T BANKA", bic: "JTBPCZPP" },
      "6000" => { name: "PPF banka", bic: "PMBPCZPP" },
      "6100" => { name: "Equa bank", bic: "EQBKCZPP" },
      "6200" => { name: "COMMERZBANK", bic: "COBACZPX" },
      "6210" => { name: "mBank", bic: "BREXCZPP" },
      "6300" => { name: "BNP Paribas Fortis SA/NV", bic: "GEBACZPP" },
      "6700" => { name: "Všeobecná úverová banka", bic: "SUBACZPP" },
      "6800" => { name: "Sberbank", bic: "VBOECZ2X" },
      "7910" => { name: "Deutsche Bank", bic: "DEUTCZPX" },
      "7940" => { name: "Waldviertler Sparkasse Bank AG", bic: "SPWTCZPP" },
      "7950" => { name: "Raiffeisen stavební spořitelna", bic: "RZSTAT2X" },
      "7960" => { name: "ČMSS", bic: "CHMFCZPP" },
      "7970" => { name: "Wüstenrot - stavební spořitelna", bic: "WUSTCZPP" },
      "7990" => { name: "Modrá pyramida stavební spořitelna", bic: "BPPFCZP1" },
      "8030" => { name: "Volksbank Raiffeisenbank Nordoberpfalz eG", bic: "GENODEF1WEV" },
      "8040" => { name: "Oberbank AG", bic: "OBKLCZ2X" },
      "8060" => { name: "Stavební spořitelna České spořitelny", bic: "BSCZC" },
      "8090" => { name: "Česká exportní banka", bic: "CEXBCZPP" },
      "8150" => { name: "HSBC Bank plc", bic: "MIDLCZPP" },
      "8200" => { name: "PRIVAT BANK der Raiffeisenlandesbank Oberösterreich Aktiengesellschaft", bic: "RVSOCZPP" },
      "8220" => { name: "Payment Execution s.r.o.", bic: "" },
      "8230" => { name: "EEPAYS s.r.o.", bic: "" },
      "8240" => { name: "Družstevní záložna Kredit", bic: "KREBCZPP" },
      "8250" => { name: "Bank of China (CEE) Ltd. Prague Branch", bic: "BKCNCZPP" }
    }.freeze

    def initialize(invoice_data)
      @data = invoice_data.is_a?(Hash) ? invoice_data : raise(Error, "invoice_data must be a Hash")
      @invoice = @data["invoice"] || @data[:invoice] || raise(Error, "missing 'invoice' key in data")
    end

    def call
      xml = Builder::XmlMarkup.new(indent: 2)
      xml.instruct! :xml, version: "1.0", encoding: "utf-8"
      xml.Invoice("xmlns" => NAMESPACE, "version" => VERSION) do
        build_header(xml)
        build_parties(xml)
        build_invoice_lines(xml)
        build_tax_total(xml)
        build_monetary_total(xml)
        build_payment(xml)
      end
      xml.target!
    end

    private

    def build_header(xml)
      xml.DocumentType document_type
      xml.ID dig("supplier_invoice_number") || dig("id")
      xml.UUID deterministic_uuid
      xml.IssueDate dig("dates", "issue_date") || ""
      xml.TaxPointDate dig("dates", "taxable_supply_date") || dig("dates", "issue_date") || ""
      xml.VATApplicable vat_applicable?
      xml.ElectronicPossibilityAgreementReference
      xml.Note note_text
      xml.LocalCurrencyCode dig("money", "currency") || "CZK"
      xml.CurrRate "1.0"
      xml.RefCurrRate "1"
    end

    def build_parties(xml)
      supplier = dig("parties", "supplier") || {}
      customer = dig("parties", "customer") || {}

      build_party_section(xml, "AccountingSupplierParty", supplier)
      build_party_section(xml, "SellerSupplierParty", supplier)
      build_party_section(xml, "AccountingCustomerParty", customer)
      build_party_section(xml, "BuyerCustomerParty", customer)
    end

    def build_party_section(xml, section_name, party)
      xml.__send__(section_name) do
        xml.Party do
          xml.PartyIdentification do
            xml.ID party["ico"] || ""
          end

          name = party["name"] || party["legal_name"]
          if name
            xml.PartyName do
              xml.Name name
            end
          end

          address = party["address"]
          if address
            xml.PostalAddress do
              xml.StreetName address["street"] if address["street"]
              xml.BuildingNumber
              xml.CityName address["city"] if address["city"]
              xml.PostalZone address["postal_code"] if address["postal_code"]
              xml.Country do
                xml.IdentificationCode address["country_code"] || "CZ"
                xml.Name country_name_for(address["country_code"] || "CZ")
              end
            end
          end

          dic = party["dic"]
          if dic
            xml.PartyTaxScheme do
              xml.CompanyID dic
              xml.TaxScheme "VAT"
            end
          end
        end
      end
    end

    def build_invoice_lines(xml)
      items = dig("line_items") || []

      xml.InvoiceLines do
        items.each do |item|
          xml.InvoiceLine do
            xml.ID item["position"].to_s
            xml.InvoicedQuantity(format_quantity(item["quantity"]), unitCode: unit_code_for(item["unit"]))
            xml.LineExtensionAmount format_decimal(item["net_amount"])
            xml.LineExtensionAmountTaxInclusive format_decimal(item["gross_amount"])
            xml.LineExtensionTaxAmount format_decimal(item["vat_amount"])

            if item["unit_price_net"]
              xml.UnitPrice format_decimal(item["unit_price_net"])
              xml.UnitPriceTaxInclusive format_decimal(item["unit_price_gross"])
            end

            xml.ClassifiedTaxCategory do
              xml.Percent format_rate(item["vat_rate"])
              xml.VATCalculationMethod VAT_CALCULATION_METHOD
            end

            xml.Item do
              xml.Description item["description"] || ""
              if item["product_code"]
                xml.SellersItemIdentification do
                  xml.ID item["product_code"]
                end
              end
            end
          end
        end
      end
    end

    def build_tax_total(xml)
      breakdowns = dig("money", "vat_breakdown") || []

      xml.TaxTotal do
        breakdowns.each do |entry|
          taxable = to_decimal(entry["base"])
          tax = to_decimal(entry["vat"])
          inclusive = to_decimal(entry["gross"]) || (taxable + tax)

          xml.TaxSubTotal do
            xml.TaxableAmount format_decimal(taxable)
            xml.TaxAmount format_decimal(tax)
            xml.TaxInclusiveAmount format_decimal(inclusive)
            xml.AlreadyClaimedTaxableAmount "0.00"
            xml.AlreadyClaimedTaxAmount "0.00"
            xml.AlreadyClaimedTaxInclusiveAmount "0.00"
            xml.DifferenceTaxableAmount format_decimal(taxable)
            xml.DifferenceTaxAmount format_decimal(tax)
            xml.DifferenceTaxInclusiveAmount format_decimal(inclusive)
            xml.TaxCategory do
              xml.Percent format_rate(entry["rate"])
            end
          end
        end

        total_tax = breakdowns.sum { |e| to_decimal(e["vat"]) }
        xml.TaxAmount format_decimal(total_tax)
      end
    end

    def build_monetary_total(xml)
      totals = dig("money", "totals") || {}
      net = to_decimal(totals["net_total"])
      gross = to_decimal(totals["gross_total"])
      amount_due = to_decimal(totals["amount_due"]) || gross

      xml.LegalMonetaryTotal do
        xml.TaxExclusiveAmount format_decimal(net)
        xml.TaxInclusiveAmount format_decimal(gross)
        xml.AlreadyClaimedTaxExclusiveAmount "0.00"
        xml.AlreadyClaimedTaxInclusiveAmount "0.00"
        xml.DifferenceTaxExclusiveAmount format_decimal(net)
        xml.DifferenceTaxInclusiveAmount format_decimal(gross)
        xml.PayableRoundingAmount "0.00"
        xml.PaidDepositsAmount "0.00"
        xml.PayableAmount format_decimal(amount_due)
      end
    end

    def build_payment(xml)
      payment = dig("payment") || {}
      return unless payment["method"] == "bank_transfer"

      account_local = payment["account_number_local"]
      return unless account_local

      account_number, bank_code = account_local.split("/")
      return unless account_number && bank_code

      due_date = dig("dates", "due_date")
      return unless due_date

      cleaned_account = account_number.delete("-")
      iban = payment["iban"] || compute_iban(cleaned_account, bank_code)
      bank_info = BANKS[bank_code] || { name: "", bic: "" }
      bic = payment["bic"] || bank_info[:bic]
      variable_symbol = payment["variable_symbol"]
      gross = to_decimal(dig("money", "totals", "gross_total"))

      xml.PaymentMeans do
        xml.Payment do
          xml.PaidAmount format_decimal(gross)
          xml.PaymentMeansCode PAYMENT_MEANS_CODE
          xml.Details do
            xml.PaymentDueDate due_date
            xml.ID cleaned_account
            xml.BankCode bank_code
            xml.Name bank_info[:name]
            xml.IBAN iban
            xml.BIC bic
            xml.VariableSymbol variable_symbol if variable_symbol
          end
        end
      end
    end

    # --- helpers ---

    def dig(*keys)
      @invoice.dig(*keys)
    end

    def document_type
      doc_type = dig("document_type") || "other"

      if dig("flags", "simplified_tax_document")
        "7"
      else
        DOCUMENT_TYPE_MAP[doc_type] || "1"
      end
    end

    def deterministic_uuid
      id = dig("id") || dig("supplier_invoice_number") || ""
      digest = Digest::MD5.hexdigest(id)
      [ digest[0..7], digest[8..11], digest[12..15], digest[16..19], digest[20..31] ].join("-")
    end

    def vat_applicable?
      !dig("flags", "reverse_charge")
    end

    def note_text
      notes = []
      notes << "Daň odvede zákazník (reverse charge)." if dig("flags", "reverse_charge")
      notes.join(" ")
    end

    def country_name_for(code)
      { "CZ" => "Česká republika", "SK" => "Slovenská republika", "DE" => "Německo", "AT" => "Rakousko",
        "PL" => "Polsko" }[code] || code
    end

    def unit_code_for(unit)
      return "C62" unless unit

      UNIT_CODE_MAP[unit] || unit
    end

    def to_decimal(value)
      return BigDecimal("0") if value.nil?

      BigDecimal(value.to_s)
    end

    def format_decimal(value)
      "%.2f" % to_decimal(value).round(2)
    end

    def format_quantity(value)
      d = to_decimal(value)
      int = d.truncate
      d == int ? "%.2f" % d : d.to_s("F")
    end

    def format_rate(value)
      return "0" if value.nil?

      BigDecimal(value.to_s).to_i.to_s
    end

    def compute_iban(account_id, bank_code)
      country_code = "CZ"
      bank_code_padded = bank_code.rjust(4, "0")
      account_padded = account_id.rjust(16, "0")

      bban = "#{bank_code_padded}#{account_padded}"
      iban_check_string = "#{bban}#{country_code.bytes.map { |b| b - 55 }.join}00"

      remainder = iban_check_string.chars.each_slice(9).reduce(0) do |acc, chunk|
        (acc.to_s + chunk.join).to_i % 97
      end

      check_digits = (98 - remainder).to_s.rjust(2, "0")
      "#{country_code}#{check_digits}#{bban}"
    end
  end
end
