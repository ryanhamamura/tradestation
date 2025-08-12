# frozen_string_literal: true

module Tradestation
  # Base error class for all TradeStation errors
  class Error < StandardError; end

  # Error raised when authentication fails
  #
  # @example Handling authentication errors
  #   begin
  #     client.exchange_code_for_token(code: invalid_code)
  #   rescue Tradestation::AuthenticationError => e
  #     puts "Auth failed: #{e.message}"
  #     puts "Error code: #{e.error_code}"
  #   end
  class AuthenticationError < Error
    # @return [String, nil] OAuth error code (e.g., "invalid_grant")
    attr_reader :error_code

    # @return [String, nil] Detailed error description from OAuth provider
    attr_reader :error_description

    # Initialize a new AuthenticationError
    #
    # @param message [String, nil] Error message
    # @param error_code [String, nil] OAuth error code
    # @param error_description [String, nil] OAuth error description
    def initialize(message = nil, error_code: nil, error_description: nil)
      super(message || error_description || "Authentication failed")
      @error_code = error_code
      @error_description = error_description
    end
  end

  # Error raised when an OAuth token has expired
  #
  # @example Handling expired tokens
  #   begin
  #     client.authenticated_request(access_token: expired_token, ...)
  #   rescue Tradestation::TokenExpiredError => e
  #     # Refresh the token
  #     new_token = client.refresh_token(refresh_token: stored_refresh_token)
  #   end
  class TokenExpiredError < Error
    # Initialize a new TokenExpiredError
    #
    # @param message [String, nil] Error message
    def initialize(message = nil)
      super(message || "Token has expired")
    end
  end

  # Error raised when configuration is invalid or missing
  #
  # @example Invalid configuration
  #   config = Tradestation::Configuration.new
  #   config.client_id = nil
  #   config.validate! # raises ConfigurationError
  class ConfigurationError < Error
    # Initialize a new ConfigurationError
    #
    # @param message [String, nil] Error message
    def initialize(message = nil)
      super(message || "Invalid configuration")
    end
  end

  # Error raised when API requests fail
  #
  # @example Handling API errors
  #   begin
  #     client.get_accounts(access_token: token)
  #   rescue Tradestation::ApiError => e
  #     puts "API error: #{e.message}"
  #     puts "Status: #{e.status_code}"
  #     puts "Response: #{e.response_body}"
  #   end
  class ApiError < Error
    # @return [Integer, nil] HTTP status code
    attr_reader :status_code

    # @return [String, Hash, nil] Response body from the API
    attr_reader :response_body

    # Initialize a new ApiError
    #
    # @param message [String, nil] Error message
    # @param status_code [Integer, nil] HTTP status code
    # @param response_body [String, Hash, nil] Response body
    def initialize(message = nil, status_code: nil, response_body: nil)
      super(message || "API request failed")
      @status_code = status_code
      @response_body = response_body
    end
  end
end
