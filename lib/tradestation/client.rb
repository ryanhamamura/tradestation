# frozen_string_literal: true

require "securerandom"
require "digest"
require "base64"
require "faraday"
require "faraday/retry"

module Tradestation
  # Client for interacting with the TradeStation API
  #
  # Provides OAuth authentication and API request methods for TradeStation's trading platform.
  # Supports both sandbox and production environments.
  #
  # @example Basic usage with global configuration
  #   Tradestation.configure do |config|
  #     config.client_id = ENV['TRADESTATION_CLIENT_ID']
  #     config.client_secret = ENV['TRADESTATION_CLIENT_SECRET']
  #     config.redirect_uri = 'http://localhost:3000/callback'
  #   end
  #   client = Tradestation::Client.new
  #
  # @example OAuth flow
  #   # Step 1: Get authorization URL
  #   auth = client.authorization_url
  #   redirect_to auth[:url]
  #
  #   # Step 2: Exchange code for token
  #   token = client.exchange_code_for_token(
  #     code: params[:code],
  #     code_verifier: session[:code_verifier]
  #   )
  #
  # @see https://api.tradestation.com/docs TradeStation API Documentation
  class Client
    # @return [Configuration] TradeStation configuration
    attr_reader :configuration

    # Initialize a new TradeStation API client
    #
    # @param config [Configuration, Hash, nil] Configuration options
    # @return [Client] A new client instance
    # @raise [ConfigurationError] if no configuration is provided
    # @raise [ArgumentError] if config is not Configuration, Hash, or nil
    #
    # @example Using global configuration
    #   client = Tradestation::Client.new
    #
    # @example Using custom configuration
    #   client = Tradestation::Client.new(
    #     client_id: 'your_id',
    #     client_secret: 'your_secret'
    #   )
    def initialize(config = nil)
      @configuration = case config
      when Configuration
        config
      when Hash
        build_configuration_from_hash(config)
      when nil
        Tradestation.configuration || raise(ConfigurationError, "No configuration provided")
      else
        raise ArgumentError, "Configuration must be a Configuration object or Hash"
      end

      @configuration.validate!
      @oauth_client = nil
    end

    # Generate OAuth authorization URL with optional PKCE
    #
    # Generates the authorization URL for the OAuth flow. By default, uses PKCE
    # (Proof Key for Code Exchange) for enhanced security.
    #
    # @param state [String, nil] OAuth state parameter for CSRF protection (auto-generated if nil)
    # @param scopes [Array<String>, String, nil] OAuth scopes to request (uses configured scopes if nil)
    # @param code_challenge_method [String, nil] PKCE method ("S256" or "plain", nil to disable PKCE)
    # @return [Hash{Symbol => String}] Hash containing :url, :state, and optionally :code_verifier
    #
    # @example Generate authorization URL with PKCE
    #   auth = client.authorization_url
    #   # Store auth[:code_verifier] in session
    #   session[:code_verifier] = auth[:code_verifier]
    #   redirect_to auth[:url]
    #
    # @example Custom scopes
    #   auth = client.authorization_url(scopes: ['openid', 'profile', 'Trade'])
    def authorization_url(state: nil, scopes: nil, code_challenge_method: "S256")
      state ||= generate_state
      scopes ||= configuration.scopes

      params = {
        response_type: "code",
        client_id: configuration.client_id,
        redirect_uri: configuration.redirect_uri,
        state: state,
        scope: Array(scopes).join(" "),
      }

      if code_challenge_method
        code_verifier = generate_code_verifier
        code_challenge = generate_code_challenge(code_verifier, code_challenge_method)

        params[:code_challenge] = code_challenge
        params[:code_challenge_method] = code_challenge_method

        # Return both URL and PKCE values for the caller to store
        {
          url: build_auth_url(params),
          state: state,
          code_verifier: code_verifier,
        }
      else
        {
          url: build_auth_url(params),
          state: state,
        }
      end
    end

    # Exchange authorization code for access token
    #
    # @param code [String] Authorization code from OAuth callback
    # @param code_verifier [String, nil] PKCE code verifier (required if PKCE was used)
    # @return [TokenResponse] Token response with access and refresh tokens
    # @raise [ArgumentError] if code is nil or empty
    # @raise [AuthenticationError] if token exchange fails
    #
    # @example Exchange code for token
    #   token = client.exchange_code_for_token(
    #     code: params[:code],
    #     code_verifier: session[:code_verifier]
    #   )
    #   # Store tokens securely
    #   session[:access_token] = token.access_token
    #   session[:refresh_token] = token.refresh_token
    def exchange_code_for_token(code:, code_verifier: nil)
      raise ArgumentError, "Authorization code is required" if code.nil? || code.empty?

      oauth_token = oauth_client.auth_code.get_token(
        code,
        redirect_uri: configuration.redirect_uri,
        code_verifier: code_verifier,
      )

      TokenResponse.new(oauth_token)
    rescue OAuth2::Error => e
      handle_oauth_error(e)
    end

    # Refresh an expired access token
    #
    # @param refresh_token [String] Refresh token from previous token response
    # @return [TokenResponse] New token response with fresh access token
    # @raise [ArgumentError] if refresh_token is nil or empty
    # @raise [AuthenticationError] if token refresh fails
    #
    # @example Refresh expired token
    #   new_token = client.refresh_token(
    #     refresh_token: stored_refresh_token
    #   )
    #   session[:access_token] = new_token.access_token
    def refresh_token(refresh_token:)
      raise ArgumentError, "Refresh token is required" if refresh_token.nil? || refresh_token.empty?

      token = OAuth2::AccessToken.new(oauth_client.client, nil, refresh_token: refresh_token)
      refreshed_token = token.refresh!

      TokenResponse.new(refreshed_token)
    rescue OAuth2::Error => e
      handle_oauth_error(e)
    end

    # Check if a token has expired
    #
    # @param expires_at [Time, Integer, String, nil] Token expiration time
    # @return [Boolean] true if expired, false otherwise
    # @raise [ArgumentError] if expires_at is not a valid time format
    #
    # @example Check token expiration
    #   if client.token_expired?(token.expires_at)
    #     token = client.refresh_token(refresh_token: stored_refresh_token)
    #   end
    def token_expired?(expires_at)
      return false if expires_at.nil?

      expires_at_time = case expires_at
      when Time
        expires_at
      when Integer, Float
        Time.at(expires_at)
      when String
        Time.parse(expires_at)
      else
        raise ArgumentError, "expires_at must be a Time, Integer (Unix timestamp), or String"
      end

      Time.now >= expires_at_time
    end

    # Check if a token expires soon
    #
    # @param expires_at [Time, Integer, String, nil] Token expiration time
    # @param buffer_seconds [Integer] Buffer time before expiry (default: 300 seconds)
    # @return [Boolean] true if expires within buffer time, false otherwise
    # @raise [ArgumentError] if expires_at is not a valid time format
    #
    # @example Proactively refresh token
    #   if client.token_expires_soon?(token.expires_at, 600) # 10 minutes
    #     token = client.refresh_token(refresh_token: stored_refresh_token)
    #   end
    def token_expires_soon?(expires_at, buffer_seconds = 300)
      return false if expires_at.nil?

      expires_at_time = case expires_at
      when Time
        expires_at
      when Integer, Float
        Time.at(expires_at)
      when String
        Time.parse(expires_at)
      else
        raise ArgumentError, "expires_at must be a Time, Integer (Unix timestamp), or String"
      end

      Time.now >= (expires_at_time - buffer_seconds)
    end

    # Make an authenticated API request
    #
    # @param method [Symbol, String] HTTP method (:get, :post, :put, :patch, :delete)
    # @param path [String] API endpoint path (without base URL or /v3 prefix)
    # @param access_token [String] OAuth access token
    # @param params [Hash] Query parameters for GET/DELETE requests
    # @param headers [Hash] Additional HTTP headers
    # @param body [Hash, String, nil] Request body for POST/PUT/PATCH requests
    # @param max_retries [Integer] Maximum number of retries (currently unused)
    # @return [Hash, Array, nil] Parsed JSON response
    # @raise [ArgumentError] if access_token is nil or empty
    # @raise [AuthenticationError] if authentication fails
    # @raise [ApiError] if API request fails
    #
    # @example Make a GET request
    #   accounts = client.authenticated_request(
    #     method: :get,
    #     path: '/brokerage/accounts',
    #     access_token: token.access_token
    #   )
    #
    # @example Make a POST request with body
    #   order = client.authenticated_request(
    #     method: :post,
    #     path: '/orderexecution/orders',
    #     access_token: token.access_token,
    #     body: {
    #       AccountID: '123456',
    #       Symbol: 'AAPL',
    #       Quantity: '10',
    #       OrderType: 'Market',
    #       TradeAction: 'BUY',
    #       TimeInForce: { Duration: 'DAY' },
    #       Route: 'Intelligent'
    #     }
    #   )
    def authenticated_request(method:, path:, access_token:, params: {}, headers: {}, body: nil, max_retries: 3)
      raise ArgumentError, "access_token is required" if access_token.nil? || access_token.empty?

      # Get the base URL for the environment
      endpoints = Endpoints.for_environment(configuration.environment)
      base_url = endpoints[:base_url] # Use the base URL without version

      # Build path with v3 API version prefix
      path_with_slash = path.start_with?("/") ? path : "/#{path}"
      request_path = "/v3#{path_with_slash}"

      # Set up the connection without retry middleware for now
      connection = Faraday.new(url: base_url) do |conn|
        conn.request(:json)
        conn.response(:json)
        conn.adapter(Faraday.default_adapter)
      end

      # Prepare headers with authentication
      auth_headers = {
        "Authorization" => "Bearer #{access_token}",
        "Accept" => "application/json",
        "Content-Type" => "application/json",
      }.merge(headers)

      # Make the request
      response = case method.to_sym
      when :get
        connection.get(request_path, params, auth_headers)
      when :post
        connection.post(request_path, body, auth_headers)
      when :put
        connection.put(request_path, body, auth_headers)
      when :patch
        connection.patch(request_path, body, auth_headers)
      when :delete
        connection.delete(request_path, params, auth_headers)
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end

      # Handle the response
      handle_api_response(response)
    rescue Faraday::Error => e
      raise ApiError.new(
        "Request failed: #{e.message}",
        status_code: e.response&.status,
        response_body: e.response&.body,
      )
    end

    # Get all brokerage accounts
    #
    # @param access_token [String] OAuth access token
    # @return [Array<Hash>] Array of account information
    # @raise [ApiError] if request fails
    #
    # @example Get all accounts
    #   accounts = client.get_accounts(access_token: token.access_token)
    #   accounts.each { |account| puts account['AccountID'] }
    def get_accounts(access_token:)
      authenticated_request(
        method: :get,
        path: "/brokerage/accounts",
        access_token: access_token,
      )
    end

    # Get account balances
    #
    # @param access_token [String] OAuth access token
    # @param account_ids [String, Array<String>] Single account ID or array of IDs
    # @return [Array<Hash>] Array of balance information
    # @raise [ApiError] if request fails
    #
    # @example Get balances for multiple accounts
    #   balances = client.get_account_balances(
    #     access_token: token.access_token,
    #     account_ids: ['123456', '789012']
    #   )
    def get_account_balances(access_token:, account_ids:)
      account_ids_str = Array(account_ids).join(",")

      authenticated_request(
        method: :get,
        path: "/brokerage/accounts/#{account_ids_str}/balances",
        access_token: access_token,
      )
    end

    # Get account positions
    #
    # @param access_token [String] OAuth access token
    # @param account_ids [String, Array<String>] Single account ID or array of IDs
    # @return [Array<Hash>] Array of position information
    # @raise [ApiError] if request fails
    #
    # @example Get positions for an account
    #   positions = client.get_positions(
    #     access_token: token.access_token,
    #     account_ids: '123456'
    #   )
    def get_positions(access_token:, account_ids:)
      account_ids_str = Array(account_ids).join(",")

      authenticated_request(
        method: :get,
        path: "/brokerage/accounts/#{account_ids_str}/positions",
        access_token: access_token,
      )
    end

    # Get today's and open orders
    #
    # @param access_token [String] OAuth access token
    # @param account_ids [String, Array<String>] Single account ID or array of IDs
    # @return [Array<Hash>] Array of order information
    # @raise [ApiError] if request fails
    #
    # @example Get orders for an account
    #   orders = client.get_orders(
    #     access_token: token.access_token,
    #     account_ids: '123456'
    #   )
    def get_orders(access_token:, account_ids:)
      account_ids_str = Array(account_ids).join(",")

      authenticated_request(
        method: :get,
        path: "/brokerage/accounts/#{account_ids_str}/orders",
        access_token: access_token,
      )
    end

    # Get historical orders
    #
    # @param access_token [String] OAuth access token
    # @param account_ids [String, Array<String>] Single account ID or array of IDs
    # @param since [String] Date to retrieve orders from (ISO 8601 format)
    # @return [Array<Hash>] Array of historical order information
    # @raise [ApiError] if request fails
    #
    # @example Get orders from last 30 days
    #   orders = client.get_historical_orders(
    #     access_token: token.access_token,
    #     account_ids: '123456',
    #     since: (Date.today - 30).iso8601
    #   )
    def get_historical_orders(access_token:, account_ids:, since:)
      account_ids_str = Array(account_ids).join(",")

      authenticated_request(
        method: :get,
        path: "/brokerage/accounts/#{account_ids_str}/historicalorders",
        access_token: access_token,
        params: { since: since },
      )
    end

    # Confirm an order (get cost and commission estimates)
    #
    # @param access_token [String] OAuth access token
    # @param order [Hash] Order details for confirmation
    # @return [Hash] Order confirmation with estimates
    # @raise [ApiError] if request fails
    #
    # @example Confirm order before placing
    #   confirmation = client.confirm_order(
    #     access_token: token.access_token,
    #     order: {
    #       AccountID: '123456',
    #       Symbol: 'AAPL',
    #       Quantity: '10',
    #       OrderType: 'Market',
    #       TradeAction: 'BUY',
    #       TimeInForce: { Duration: 'DAY' },
    #       Route: 'Intelligent'
    #     }
    #   )
    def confirm_order(access_token:, order:)
      authenticated_request(
        method: :post,
        path: "/orderexecution/orderconfirm",
        access_token: access_token,
        body: order,
      )
    end

    # Place a new order
    #
    # @param access_token [String] OAuth access token
    # @param order [Hash] Order details
    # @return [Hash] Order placement response with order ID
    # @raise [ApiError] if request fails
    #
    # @example Place a market order
    #   response = client.place_order(
    #     access_token: token.access_token,
    #     order: {
    #       AccountID: '123456',
    #       Symbol: 'AAPL',
    #       Quantity: '10',
    #       OrderType: 'Market',
    #       TradeAction: 'BUY',
    #       TimeInForce: { Duration: 'DAY' },
    #       Route: 'Intelligent'
    #     }
    #   )
    #   puts "Order ID: #{response['OrderID']}"
    def place_order(access_token:, order:)
      authenticated_request(
        method: :post,
        path: "/orderexecution/orders",
        access_token: access_token,
        body: order,
      )
    end

    # Replace an existing order
    #
    # @param access_token [String] OAuth access token
    # @param order_id [String] ID of the order to replace
    # @param order [Hash] New order details
    # @return [Hash] Order replacement response
    # @raise [ApiError] if request fails
    #
    # @example Replace order with new price
    #   response = client.replace_order(
    #     access_token: token.access_token,
    #     order_id: '12345',
    #     order: {
    #       AccountID: '123456',
    #       Symbol: 'AAPL',
    #       Quantity: '10',
    #       OrderType: 'Limit',
    #       LimitPrice: '150.00',
    #       TradeAction: 'BUY',
    #       TimeInForce: { Duration: 'DAY' },
    #       Route: 'Intelligent'
    #     }
    #   )
    def replace_order(access_token:, order_id:, order:)
      authenticated_request(
        method: :put,
        path: "/orderexecution/orders/#{order_id}",
        access_token: access_token,
        body: order,
      )
    end

    # Cancel an order
    #
    # @param access_token [String] OAuth access token
    # @param order_id [String] ID of the order to cancel
    # @return [Hash] Cancellation response
    # @raise [ApiError] if request fails
    #
    # @example Cancel an order
    #   response = client.cancel_order(
    #     access_token: token.access_token,
    #     order_id: '12345'
    #   )
    def cancel_order(access_token:, order_id:)
      authenticated_request(
        method: :delete,
        path: "/orderexecution/orders/#{order_id}",
        access_token: access_token,
      )
    end

    # Get market quotes for symbols
    #
    # @param access_token [String] OAuth access token
    # @param symbols [String, Array<String>] Single symbol or array of symbols
    # @return [Array<Hash>] Array of quote data
    # @raise [ApiError] if request fails
    #
    # @example Get quotes for multiple symbols
    #   quotes = client.get_quotes(
    #     access_token: token.access_token,
    #     symbols: ['AAPL', 'GOOGL', 'MSFT']
    #   )
    def get_quotes(access_token:, symbols:)
      authenticated_request(
        method: :get,
        path: "/marketdata/quotes/#{Array(symbols).join(",")}",
        access_token: access_token,
      )
    end

    private

    # @api private

    # Get or create the OAuth2 client
    # @return [OAuth2Client] OAuth2 client instance
    # @api private
    def oauth_client
      @oauth_client ||= OAuth2Client.new(configuration)
    end

    # Build configuration from a hash
    # @param hash [Hash] Configuration options
    # @return [Configuration] Configuration instance
    # @api private
    def build_configuration_from_hash(hash)
      config = Configuration.new
      hash.each do |key, value|
        setter = "#{key}="
        config.send(setter, value) if config.respond_to?(setter)
      end
      config
    end

    # Generate a secure random state parameter
    # @return [String] Random state string
    # @api private
    def generate_state
      SecureRandom.urlsafe_base64(32)
    end

    # Generate a PKCE code verifier
    # @return [String] Random code verifier
    # @api private
    def generate_code_verifier
      SecureRandom.urlsafe_base64(32)
    end

    # Generate a PKCE code challenge from verifier
    # @param verifier [String] Code verifier
    # @param method [String] Challenge method ("S256" or "plain")
    # @return [String] Code challenge
    # @raise [ArgumentError] if method is unsupported
    # @api private
    def generate_code_challenge(verifier, method)
      case method
      when "S256"
        Base64.urlsafe_encode64(
          Digest::SHA256.digest(verifier),
          padding: false,
        )
      when "plain"
        verifier
      else
        raise ArgumentError, "Unsupported code challenge method: #{method}"
      end
    end

    # Build the full authorization URL
    # @param params [Hash] URL parameters
    # @return [String] Full authorization URL
    # @api private
    def build_auth_url(params)
      endpoints = Endpoints.for_environment(configuration.environment)
      base_url = endpoints[:auth_url]
      uri = URI(base_url)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    # Handle API response and raise appropriate errors
    # @param response [Faraday::Response] API response
    # @return [Hash, Array, nil] Parsed response body
    # @raise [AuthenticationError] if authentication fails
    # @raise [ApiError] if request fails
    # @api private
    def handle_api_response(response)
      case response.status
      when 200..299
        response.body
      when 401
        raise AuthenticationError, "Authentication failed: #{response.body}"
      when 403
        raise AuthenticationError, "Access forbidden: #{response.body}"
      when 404
        raise ApiError.new("Resource not found", status_code: 404, response_body: response.body)
      when 400..499
        raise ApiError.new("Client error", status_code: response.status, response_body: response.body)
      when 500..599
        raise ApiError.new("Server error", status_code: response.status, response_body: response.body)
      else
        raise ApiError.new("Unexpected response", status_code: response.status, response_body: response.body)
      end
    end

    # Handle OAuth errors and raise appropriate exceptions
    # @param error [OAuth2::Error] OAuth error
    # @raise [AuthenticationError] if authentication fails
    # @raise [TokenExpiredError] if token is expired
    # @raise [ApiError] for other errors
    # @api private
    def handle_oauth_error(error)
      case error.response.status
      when 401
        raise AuthenticationError.new(
          "Authentication failed",
          error_code: error.code,
          error_description: error.description,
        )
      when 400
        raise TokenExpiredError, error.description if error.description&.downcase&.include?("expired")

        raise AuthenticationError.new(
          error.description,
          error_code: error.code,
          error_description: error.description,
        )

      else
        raise ApiError.new(
          error.message,
          status_code: error.response.status,
          response_body: error.response.body,
        )
      end
    end
  end
end
