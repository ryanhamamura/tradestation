# frozen_string_literal: true

require "spec_helper"
require "webmock/rspec"

RSpec.describe(Tradestation::Client) do
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
        expect(client.configuration).to(eq(configuration))
      end
    end

    context "with Hash" do
      let(:client) do
        described_class.new(
          client_id: "hash_client_id",
          client_secret: "hash_secret",
          redirect_uri: "http://example.com/callback",
        )
      end

      it "builds configuration from hash" do
        expect(client.configuration.client_id).to(eq("hash_client_id"))
        expect(client.configuration.client_secret).to(eq("hash_secret"))
        expect(client.configuration.redirect_uri).to(eq("http://example.com/callback"))
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
        expect(client.configuration.client_id).to(eq("global_client_id"))
      end
    end

    context "with invalid configuration" do
      it "raises ConfigurationError when required fields are missing" do
        invalid_config = Tradestation::Configuration.new
        expect { described_class.new(invalid_config) }.to(raise_error(
          Tradestation::ConfigurationError,
          "client_id is required",
        ))
      end
    end

    context "with invalid argument type" do
      it "raises ArgumentError" do
        expect { described_class.new("invalid") }.to(raise_error(
          ArgumentError,
          "Configuration must be a Configuration object or Hash",
        ))
      end
    end
  end

  describe "#authorization_url" do
    context "with default parameters" do
      let(:result) { client.authorization_url }

      it "returns a hash with url, state, and code_verifier" do
        expect(result).to(be_a(Hash))
        expect(result).to(have_key(:url))
        expect(result).to(have_key(:state))
        expect(result).to(have_key(:code_verifier))
      end

      it "generates a valid authorization URL" do
        url = result[:url]
        uri = URI.parse(url)
        params = CGI.parse(uri.query)

        expect(uri.host).to(eq("signin.tradestation.com"))
        expect(uri.path).to(eq("/oauth/authorize"))
        expect(params["response_type"]).to(eq(["code"]))
        expect(params["client_id"]).to(eq(["test_client_id"]))
        expect(params["redirect_uri"]).to(eq(["http://localhost:3000/callback"]))
        expect(params["state"]).to(eq([result[:state]]))
        expect(params["code_challenge"]).not_to(be_empty)
        expect(params["code_challenge_method"]).to(eq(["S256"]))
      end

      it "generates different state values on each call" do
        result1 = client.authorization_url
        result2 = client.authorization_url
        expect(result1[:state]).not_to(eq(result2[:state]))
      end

      it "generates different code_verifier values on each call" do
        result1 = client.authorization_url
        result2 = client.authorization_url
        expect(result1[:code_verifier]).not_to(eq(result2[:code_verifier]))
      end
    end

    context "with custom parameters" do
      let(:custom_state) { "custom_state_123" }
      let(:custom_scopes) { ["Trade", "MarketData"] }

      let(:result) do
        client.authorization_url(
          state: custom_state,
          scopes: custom_scopes,
        )
      end

      it "uses provided state" do
        expect(result[:state]).to(eq(custom_state))
      end

      it "includes custom scopes in URL" do
        uri = URI.parse(result[:url])
        params = CGI.parse(uri.query)
        expect(params["scope"]).to(eq(["Trade MarketData"]))
      end
    end

    context "without PKCE" do
      let(:result) { client.authorization_url(code_challenge_method: nil) }

      it "does not include code_verifier in result" do
        expect(result).not_to(have_key(:code_verifier))
      end

      it "does not include PKCE parameters in URL" do
        uri = URI.parse(result[:url])
        params = CGI.parse(uri.query)
        expect(params).not_to(have_key("code_challenge"))
        expect(params).not_to(have_key("code_challenge_method"))
      end
    end

    context "with plain code challenge method" do
      let(:result) { client.authorization_url(code_challenge_method: "plain") }

      it "uses plain method" do
        uri = URI.parse(result[:url])
        params = CGI.parse(uri.query)
        expect(params["code_challenge_method"]).to(eq(["plain"]))
        expect(params["code_challenge"]).to(eq([result[:code_verifier]]))
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
        "id_token" => "test.id.token",
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
            "client_secret" => "test_client_secret",
          ),
        )
        .to_return(
          status: 200,
          body: token_response.to_json,
          headers: { "Content-Type" => "application/json" },
        )
    end

    it "returns a TokenResponse object" do
      result = client.exchange_code_for_token(code: auth_code)
      expect(result).to(be_a(Tradestation::TokenResponse))
      expect(result.access_token).to(eq("test_access_token"))
      expect(result.refresh_token).to(eq("test_refresh_token"))
      expect(result.expires_in).to(eq(1200))
    end

    context "with code_verifier (PKCE)" do
      before do
        stub_request(:post, "https://signin.tradestation.com/oauth/token")
          .with(
            body: hash_including(
              "code_verifier" => code_verifier,
            ),
          )
          .to_return(
            status: 200,
            body: token_response.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "includes code_verifier in request" do
        client.exchange_code_for_token(code: auth_code, code_verifier: code_verifier)
        expect(WebMock).to(have_requested(:post, "https://signin.tradestation.com/oauth/token")
          .with(body: hash_including("code_verifier" => code_verifier)))
      end
    end

    context "with invalid code" do
      before do
        stub_request(:post, "https://signin.tradestation.com/oauth/token")
          .to_return(
            status: 401,
            body: { error: "invalid_grant", error_description: "Invalid authorization code" }.to_json,
          )
      end

      it "raises AuthenticationError" do
        expect { client.exchange_code_for_token(code: "invalid") }.to(raise_error(
          Tradestation::AuthenticationError,
          "Authentication failed",
        ))
      end
    end

    context "with nil code" do
      it "raises ArgumentError" do
        expect { client.exchange_code_for_token(code: nil) }.to(raise_error(
          ArgumentError,
          "Authorization code is required",
        ))
      end
    end

    context "with empty code" do
      it "raises ArgumentError" do
        expect { client.exchange_code_for_token(code: "") }.to(raise_error(
          ArgumentError,
          "Authorization code is required",
        ))
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
        "token_type" => "Bearer",
      }
    end

    before do
      stub_request(:post, "https://signin.tradestation.com/oauth/token")
        .with(
          body: hash_including(
            "grant_type" => "refresh_token",
            "refresh_token" => refresh_token_value,
          ),
        )
        .to_return(
          status: 200,
          body: new_token_response.to_json,
          headers: { "Content-Type" => "application/json" },
        )
    end

    it "returns a new TokenResponse" do
      result = client.refresh_token(refresh_token: refresh_token_value)
      expect(result).to(be_a(Tradestation::TokenResponse))
      expect(result.access_token).to(eq("new_access_token"))
      expect(result.refresh_token).to(eq("new_refresh_token"))
    end

    context "with expired refresh token" do
      before do
        stub_request(:post, "https://signin.tradestation.com/oauth/token")
          .to_return(
            status: 400,
            body: { error: "invalid_grant", error_description: "Refresh token expired" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "raises TokenExpiredError" do
        expect { client.refresh_token(refresh_token: "expired") }.to(raise_error(
          Tradestation::TokenExpiredError,
        ))
      end
    end

    context "with nil refresh token" do
      it "raises ArgumentError" do
        expect { client.refresh_token(refresh_token: nil) }.to(raise_error(
          ArgumentError,
          "Refresh token is required",
        ))
      end
    end
  end

  describe "#token_expired?" do
    context "with Time object" do
      it "returns true when token is expired" do
        past_time = Time.now - 3600
        expect(client.token_expired?(past_time)).to(be(true))
      end

      it "returns false when token is not expired" do
        future_time = Time.now + 3600
        expect(client.token_expired?(future_time)).to(be(false))
      end
    end

    context "with Unix timestamp" do
      it "returns true when token is expired" do
        past_timestamp = (Time.now - 3600).to_i
        expect(client.token_expired?(past_timestamp)).to(be(true))
      end

      it "returns false when token is not expired" do
        future_timestamp = (Time.now + 3600).to_i
        expect(client.token_expired?(future_timestamp)).to(be(false))
      end
    end

    context "with String timestamp" do
      it "returns true when token is expired" do
        past_time_string = (Time.now - 3600).iso8601
        expect(client.token_expired?(past_time_string)).to(be(true))
      end

      it "returns false when token is not expired" do
        future_time_string = (Time.now + 3600).iso8601
        expect(client.token_expired?(future_time_string)).to(be(false))
      end
    end

    context "with nil" do
      it "returns false" do
        expect(client.token_expired?(nil)).to(be(false))
      end
    end

    context "with invalid type" do
      it "raises ArgumentError" do
        expect { client.token_expired?([]) }.to(raise_error(
          ArgumentError,
          "expires_at must be a Time, Integer (Unix timestamp), or String",
        ))
      end
    end
  end

  describe "#token_expires_soon?" do
    context "with default buffer (5 minutes)" do
      it "returns true when token expires within buffer" do
        expires_in_2_minutes = Time.now + 120
        expect(client.token_expires_soon?(expires_in_2_minutes)).to(be(true))
      end

      it "returns false when token expires after buffer" do
        expires_in_10_minutes = Time.now + 600
        expect(client.token_expires_soon?(expires_in_10_minutes)).to(be(false))
      end

      it "returns true when token is already expired" do
        past_time = Time.now - 3600
        expect(client.token_expires_soon?(past_time)).to(be(true))
      end
    end

    context "with custom buffer" do
      it "uses the provided buffer seconds" do
        expires_in_1_hour = Time.now + 3600
        expect(client.token_expires_soon?(expires_in_1_hour, 3700)).to(be(true))
        expect(client.token_expires_soon?(expires_in_1_hour, 3500)).to(be(false))
      end
    end

    context "with nil" do
      it "returns false" do
        expect(client.token_expires_soon?(nil)).to(be(false))
      end
    end

    context "with Integer timestamp" do
      it "returns true when token expires within buffer" do
        expires_in_2_minutes = (Time.now + 120).to_i
        expect(client.token_expires_soon?(expires_in_2_minutes)).to(be(true))
      end

      it "returns false when token expires after buffer" do
        expires_in_10_minutes = (Time.now + 600).to_i
        expect(client.token_expires_soon?(expires_in_10_minutes)).to(be(false))
      end
    end

    context "with Float timestamp" do
      it "returns true when token expires within buffer" do
        expires_in_2_minutes = (Time.now + 120).to_f
        expect(client.token_expires_soon?(expires_in_2_minutes)).to(be(true))
      end

      it "returns false when token expires after buffer" do
        expires_in_10_minutes = (Time.now + 600).to_f
        expect(client.token_expires_soon?(expires_in_10_minutes)).to(be(false))
      end
    end

    context "with String timestamp" do
      it "handles ISO8601 string" do
        expires_in_2_minutes = (Time.now + 120).iso8601
        expect(client.token_expires_soon?(expires_in_2_minutes)).to(be(true))
      end

      it "handles RFC2822 string" do
        expires_in_10_minutes = (Time.now + 600).rfc2822
        expect(client.token_expires_soon?(expires_in_10_minutes)).to(be(false))
      end
    end

    context "with invalid type" do
      it "raises ArgumentError" do
        expect { client.token_expires_soon?([]) }.to(raise_error(
          ArgumentError,
          "expires_at must be a Time, Integer (Unix timestamp), or String",
        ))
      end

      it "raises ArgumentError for hash" do
        expect { client.token_expires_soon?({ time: Time.now }) }.to(raise_error(
          ArgumentError,
          "expires_at must be a Time, Integer (Unix timestamp), or String",
        ))
      end
    end
  end

  describe "#authenticated_request" do
    let(:access_token) { "test_access_token" }
    let(:api_base_url) { "https://sim-api.tradestation.com/v3" }

    context "with GET requests" do
      before do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .with(
            headers: {
              "Authorization" => "Bearer #{access_token}",
              "Accept" => "application/json",
              "Content-Type" => "application/json",
            },
          )
          .to_return(
            status: 200,
            body: { data: "test_response" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "makes authenticated GET request with proper headers" do
        response = client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
        )

        expect(response).to(eq("data" => "test_response"))
      end

      it "includes custom headers" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

        client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
          headers: { "X-Custom-Header" => "custom_value" },
        )

        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint")
          .with { |request| request.headers["X-Custom-Header"] == "custom_value" })
      end

      it "includes query parameters" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .with(query: { foo: "bar", baz: "qux" })
          .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

        client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
          params: { foo: "bar", baz: "qux" },
        )

        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint")
          .with(query: { foo: "bar", baz: "qux" }))
      end
    end

    context "with POST requests" do
      let(:request_body) { { order: { symbol: "AAPL", quantity: 100 } } }

      context "for non-idempotent endpoints (order placement)" do
        before do
          stub_request(:post, "#{api_base_url}/orderexecution/orders")
            .with(body: request_body.to_json)
            .to_return(
              status: 201,
              body: { order_id: "12345" }.to_json,
              headers: { "Content-Type" => "application/json" },
            )
        end

        it "sends JSON body with proper content-type" do
          response = client.authenticated_request(
            method: :post,
            path: "/orderexecution/orders",
            access_token: access_token,
            body: request_body,
          )

          expect(response).to(eq("order_id" => "12345"))
          expect(WebMock).to(have_requested(:post, "#{api_base_url}/orderexecution/orders")
            .with(body: request_body.to_json))
        end

        xit "does NOT retry on server errors (non-idempotent)" do
          stub_request(:post, "#{api_base_url}/orderexecution/orders")
            .to_return(status: 503, body: { error: "Service unavailable" }.to_json, headers: { "Content-Type" => "application/json" })
            .times(1)

          expect do
            client.authenticated_request(
              method: :post,
              path: "/orderexecution/orders",
              access_token: access_token,
              body: request_body,
            )
          end.to(raise_error(Tradestation::ApiError))

          # Should only be called once, no retries
          expect(WebMock).to(have_requested(:post, "#{api_base_url}/orderexecution/orders").once)
        end
      end

      context "for safe endpoints (order confirmation)" do
        before do
          stub_request(:post, "#{api_base_url}/orderexecution/orderconfirm")
            .with(body: request_body.to_json)
            .to_return(
              status: 200,
              body: { confirmed: true, estimated_cost: 10_000 }.to_json,
              headers: { "Content-Type" => "application/json" },
            )
        end

        xit "retries on server errors (safe endpoint)" do
          stub_request(:post, "#{api_base_url}/orderexecution/orderconfirm")
            .to_return(
              {
                status: 503,
                body: { error: "Service unavailable" }.to_json,
                headers: { "Content-Type" => "application/json" },
              },
              {
                status: 503,
                body: { error: "Service unavailable" }.to_json,
                headers: { "Content-Type" => "application/json" },
              },
              { status: 200, body: { confirmed: true }.to_json, headers: { "Content-Type" => "application/json" } },
            )

          response = client.authenticated_request(
            method: :post,
            path: "/orderexecution/orderconfirm",
            access_token: access_token,
            body: request_body,
          )

          expect(response).to(eq("confirmed" => true))
          # Should retry twice and succeed on third attempt
          expect(WebMock).to(have_requested(:post, "#{api_base_url}/orderexecution/orderconfirm").times(3))
        end
      end
    end

    context "with PUT requests" do
      let(:update_body) { { quantity: 200 } }

      before do
        stub_request(:put, "#{api_base_url}/orderexecution/orders/123")
          .with(body: update_body.to_json)
          .to_return(
            status: 200,
            body: { order_id: "123", status: "REPLACED" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "sends PUT request with body" do
        response = client.authenticated_request(
          method: :put,
          path: "/orderexecution/orders/123",
          access_token: access_token,
          body: update_body,
        )

        expect(response).to(eq("order_id" => "123", "status" => "REPLACED"))
      end

      xit "retries PUT requests (idempotent)" do
        stub_request(:put, "#{api_base_url}/test/resource")
          .to_return(
            {
              status: 503,
              body: { error: "Service unavailable" }.to_json,
              headers: { "Content-Type" => "application/json" },
            },
            { status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" } },
          )

        response = client.authenticated_request(
          method: :put,
          path: "/test/resource",
          access_token: access_token,
          body: { data: "test" },
        )

        expect(response).to(eq("success" => true))
        expect(WebMock).to(have_requested(:put, "#{api_base_url}/test/resource").times(2))
      end
    end

    context "with PATCH requests" do
      xit "does NOT retry PATCH requests (non-idempotent)" do
        stub_request(:patch, "#{api_base_url}/test/resource")
          .to_return(status: 503, body: { error: "Service unavailable" }.to_json, headers: { "Content-Type" => "application/json" })
          .times(1)

        expect do
          client.authenticated_request(
            method: :patch,
            path: "/test/resource",
            access_token: access_token,
            body: { data: "test" },
          )
        end.to(raise_error(Tradestation::ApiError))

        expect(WebMock).to(have_requested(:patch, "#{api_base_url}/test/resource").once)
      end
    end

    context "with DELETE requests" do
      before do
        stub_request(:delete, "#{api_base_url}/orderexecution/orders/123")
          .to_return(
            status: 200,
            body: { order_id: "123", status: "CANCELLED" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "sends DELETE request" do
        response = client.authenticated_request(
          method: :delete,
          path: "/orderexecution/orders/123",
          access_token: access_token,
        )

        expect(response).to(eq("order_id" => "123", "status" => "CANCELLED"))
      end

      xit "retries DELETE requests (idempotent)" do
        stub_request(:delete, "#{api_base_url}/test/resource")
          .to_return(
            {
              status: 504,
              body: { error: "Gateway timeout" }.to_json,
              headers: { "Content-Type" => "application/json" },
            },
            { status: 204, body: nil },
          )

        client.authenticated_request(
          method: :delete,
          path: "/test/resource",
          access_token: access_token,
        )

        expect(WebMock).to(have_requested(:delete, "#{api_base_url}/test/resource").times(2))
      end
    end

    xcontext "retry logic" do
      it "retries on 429 rate limit with exponential backoff" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            {
              status: 429,
              body: { error: "Rate limit exceeded" }.to_json,
              headers: { "Content-Type" => "application/json" },
            },
            {
              status: 429,
              body: { error: "Rate limit exceeded" }.to_json,
              headers: { "Content-Type" => "application/json" },
            },
            { status: 200, body: { data: "success" }.to_json, headers: { "Content-Type" => "application/json" } },
          )

        response = client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
        )

        expect(response).to(eq("data" => "success"))
        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").times(3))
      end

      it "retries on 503 service unavailable" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            {
              status: 503,
              body: { error: "Service unavailable" }.to_json,
              headers: { "Content-Type" => "application/json" },
            },
            { status: 200, body: { data: "success" }.to_json, headers: { "Content-Type" => "application/json" } },
          )

        response = client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
        )

        expect(response).to(eq("data" => "success"))
        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").times(2))
      end

      it "retries on 504 gateway timeout" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            {
              status: 504,
              body: { error: "Gateway timeout" }.to_json,
              headers: { "Content-Type" => "application/json" },
            },
            { status: 200, body: { data: "success" }.to_json, headers: { "Content-Type" => "application/json" } },
          )

        response = client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
        )

        expect(response).to(eq("data" => "success"))
        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").times(2))
      end

      it "retries on connection timeout" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_timeout.then
          .to_return(status: 200, body: { data: "success" }.to_json, headers: { "Content-Type" => "application/json" })

        response = client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
        )

        expect(response).to(eq("data" => "success"))
        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").times(2))
      end

      it "retries on connection failure" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_raise(Faraday::ConnectionFailed).then
          .to_return(status: 200, body: { data: "success" }.to_json, headers: { "Content-Type" => "application/json" })

        response = client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
        )

        expect(response).to(eq("data" => "success"))
        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").times(2))
      end

      it "fails after max retries exceeded" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(status: 503, body: { error: "Service unavailable" }.to_json, headers: { "Content-Type" => "application/json" })

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
            max_retries: 3,
          )
        end.to(raise_error(Tradestation::ApiError))

        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").times(4))
      end

      it "respects custom max_retries parameter" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(status: 503, body: { error: "Service unavailable" }.to_json, headers: { "Content-Type" => "application/json" })

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
            max_retries: 1,
          )
        end.to(raise_error(Tradestation::ApiError))

        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").times(2))
      end

      it "does not retry when max_retries is 0" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(status: 503, body: { error: "Service unavailable" }.to_json, headers: { "Content-Type" => "application/json" })
          .times(1)

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
            max_retries: 0,
          )
        end.to(raise_error(Tradestation::ApiError))

        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").once)
      end
    end

    context "error handling" do
      it "raises AuthenticationError on 401" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            status: 401,
            body: { error: "Unauthorized", message: "Invalid token" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
          )
        end.to(raise_error(Tradestation::AuthenticationError, /Authentication failed/))
      end

      it "raises AuthenticationError on 403" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            status: 403,
            body: { error: "Forbidden", message: "Insufficient permissions" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
          )
        end.to(raise_error(Tradestation::AuthenticationError, /Access forbidden/))
      end

      it "raises ApiError with specific message on 404" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            status: 404,
            body: { error: "Not found", message: "Resource does not exist" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
          )
        end.to(raise_error(Tradestation::ApiError)) do |error|
          expect(error.message).to(eq("Resource not found"))
          expect(error.status_code).to(eq(404))
        end
      end

      it "raises ApiError on 422 unprocessable entity" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            status: 422,
            body: { error: "Validation failed", errors: ["Field is required"] }.to_json,
            headers: { "Content-Type" => "application/json" },
          )

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
          )
        end.to(raise_error(Tradestation::ApiError)) do |error|
          expect(error.message).to(eq("Client error"))
          expect(error.status_code).to(eq(422))
        end
      end

      it "raises ApiError on 500 internal server error after retries" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            status: 500,
            body: { error: "Internal server error" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
          .times(4) # Will retry 3 times

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
          )
        end.to(raise_error(Tradestation::ApiError)) do |error|
          expect(error.message).to(eq("Server error"))
          expect(error.status_code).to(eq(500))
        end
      end

      it "handles non-JSON error responses gracefully" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(
            status: 500,
            body: "Internal Server Error",
            headers: { "Content-Type" => "text/plain" },
          )
          .times(4)

        expect do
          client.authenticated_request(
            method: :get,
            path: "/test/endpoint",
            access_token: access_token,
          )
        end.to(raise_error(Tradestation::ApiError))
      end
    end

    context "parameter validation" do
      it "raises ArgumentError when access_token is nil" do
        expect do
          client.authenticated_request(
            method: :get,
            path: "/test",
            access_token: nil,
          )
        end.to(raise_error(ArgumentError, "access_token is required"))
      end

      it "raises ArgumentError when access_token is empty" do
        expect do
          client.authenticated_request(
            method: :get,
            path: "/test",
            access_token: "",
          )
        end.to(raise_error(ArgumentError, "access_token is required"))
      end

      it "raises ArgumentError for unsupported HTTP method" do
        expect do
          client.authenticated_request(
            method: :options,
            path: "/test",
            access_token: access_token,
          )
        end.to(raise_error(ArgumentError, "Unsupported HTTP method: options"))
      end

      it "handles path with or without leading slash" do
        stub_request(:get, "#{api_base_url}/test/endpoint")
          .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

        # Without leading slash
        client.authenticated_request(
          method: :get,
          path: "test/endpoint",
          access_token: access_token,
        )

        # With leading slash
        client.authenticated_request(
          method: :get,
          path: "/test/endpoint",
          access_token: access_token,
        )

        expect(WebMock).to(have_requested(:get, "#{api_base_url}/test/endpoint").times(2))
      end
    end
  end

  describe "convenience methods" do
    let(:access_token) { "test_access_token" }
    let(:api_base_url) { "https://sim-api.tradestation.com/v3" }

    describe "#get_accounts" do
      before do
        stub_request(:get, "#{api_base_url}/brokerage/accounts")
          .to_return(
            status: 200,
            body: { Accounts: [{ AccountID: "123", AccountType: "Cash" }] }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "fetches accounts list" do
        response = client.get_accounts(access_token: access_token)
        expect(response).to(eq("Accounts" => [{ "AccountID" => "123", "AccountType" => "Cash" }]))
      end
    end

    describe "#get_account_balances" do
      context "with single account ID" do
        before do
          stub_request(:get, "#{api_base_url}/brokerage/accounts/123/balances")
            .to_return(
              status: 200,
              body: { CashBalance: "10000.00", Equity: "50000.00" }.to_json,
              headers: { "Content-Type" => "application/json" },
            )
        end

        it "fetches balances for single account" do
          response = client.get_account_balances(
            access_token: access_token,
            account_ids: "123",
          )
          expect(response).to(eq("CashBalance" => "10000.00", "Equity" => "50000.00"))
        end
      end

      context "with multiple account IDs" do
        before do
          stub_request(:get, "#{api_base_url}/brokerage/accounts/123,456,789/balances")
            .to_return(
              status: 200,
              body: { Balances: [] }.to_json,
              headers: { "Content-Type" => "application/json" },
            )
        end

        it "fetches balances for multiple accounts" do
          response = client.get_account_balances(
            access_token: access_token,
            account_ids: ["123", "456", "789"],
          )
          expect(response).to(eq("Balances" => []))
        end

        it "handles array of account IDs" do
          client.get_account_balances(
            access_token: access_token,
            account_ids: ["123", "456", "789"],
          )

          expect(WebMock).to(have_requested(:get, "#{api_base_url}/brokerage/accounts/123,456,789/balances"))
        end
      end
    end

    describe "#get_positions" do
      before do
        stub_request(:get, "#{api_base_url}/brokerage/accounts/123,456/positions")
          .to_return(
            status: 200,
            body: { Positions: [] }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "fetches positions for accounts" do
        response = client.get_positions(
          access_token: access_token,
          account_ids: ["123", "456"],
        )
        expect(response).to(eq("Positions" => []))
      end
    end

    describe "#get_orders" do
      before do
        stub_request(:get, "#{api_base_url}/brokerage/accounts/123/orders")
          .to_return(
            status: 200,
            body: { Orders: [] }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "fetches today's and open orders" do
        response = client.get_orders(
          access_token: access_token,
          account_ids: "123",
        )
        expect(response).to(eq("Orders" => []))
      end
    end

    describe "#get_historical_orders" do
      before do
        stub_request(:get, "#{api_base_url}/brokerage/accounts/123/historicalorders")
          .with(query: { since: "2024-01-01" })
          .to_return(
            status: 200,
            body: { Orders: [] }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "fetches historical orders with since parameter" do
        response = client.get_historical_orders(
          access_token: access_token,
          account_ids: "123",
          since: "2024-01-01",
        )
        expect(response).to(eq("Orders" => []))
      end

      it "requires since parameter" do
        client.get_historical_orders(
          access_token: access_token,
          account_ids: "123",
          since: "2024-01-01",
        )

        expect(WebMock).to(have_requested(:get, "#{api_base_url}/brokerage/accounts/123/historicalorders")
          .with(query: { since: "2024-01-01" }))
      end
    end

    describe "#confirm_order" do
      let(:order) { { Symbol: "AAPL", Quantity: 100, OrderType: "Market" } }

      before do
        stub_request(:post, "#{api_base_url}/orderexecution/orderconfirm")
          .with(body: order.to_json)
          .to_return(
            status: 200,
            body: { EstimatedCost: 15_000, Commission: 5 }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "confirms order and returns estimates" do
        response = client.confirm_order(
          access_token: access_token,
          order: order,
        )
        expect(response).to(eq("EstimatedCost" => 15_000, "Commission" => 5))
      end

      it "sends order data as JSON body" do
        client.confirm_order(
          access_token: access_token,
          order: order,
        )

        expect(WebMock).to(have_requested(:post, "#{api_base_url}/orderexecution/orderconfirm")
          .with(body: order.to_json))
      end
    end

    describe "#place_order" do
      let(:order) { { Symbol: "AAPL", Quantity: 100, OrderType: "Market", BuyOrSell: "Buy" } }

      before do
        stub_request(:post, "#{api_base_url}/orderexecution/orders")
          .with(body: order.to_json)
          .to_return(
            status: 201,
            body: { OrderID: "ORD123", Status: "PENDING" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "places order and returns order details" do
        response = client.place_order(
          access_token: access_token,
          order: order,
        )
        expect(response).to(eq("OrderID" => "ORD123", "Status" => "PENDING"))
      end

      it "does not retry on failure (non-idempotent)" do
        stub_request(:post, "#{api_base_url}/orderexecution/orders")
          .to_return(status: 503)
          .times(1)

        expect do
          client.place_order(
            access_token: access_token,
            order: order,
          )
        end.to(raise_error(Tradestation::ApiError))

        expect(WebMock).to(have_requested(:post, "#{api_base_url}/orderexecution/orders").once)
      end
    end

    describe "#replace_order" do
      let(:order) { { Quantity: 200 } }

      before do
        stub_request(:put, "#{api_base_url}/orderexecution/orders/ORD123")
          .with(body: order.to_json)
          .to_return(
            status: 200,
            body: { OrderID: "ORD123", Status: "REPLACED" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "replaces existing order" do
        response = client.replace_order(
          access_token: access_token,
          order_id: "ORD123",
          order: order,
        )
        expect(response).to(eq("OrderID" => "ORD123", "Status" => "REPLACED"))
      end
    end

    describe "#cancel_order" do
      before do
        stub_request(:delete, "#{api_base_url}/orderexecution/orders/ORD123")
          .to_return(
            status: 200,
            body: { OrderID: "ORD123", Status: "CANCELLED" }.to_json,
            headers: { "Content-Type" => "application/json" },
          )
      end

      it "cancels order" do
        response = client.cancel_order(
          access_token: access_token,
          order_id: "ORD123",
        )
        expect(response).to(eq("OrderID" => "ORD123", "Status" => "CANCELLED"))
      end
    end

    describe "#get_quotes" do
      context "with single symbol" do
        before do
          stub_request(:get, "#{api_base_url}/marketdata/quotes/AAPL")
            .to_return(
              status: 200,
              body: { Symbol: "AAPL", Last: 150.00, Bid: 149.95, Ask: 150.05 }.to_json,
              headers: { "Content-Type" => "application/json" },
            )
        end

        it "fetches quote for single symbol" do
          response = client.get_quotes(
            access_token: access_token,
            symbols: "AAPL",
          )
          expect(response).to(eq("Symbol" => "AAPL", "Last" => 150.00, "Bid" => 149.95, "Ask" => 150.05))
        end
      end

      context "with multiple symbols" do
        before do
          stub_request(:get, "#{api_base_url}/marketdata/quotes/AAPL,GOOGL,TSLA")
            .to_return(
              status: 200,
              body: { Quotes: [] }.to_json,
              headers: { "Content-Type" => "application/json" },
            )
        end

        it "fetches quotes for multiple symbols" do
          response = client.get_quotes(
            access_token: access_token,
            symbols: ["AAPL", "GOOGL", "TSLA"],
          )
          expect(response).to(eq("Quotes" => []))
        end

        it "joins multiple symbols with comma" do
          client.get_quotes(
            access_token: access_token,
            symbols: ["AAPL", "GOOGL", "TSLA"],
          )

          expect(WebMock).to(have_requested(:get, "#{api_base_url}/marketdata/quotes/AAPL,GOOGL,TSLA"))
        end
      end
    end
  end
end
