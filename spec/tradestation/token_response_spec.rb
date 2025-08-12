# frozen_string_literal: true

require "spec_helper"
require "oauth2"
require "jwt"

RSpec.describe Tradestation::TokenResponse do
  let(:access_token_value) { "test_access_token" }
  let(:refresh_token_value) { "test_refresh_token" }
  let(:expires_in) { 1200 }
  let(:token_type) { "Bearer" }
  let(:scope) { "openid profile" }

  # Create a test ID token
  let(:id_token_payload) do
    {
      sub: "user123",
      name: "John Doe",
      email: "john@example.com",
      iat: Time.now.to_i,
      exp: Time.now.to_i + 3600
    }
  end

  let(:id_token) { JWT.encode(id_token_payload, nil, "none") }

  describe "#initialize" do
    context "with OAuth2::AccessToken" do
      let(:oauth2_client) { instance_double(OAuth2::Client) }
      let(:oauth2_token) do
        OAuth2::AccessToken.new(
          oauth2_client,
          access_token_value,
          refresh_token: refresh_token_value,
          expires_in: expires_in,
          expires_at: Time.now.to_i + expires_in,
          token_type: token_type,
          scope: scope,
          id_token: id_token
        )
      end

      let(:token_response) { described_class.new(oauth2_token) }

      it "extracts token values correctly" do
        expect(token_response.access_token).to eq(access_token_value)
        expect(token_response.refresh_token).to eq(refresh_token_value)
        expect(token_response.expires_in).to eq(expires_in)
        expect(token_response.token_type).to eq(token_type)
        expect(token_response.id_token).to eq(id_token)
      end

      it "parses scope as array" do
        expect(token_response.scope).to eq(%w[openid profile])
      end

      it "stores raw response" do
        expect(token_response.raw_response).to eq(oauth2_token)
      end
    end

    context "with Hash" do
      let(:token_hash) do
        {
          "access_token" => access_token_value,
          "refresh_token" => refresh_token_value,
          "expires_in" => expires_in,
          "token_type" => token_type,
          "scope" => scope,
          "id_token" => id_token
        }
      end

      let(:token_response) { described_class.new(token_hash) }

      it "extracts token values from hash" do
        expect(token_response.access_token).to eq(access_token_value)
        expect(token_response.refresh_token).to eq(refresh_token_value)
        expect(token_response.expires_in).to eq(expires_in)
        expect(token_response.token_type).to eq(token_type)
        expect(token_response.id_token).to eq(id_token)
      end

      it "handles symbol keys" do
        symbol_hash = {
          access_token: access_token_value,
          refresh_token: refresh_token_value,
          expires_in: expires_in
        }

        response = described_class.new(symbol_hash)
        expect(response.access_token).to eq(access_token_value)
        expect(response.refresh_token).to eq(refresh_token_value)
      end

      it "calculates expires_at from expires_in" do
        freeze_time = Time.now
        allow(Time).to receive(:now).and_return(freeze_time)

        response = described_class.new(token_hash)
        expected_expires_at = freeze_time + expires_in

        expect(response.expires_at).to be_within(1).of(expected_expires_at)
      end

      it "defaults token_type to Bearer if not provided" do
        hash_without_type = token_hash.dup
        hash_without_type.delete("token_type")

        response = described_class.new(hash_without_type)
        expect(response.token_type).to eq("Bearer")
      end
    end

    context "with invalid input" do
      it "raises ArgumentError for unsupported types" do
        expect { described_class.new("invalid") }.to raise_error(
          ArgumentError,
          "TokenResponse requires OAuth2::AccessToken or Hash"
        )
      end
    end
  end

  describe "#expired?" do
    let(:token_hash) { { "access_token" => access_token_value } }

    context "when expires_at is in the past" do
      it "returns true" do
        token_hash["expires_in"] = -100
        response = described_class.new(token_hash)
        expect(response.expired?).to be true
      end
    end

    context "when expires_at is in the future" do
      it "returns false" do
        token_hash["expires_in"] = 3600
        response = described_class.new(token_hash)
        expect(response.expired?).to be false
      end
    end

    context "when expires_at is nil" do
      it "returns false" do
        response = described_class.new(token_hash)
        expect(response.expired?).to be false
      end
    end
  end

  describe "#expires_soon?" do
    let(:token_hash) { { "access_token" => access_token_value } }

    context "with default buffer (5 minutes)" do
      it "returns true when expiring within 5 minutes" do
        token_hash["expires_in"] = 120  # 2 minutes
        response = described_class.new(token_hash)
        expect(response.expires_soon?).to be true
      end

      it "returns false when expiring after 5 minutes" do
        token_hash["expires_in"] = 600  # 10 minutes
        response = described_class.new(token_hash)
        expect(response.expires_soon?).to be false
      end
    end

    context "with custom buffer" do
      it "uses the provided buffer seconds" do
        token_hash["expires_in"] = 3600 # 1 hour
        response = described_class.new(token_hash)

        expect(response.expires_soon?(3700)).to be true
        expect(response.expires_soon?(3500)).to be false
      end
    end

    context "when already expired" do
      it "returns true" do
        token_hash["expires_in"] = -100
        response = described_class.new(token_hash)
        expect(response.expires_soon?).to be true
      end
    end

    context "when expires_at is nil" do
      it "returns false" do
        response = described_class.new(token_hash)
        expect(response.expires_soon?).to be false
      end
    end
  end

  describe "#time_until_expiry" do
    let(:token_hash) { { "access_token" => access_token_value } }

    context "when token has not expired" do
      it "returns seconds until expiry" do
        token_hash["expires_in"] = 3600
        response = described_class.new(token_hash)

        expect(response.time_until_expiry).to be_within(2).of(3600)
      end
    end

    context "when token has expired" do
      it "returns 0" do
        token_hash["expires_in"] = -100
        response = described_class.new(token_hash)

        expect(response.time_until_expiry).to eq(0)
      end
    end

    context "when expires_at is nil" do
      it "returns nil" do
        response = described_class.new(token_hash)
        expect(response.time_until_expiry).to be_nil
      end
    end
  end

  describe "#decoded_id_token" do
    let(:token_hash) do
      {
        "access_token" => access_token_value,
        "id_token" => id_token
      }
    end

    let(:token_response) { described_class.new(token_hash) }

    it "decodes the JWT token" do
      decoded = token_response.decoded_id_token

      expect(decoded).to be_a(Hash)
      expect(decoded["sub"]).to eq("user123")
      expect(decoded["name"]).to eq("John Doe")
      expect(decoded["email"]).to eq("john@example.com")
    end

    it "caches the decoded token" do
      decoded1 = token_response.decoded_id_token
      decoded2 = token_response.decoded_id_token

      expect(decoded1).to be(decoded2) # Same object
    end

    context "when id_token is nil" do
      it "returns nil" do
        token_hash.delete("id_token")
        response = described_class.new(token_hash)

        expect(response.decoded_id_token).to be_nil
      end
    end

    context "when id_token is invalid" do
      it "raises AuthenticationError" do
        token_hash["id_token"] = "invalid.jwt.token"
        response = described_class.new(token_hash)

        expect { response.decoded_id_token }.to raise_error(
          Tradestation::AuthenticationError,
          /Failed to decode ID token/
        )
      end
    end
  end

  describe "#user_id" do
    let(:token_hash) do
      {
        "access_token" => access_token_value,
        "id_token" => id_token
      }
    end

    let(:token_response) { described_class.new(token_hash) }

    it "returns the sub claim from id_token" do
      expect(token_response.user_id).to eq("user123")
    end

    context "when id_token is nil" do
      it "returns nil" do
        token_hash.delete("id_token")
        response = described_class.new(token_hash)

        expect(response.user_id).to be_nil
      end
    end
  end

  describe "#to_h" do
    let(:token_hash) do
      {
        "access_token" => access_token_value,
        "refresh_token" => refresh_token_value,
        "expires_in" => expires_in,
        "token_type" => token_type,
        "scope" => scope,
        "id_token" => id_token
      }
    end

    let(:token_response) { described_class.new(token_hash) }

    it "returns a hash representation" do
      hash = token_response.to_h

      expect(hash).to be_a(Hash)
      expect(hash[:access_token]).to eq(access_token_value)
      expect(hash[:refresh_token]).to eq(refresh_token_value)
      expect(hash[:expires_in]).to eq(expires_in)
      expect(hash[:token_type]).to eq(token_type)
      expect(hash[:scope]).to eq(%w[openid profile])
      expect(hash[:id_token]).to eq(id_token)
    end

    it "includes expires_at as ISO8601 string" do
      hash = token_response.to_h
      expect(hash[:expires_at]).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "excludes nil values" do
      minimal_hash = { "access_token" => access_token_value }
      response = described_class.new(minimal_hash)

      hash = response.to_h
      expect(hash).not_to have_key(:refresh_token)
      expect(hash).not_to have_key(:expires_at)
      expect(hash).not_to have_key(:id_token)
    end
  end

  describe "#bearer_token" do
    let(:token_hash) do
      {
        "access_token" => access_token_value,
        "token_type" => token_type
      }
    end

    let(:token_response) { described_class.new(token_hash) }

    it "returns formatted bearer token string" do
      expect(token_response.bearer_token).to eq("Bearer #{access_token_value}")
    end

    context "with custom token type" do
      it "uses the provided token type" do
        token_hash["token_type"] = "MAC"
        response = described_class.new(token_hash)

        expect(response.bearer_token).to eq("MAC #{access_token_value}")
      end
    end
  end

  describe "scope handling" do
    it "handles array scope" do
      token_hash = {
        "access_token" => access_token_value,
        "scope" => %w[openid profile Trade]
      }

      response = described_class.new(token_hash)
      expect(response.scope).to eq(%w[openid profile Trade])
    end

    it "handles string scope with spaces" do
      token_hash = {
        "access_token" => access_token_value,
        "scope" => "openid profile Trade"
      }

      response = described_class.new(token_hash)
      expect(response.scope).to eq(%w[openid profile Trade])
    end

    it "handles nil scope" do
      token_hash = { "access_token" => access_token_value }

      response = described_class.new(token_hash)
      expect(response.scope).to eq([])
    end
  end
end
