# frozen_string_literal: true

module Wallets
  module RecurringTransactionRules
    class ValidateService < BaseService
      def initialize(params:)
        @params = params
        super
      end

      def call
        return false unless valid_trigger?
        return false unless valid_method?
        return false unless valid_credits?
        return false unless valid_metadata?
        return false unless valid_expiration_at?

        true
      end

      private

      attr_reader :params

      def trigger
        @trigger ||= params[:trigger]&.to_s
      end

      def method
        @method ||= params[:method]&.to_s
      end

      def valid_trigger?
        valid_interval_trigger? || valid_threshold_trigger?
      end

      def valid_interval_trigger?
        trigger == "interval" && RecurringTransactionRule.intervals.key?(params[:interval])
      end

      def valid_threshold_trigger?
        trigger == "threshold" && ::Validators::DecimalAmountService.new(params[:threshold_credits]).valid_decimal?
      end

      def valid_method?
        return valid_decimal?(params[:target_ongoing_balance]) if method == "target"

        true
      end

      def valid_credits?
        return true unless params[:paid_credits] || params[:granted_credits]

        params[:paid_credits] && valid_decimal?(params[:paid_credits]) ||
          params[:granted_credits] && valid_decimal?(params[:granted_credits])
      end

      def valid_decimal?(value)
        ::Validators::DecimalAmountService.new(value).valid_decimal?
      end

      def valid_metadata?
        ::Validators::MetadataValidator.new(params[:transaction_metadata]).valid?
      end

      def valid_expiration_at?
        return true if Validators::ExpirationDateValidator.valid?(params[:expiration_at])

        false
      end
    end
  end
end
