# frozen_string_literal: true

require "oauth2"

module Tradestation
  # Internal OAuth2 client wrapper
  #
  # This class wraps the OAuth2 gem client and provides TradeStation-specific
  # OAuth functionality. It's primarily used internally by the Client class.
  #
  # @api private
  class OAuth2Client
    # @return [Configuration] TradeStation configuration
    attr_reader :configuration

    # @return [OAuth2::Client] Underlying OAuth2 client
    attr_reader :client

    # Initialize a new OAuth2Client
    #
    # @param configuration [Configuration] TradeStation configuration
    # @api private
    def initialize(configuration)
      @configuration = configuration
      @client = build_oauth2_client
    end

    # Get the authorization code strategy
    #
    # @return [OAuth2::Strategy::AuthCode] Authorization code strategy
    # @api private
    def auth_code
      client.auth_code
    end

    # Generate an authorization URL
    #
    # @param params [Hash] Additional parameters for the authorization URL
    # @return [String] Authorization URL
    # @api private
    def authorize_url(params = {})
      client.auth_code.authorize_url(params)
    end

    # Exchange an authorization code for an access token
    #
    # @param code [String] Authorization code
    # @param params [Hash] Additional parameters
    # @return [OAuth2::AccessToken] Access token
    # @api private
    def get_token(code, params = {})
      client.auth_code.get_token(code, params)
    end

    # Refresh an access token
    #
    # @param refresh_token_value [String] Refresh token
    # @return [OAuth2::AccessToken] New access token
    # @api private
    def refresh_token(refresh_token_value)
      token = OAuth2::AccessToken.new(client, nil, refresh_token: refresh_token_value)
      token.refresh!
    end

    private

    # Build the OAuth2 client with TradeStation endpoints
    #
    # @return [OAuth2::Client] Configured OAuth2 client
    # @api private
    def build_oauth2_client
      endpoints = Endpoints.for_environment(configuration.environment)

      OAuth2::Client.new(
        configuration.client_id,
        configuration.client_secret,
        site: endpoints[:base_url],
        authorize_url: endpoints[:auth_url],
        token_url: endpoints[:token_url],
        auth_scheme: :request_body,
        connection_opts: {
          request: {
            timeout: configuration.timeout || 30,
          },
        },
      )
    end
  end
end
