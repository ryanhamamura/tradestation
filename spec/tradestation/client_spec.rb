# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe Tradestation::Client do
  let(:configuration) do
    Tradestation::Configuration.new.tap do |config|
      config.client_id = "test_client_id"
      config.client_secret = "test_client_secret"
      config.redirect_uri = "http://localhost:3000/callback"
      config.environment = :sandbox
    end
  end

  let(:client) { described_class.new(configuration) }

  describe "#initialize" do
    context "with Configuration object" do
      it "uses the provided configuration" do
        expect(client.configuration).to eq(configuration)
      end
    end

    context "with Hash" do
      let(:client) do
        described_class.new(
          client_id: "hash_client_id",
          client_secret: "hash_secret",
          redirect_uri: "http://example.com/callback"
        )
      end

      it "builds configuration from hash" do
        expect(client.configuration.client_id).to eq("hash_client_id")
        expect(client.configuration.client_secret).to eq("hash_secret")
        expect(client.configuration.redirect_uri).to eq("http://example.com/callback")
      end
    end

    context "with nil and global configuration" do
      before do
        Tradestation.configure do |config|
          config.client_id = "global_client_id"
          config.client_secret = "global_secret"
          config.redirect_uri = "http://global.com/callback"
        end
      end

      after { Tradestation.reset_configuration! }

      let(:client) { described_class.new }

      it "uses global configuration" do
        expect(client.configuration.client_id).to eq("global_client_id")
      end
    end

    context "with invalid configuration" do
      it "raises ConfigurationError when required fields are missing" do
        invalid_config = Tradestation::Configuration.new
        expect { described_class.new(invalid_config) }.to raise_error(
          Tradestation::ConfigurationError,
          "client_id is required"
        )
      end
    end

    context "with invalid argument type" do
      it "raises ArgumentError" do
        expect { described_class.new("invalid") }.to raise_error(
          ArgumentError,
          "Configuration must be a Configuration object or Hash"
        )
      end
    end
  end

  describe "#authorization_url" do
    context "with default parameters" do
      let(:result) { client.authorization_url }

      it "returns a hash with url, state, and code_verifier" do
        expect(result).to be_a(Hash)
        expect(result).to have_key(:url)
        expect(result).to have_key(:state)
        expect(result).to have_key(:code_verifier)
      end

      it "generates a valid authorization URL" do
        url = result[:url]
        uri = URI.parse(url)
        params = CGI.parse(uri.query)

        expect(uri.host).to eq("signin.tradestation.com")
        expect(uri.path).to eq("/oauth/authorize")
        expect(params["response_type"]).to eq(["code"])
        expect(params["client_id"]).to eq(["test_client_id"])
        expect(params["redirect_uri"]).to eq(["http://localhost:3000/callback"])
        expect(params["state"]).to eq([result[:state]])
        expect(params["code_challenge"]).not_to be_empty
        expect(params["code_challenge_method"]).to eq(["S256"])
      end

      it "generates different state values on each call" do
        result1 = client.authorization_url
        result2 = client.authorization_url
        expect(result1[:state]).not_to eq(result2[:state])
      end

      it "generates different code_verifier values on each call" do
        result1 = client.authorization_url
        result2 = client.authorization_url
        expect(result1[:code_verifier]).not_to eq(result2[:code_verifier])
      end
    end

    context "with custom parameters" do
      let(:custom_state) { "custom_state_123" }
      let(:custom_scopes) { %w[Trade MarketData] }

      let(:result) do
        client.authorization_url(
          state: custom_state,
          scopes: custom_scopes
        )
      end

      it "uses provided state" do
        expect(result[:state]).to eq(custom_state)
      end

      it "includes custom scopes in URL" do
        uri = URI.parse(result[:url])
        params = CGI.parse(uri.query)
        expect(params["scope"]).to eq(["Trade MarketData"])
      end
    end

    context "without PKCE" do
      let(:result) { client.authorization_url(code_challenge_method: nil) }

      it "does not include code_verifier in result" do
        expect(result).not_to have_key(:code_verifier)
      end

      it "does not include PKCE parameters in URL" do
        uri = URI.parse(result[:url])
        params = CGI.parse(uri.query)
        expect(params).not_to have_key("code_challenge")
        expect(params).not_to have_key("code_challenge_method")
      end
    end

    context "with plain code challenge method" do
      let(:result) { client.authorization_url(code_challenge_method: "plain") }

      it "uses plain method" do
        uri = URI.parse(result[:url])
        params = CGI.parse(uri.query)
        expect(params["code_challenge_method"]).to eq(["plain"])
        expect(params["code_challenge"]).to eq([result[:code_verifier]])
      end
    end
  end

  describe "#exchange_code_for_token" do
    let(:auth_code) { "test_auth_code" }
    let(:code_verifier) { "test_verifier" }

    let(:token_response) do
      {
        "access_token" => "test_access_token",
        "refresh_token" => "test_refresh_token",
        "expires_in" => 1200,
        "token_type" => "Bearer",
        "scope" => "openid profile",
        "id_token" => "test.id.token"
      }
    end

    before do
      stub_request(:post, "https://signin.tradestation.com/oauth/token")
        .with(
          body: hash_including(
            "grant_type" => "authorization_code",
            "code" => auth_code,
            "redirect_uri" => "http://localhost:3000/callback",
            "client_id" => "test_client_id",
            "client_secret" => "test_client_secret"
          )
        )
        .to_return(
          status: 200,
          body: token_response.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns a TokenResponse object" do
      result = client.exchange_code_for_token(code: auth_code)
      expect(result).to be_a(Tradestation::TokenResponse)
      expect(result.access_token).to eq("test_access_token")
      expect(result.refresh_token).to eq("test_refresh_token")
      expect(result.expires_in).to eq(1200)
    end

    context "with code_verifier (PKCE)" do
      before do
        stub_request(:post, "https://signin.tradestation.com/oauth/token")
          .with(
            body: hash_including(
              "code_verifier" => code_verifier
            )
          )
          .to_return(
            status: 200,
            body: token_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "includes code_verifier in request" do
        client.exchange_code_for_token(code: auth_code, code_verifier: code_verifier)
        expect(WebMock).to have_requested(:post, "https://signin.tradestation.com/oauth/token")
          .with(body: hash_including("code_verifier" => code_verifier))
      end
    end

    context "with invalid code" do
      before do
        stub_request(:post, "https://signin.tradestation.com/oauth/token")
          .to_return(
            status: 401,
            body: { error: "invalid_grant", error_description: "Invalid authorization code" }.to_json
          )
      end

      it "raises AuthenticationError" do
        expect { client.exchange_code_for_token(code: "invalid") }.to raise_error(
          Tradestation::AuthenticationError,
          "Authentication failed"
        )
      end
    end

    context "with nil code" do
      it "raises ArgumentError" do
        expect { client.exchange_code_for_token(code: nil) }.to raise_error(
          ArgumentError,
          "Authorization code is required"
        )
      end
    end

    context "with empty code" do
      it "raises ArgumentError" do
        expect { client.exchange_code_for_token(code: "") }.to raise_error(
          ArgumentError,
          "Authorization code is required"
        )
      end
    end
  end

  describe "#refresh_token" do
    let(:refresh_token_value) { "test_refresh_token" }

    let(:new_token_response) do
      {
        "access_token" => "new_access_token",
        "refresh_token" => "new_refresh_token",
        "expires_in" => 1200,
        "token_type" => "Bearer"
      }
    end

    before do
      stub_request(:post, "https://signin.tradestation.com/oauth/token")
        .with(
          body: hash_including(
            "grant_type" => "refresh_token",
            "refresh_token" => refresh_token_value
          )
        )
        .to_return(
          status: 200,
          body: new_token_response.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns a new TokenResponse" do
      result = client.refresh_token(refresh_token: refresh_token_value)
      expect(result).to be_a(Tradestation::TokenResponse)
      expect(result.access_token).to eq("new_access_token")
      expect(result.refresh_token).to eq("new_refresh_token")
    end

    context "with expired refresh token" do
      before do
        stub_request(:post, "https://signin.tradestation.com/oauth/token")
          .to_return(
            status: 400,
            body: { error: "invalid_grant", error_description: "Refresh token expired" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises TokenExpiredError" do
        expect { client.refresh_token(refresh_token: "expired") }.to raise_error(
          Tradestation::TokenExpiredError
        )
      end
    end

    context "with nil refresh token" do
      it "raises ArgumentError" do
        expect { client.refresh_token(refresh_token: nil) }.to raise_error(
          ArgumentError,
          "Refresh token is required"
        )
      end
    end
  end
end
