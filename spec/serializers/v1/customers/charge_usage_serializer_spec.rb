# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Customers::ChargeUsageSerializer do
  subject(:serializer) { described_class.new(usage, root_name: "charges") }

  let(:charge) { create(:standard_charge) }
  let(:billable_metric) { charge.billable_metric }

  let(:usage) do
    [
      OpenStruct.new(
        charge_id: charge.id,
        billable_metric:,
        charge:,
        units: 10,
        events_count: 12,
        amount_cents: 100,
        amount_currency: "EUR",
        invoice_display_name: charge.invoice_display_name,
        lago_id: billable_metric.id,
        name: billable_metric.name,
        code: billable_metric.code,
        aggregation_type: billable_metric.aggregation_type,
        grouped_by: {"card_type" => "visa"}
      )
    ]
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the fee" do
    aggregate_failures do
      expect(result["charges"].first).to include(
        "units" => "10.0",
        "events_count" => 12,
        "amount_cents" => 100,
        "amount_currency" => "EUR",
        "charge" => {
          "lago_id" => charge.id,
          "charge_model" => charge.charge_model,
          "invoice_display_name" => charge.invoice_display_name
        },
        "billable_metric" => {
          "lago_id" => billable_metric.id,
          "name" => billable_metric.name,
          "code" => billable_metric.code,
          "aggregation_type" => billable_metric.aggregation_type
        },
        "filters" => [],
        "grouped_usage" => [
          {
            "amount_cents" => 100,
            "events_count" => 12,
            "units" => "10.0",
            "grouped_by" => {"card_type" => "visa"},
            "filters" => []
          }
        ]
      )
    end
  end

  describe "#filters" do
    let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }
    let(:charge_filter) { create(:charge_filter, charge:, invoice_display_name: nil) }

    let(:usage) do
      [
        OpenStruct.new(
          charge_id: charge.id,
          billable_metric:,
          charge:,
          units: "10.0",
          events_count: 12,
          amount_cents: 100,
          amount_currency: "EUR",
          invoice_display_name: charge.invoice_display_name,
          lago_id: billable_metric.id,
          name: billable_metric.name,
          code: billable_metric.code,
          aggregation_type: billable_metric.aggregation_type,
          grouped_by: {"card_type" => "visa"},
          charge_filter:
        )
      ]
    end

    it "returns filters array" do
      expect(result["charges"].first["filters"].first).to include(
        "units" => "10.0",
        "amount_cents" => 100,
        "events_count" => 12,
        "invoice_display_name" => charge_filter.invoice_display_name,
        "values" => {}
      )

      expect(result["charges"].first["grouped_usage"].first["filters"].first).to include(
        "units" => "10.0",
        "amount_cents" => 100,
        "events_count" => 12,
        "invoice_display_name" => charge_filter.invoice_display_name,
        "values" => {}
      )
    end
  end
end
