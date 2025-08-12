# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Tradestation::Configuration) do
  let(:configuration) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(configuration.environment).to(eq(:sandbox))
      expect(configuration.scopes).to(eq(["openid", "profile"]))
      expect(configuration.timeout).to(eq(30))
      expect(configuration.client_id).to(be_nil)
      expect(configuration.client_secret).to(be_nil)
      expect(configuration.redirect_uri).to(be_nil)
    end
  end

  describe "#base_url" do
    context "with sandbox environment" do
      it "returns sandbox URL" do
        configuration.environment = :sandbox
        expect(configuration.base_url).to(eq("https://sim-api.tradestation.com"))
      end
    end

    context "with production environment" do
      it "returns production URL" do
        configuration.environment = :production
        expect(configuration.base_url).to(eq("https://api.tradestation.com"))
      end
    end

    context "with invalid environment" do
      it "raises ConfigurationError" do
        configuration.environment = :invalid
        expect { configuration.base_url }.to(raise_error(
          Tradestation::ConfigurationError,
          "Invalid environment: invalid",
        ))
      end
    end
  end

  describe "#auth_url" do
    it "returns the authorization URL" do
      configuration.environment = :sandbox
      expect(configuration.auth_url).to(eq("https://sim-api.tradestation.com/authorize"))
    end
  end

  describe "#token_url" do
    it "returns the token URL" do
      configuration.environment = :sandbox
      expect(configuration.token_url).to(eq("https://sim-api.tradestation.com/token"))
    end
  end

  describe "#api_url" do
    it "returns the API URL" do
      configuration.environment = :sandbox
      expect(configuration.api_url).to(eq("https://sim-api.tradestation.com"))
    end
  end

  describe "#validate!" do
    context "with valid configuration" do
      before do
        configuration.client_id = "test_client_id"
        configuration.client_secret = "test_client_secret"
        configuration.redirect_uri = "http://localhost:3000/callback"
      end

      it "returns true" do
        expect(configuration.validate!).to(be(true))
      end
    end

    context "with missing client_id" do
      before do
        configuration.client_secret = "test_client_secret"
        configuration.redirect_uri = "http://localhost:3000/callback"
      end

      it "raises ConfigurationError" do
        expect { configuration.validate! }.to(raise_error(
          Tradestation::ConfigurationError,
          "client_id is required",
        ))
      end
    end

    context "with empty client_id" do
      before do
        configuration.client_id = ""
        configuration.client_secret = "test_client_secret"
        configuration.redirect_uri = "http://localhost:3000/callback"
      end

      it "raises ConfigurationError" do
        expect { configuration.validate! }.to(raise_error(
          Tradestation::ConfigurationError,
          "client_id is required",
        ))
      end
    end

    context "with missing client_secret" do
      before do
        configuration.client_id = "test_client_id"
        configuration.redirect_uri = "http://localhost:3000/callback"
      end

      it "raises ConfigurationError" do
        expect { configuration.validate! }.to(raise_error(
          Tradestation::ConfigurationError,
          "client_secret is required",
        ))
      end
    end

    context "with missing redirect_uri" do
      before do
        configuration.client_id = "test_client_id"
        configuration.client_secret = "test_client_secret"
      end

      it "raises ConfigurationError" do
        expect { configuration.validate! }.to(raise_error(
          Tradestation::ConfigurationError,
          "redirect_uri is required",
        ))
      end
    end

    context "with invalid environment" do
      before do
        configuration.client_id = "test_client_id"
        configuration.client_secret = "test_client_secret"
        configuration.redirect_uri = "http://localhost:3000/callback"
        configuration.environment = :invalid
      end

      it "raises ConfigurationError" do
        expect { configuration.validate! }.to(raise_error(
          Tradestation::ConfigurationError,
          "Invalid environment: invalid",
        ))
      end
    end
  end

  describe "#reset!" do
    before do
      configuration.client_id = "test_client_id"
      configuration.client_secret = "test_client_secret"
      configuration.redirect_uri = "http://localhost:3000/callback"
      configuration.environment = :production
      configuration.scopes = ["custom", "scope"]
      configuration.timeout = 60
    end

    it "resets all values to defaults" do
      configuration.reset!

      expect(configuration.client_id).to(be_nil)
      expect(configuration.client_secret).to(be_nil)
      expect(configuration.redirect_uri).to(be_nil)
      expect(configuration.environment).to(eq(:sandbox))
      expect(configuration.scopes).to(eq(["openid", "profile"]))
      expect(configuration.timeout).to(eq(30))
    end
  end
end

RSpec.describe(Tradestation) do
  describe ".configure" do
    before { described_class.reset_configuration! }

    context "without a block" do
      it "returns the configuration instance" do
        config = described_class.configure
        expect(config).to(be_a(Tradestation::Configuration))
      end

      it "creates a configuration if none exists" do
        # After reset_configuration!, we have a fresh configuration instance
        initial_config = described_class.configuration
        expect(initial_config).to(be_a(Tradestation::Configuration))

        # configure should return the same instance
        configured = described_class.configure
        expect(configured).to(be(initial_config))
      end
    end

    context "with a block" do
      it "yields the configuration instance" do
        described_class.configure do |config|
          config.client_id = "test_id"
          config.client_secret = "test_secret"
          config.redirect_uri = "http://localhost:3000"
          config.environment = :production
        end

        config = described_class.configuration
        expect(config.client_id).to(eq("test_id"))
        expect(config.client_secret).to(eq("test_secret"))
        expect(config.redirect_uri).to(eq("http://localhost:3000"))
        expect(config.environment).to(eq(:production))
      end
    end

    it "returns the same configuration instance on multiple calls" do
      config1 = described_class.configure
      config2 = described_class.configure
      expect(config1).to(be(config2))
    end
  end

  describe ".reset_configuration!" do
    before do
      described_class.configure do |config|
        config.client_id = "test_id"
        config.environment = :production
      end
    end

    it "creates a new configuration instance" do
      old_config = described_class.configuration
      described_class.reset_configuration!
      new_config = described_class.configuration

      expect(new_config).not_to(be(old_config))
      expect(new_config.client_id).to(be_nil)
      expect(new_config.environment).to(eq(:sandbox))
    end
  end
end
