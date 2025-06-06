# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::RefreshOngoingBalanceJob, type: :job do
  let(:wallet) { create(:wallet, ready_to_be_refreshed: true) }
  let(:result) { BaseService::Result.new }

  let(:refresh_service) do
    instance_double(Wallets::Balance::RefreshOngoingService)
  end

  before do
    allow(Wallets::Balance::RefreshOngoingService).to receive(:new).with(wallet:).and_return(refresh_service)
    allow(refresh_service).to receive(:call).and_return(result)
  end

  context "when wallet is not ready to be refreshed" do
    let(:wallet) { create(:wallet, ready_to_be_refreshed: false) }

    it "does not call the RefreshOngoingBalance service" do
      described_class.perform_now(wallet)
      expect(Wallets::Balance::RefreshOngoingService).not_to have_received(:new)
    end
  end

  it "delegates to the RefreshOngoingBalance service" do
    described_class.perform_now(wallet)
    expect(Wallets::Balance::RefreshOngoingService).to have_received(:new)
    expect(refresh_service).to have_received(:call)
  end

  context "when refresh wallet failed" do
    let(:result) { BaseService::Result.new.validation_failure!(errors: {tax_error: "error"}) }

    before do
      allow(refresh_service).to receive(:call).and_return(result)
    end

    it "fails with an error" do
      expect { described_class.perform_now(wallet) }.to raise_error(BaseService::ValidationFailure)
    end
  end
end
