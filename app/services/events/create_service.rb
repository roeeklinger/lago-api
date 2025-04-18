# frozen_string_literal: true

module Events
  class CreateService < BaseService
    def initialize(organization:, params:, timestamp:, metadata:)
      @organization = organization
      @params = params
      @timestamp = timestamp
      @metadata = metadata
      super
    end

    def call
      event = Event.new
      event.organization_id = organization.id
      event.code = params[:code]
      event.transaction_id = params[:transaction_id]
      event.external_subscription_id = params[:external_subscription_id]
      event.properties = params[:properties] || {}
      event.metadata = metadata || {}
      event.timestamp = Time.zone.at(params[:timestamp] ? Float(params[:timestamp]) : timestamp)
      event.precise_total_amount_cents = params[:precise_total_amount_cents]

      expression_result = CalculateExpressionService.call(organization:, event:)
      return result.validation_failure!(errors: expression_result.error.message) unless expression_result.success?

      event.save! unless organization.clickhouse_events_store?

      result.event = event

      produce_kafka_event(event)
      Events::PostProcessJob.perform_later(event:) unless organization.clickhouse_events_store?

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    rescue ActiveRecord::RecordNotUnique
      result.single_validation_failure!(field: :transaction_id, error_code: "value_already_exist")
    rescue ArgumentError
      result.single_validation_failure!(field: :timestamp, error_code: "invalid_format")
    end

    private

    attr_reader :organization, :params, :timestamp, :metadata

    def produce_kafka_event(event)
      return if ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"].blank?
      return if ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"].blank?

      Karafka.producer.produce_async(
        topic: ENV["LAGO_KAFKA_RAW_EVENTS_TOPIC"],
        key: "#{organization.id}-#{event.external_subscription_id}",
        payload: {
          organization_id: organization.id,
          external_customer_id: event.external_customer_id,
          external_subscription_id: event.external_subscription_id,
          transaction_id: event.transaction_id,
          # NOTE: Removes trailing 'Z' to allow clickhouse parsing
          timestamp: event.timestamp.to_f.to_s,
          code: event.code,
          # NOTE: Default value to 0.0 is required for clickhouse parsing
          precise_total_amount_cents: event.precise_total_amount_cents.present? ? event.precise_total_amount_cents.to_s : "0.0",
          properties: event.properties,
          ingested_at: Time.zone.now.iso8601[...-1],
          source: "http_ruby",
          source_metadata: {
            api_post_processed: !organization.clickhouse_events_store?
          }
        }.to_json
      )
    end
  end
end
