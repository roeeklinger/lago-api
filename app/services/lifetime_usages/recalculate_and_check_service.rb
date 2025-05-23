# frozen_string_literal: true

module LifetimeUsages
  class RecalculateAndCheckService < BaseService
    Result = BaseResult[:invoice]

    def initialize(lifetime_usage:)
      @lifetime_usage = lifetime_usage

      super
    end

    def call
      LifetimeUsages::CalculateService.call!(lifetime_usage:)
      usage_thresholds = LifetimeUsages::UsageThresholds::CheckService.call!(lifetime_usage:, progressive_billed_amount:).passed_thresholds
      if usage_thresholds.any?
        usage_thresholds.each do |usage_threshold|
          SendWebhookJob.perform_later("subscription.usage_threshold_reached", subscription, usage_threshold:)
        end
        invoice_result = Invoices::ProgressiveBillingService.call(usage_thresholds:, lifetime_usage:)
        # If there is tax error, invoice is marked as failed and it can be retried manually
        invoice_result.raise_if_error! unless tax_error?(invoice_result)
        result.invoice = invoice_result.invoice
      end
      result
    end

    private

    attr_reader :lifetime_usage
    delegate :subscription, to: :lifetime_usage

    def progressive_billed_amount
      Subscriptions::ProgressiveBilledAmount.call!(subscription:).progressive_billed_amount
    end

    def tax_error?(result)
      return false if result.success?

      result.error.is_a?(BaseService::UnknownTaxFailure)
    end
  end
end
