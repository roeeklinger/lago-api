# frozen_string_literal: true

module Integrations
  module Aggregator
    class PerformSyncJob < ApplicationJob
      queue_as 'integrations'

      retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 3

      def perform(integration:, sync_tax_items: false)
        sync_result = Integrations::Aggregator::SyncService.call(integration:)
        sync_result.raise_if_error!

        items_result = Integrations::Aggregator::ItemsService.call(integration:)
        items_result.raise_if_error!

        if sync_tax_items
          tax_items_result = Integrations::Aggregator::TaxItemsService.call(integration:)
          tax_items_result.raise_if_error!
        end
      end
    end
  end
end
