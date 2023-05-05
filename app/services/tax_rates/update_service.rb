# frozen_string_literal: true

module TaxRates
  class UpdateService < BaseService
    def initialize(tax_rate:, params:)
      @tax_rate = tax_rate
      @params = params

      super
    end

    def call
      return result.not_found_failure!(resource: 'tax_rate') unless tax_rate

      tax_rate.update!(
        name: params[:name],
        code: params[:code],
        value: params[:value],
        description: params[:description],
      )

      # TODO: Refresh only invoices related to the corresponding customers.
      draft_invoices = tax_rate.organization.invoices.draft
      Invoices::RefreshBatchJob.perform_later(draft_invoices.pluck(:id))

      result.tax_rate = tax_rate
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :tax_rate, :params
  end
end