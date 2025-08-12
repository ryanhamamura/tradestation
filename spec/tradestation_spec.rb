# frozen_string_literal: true

RSpec.describe(Tradestation) do
  it "has a version number" do
    expect(Tradestation::VERSION).not_to(be(nil))
  end

  it "can be configured" do
    expect do
      described_class.configure do |config|
        config.client_id = "test"
      end
    end.not_to(raise_error)
  end
end
