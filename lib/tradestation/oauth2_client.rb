# frozen_string_literal: true

require "oauth2"

module Tradestation
  class OAuth2Client
    attr_reader :configuration, :client

    def initialize(configuration)
      @configuration = configuration
      @client = build_oauth2_client
    end

    def auth_code
      client.auth_code
    end

    def authorize_url(params = {})
      client.auth_code.authorize_url(params)
    end

    def get_token(code, params = {})
      client.auth_code.get_token(code, params)
    end

    def refresh_token(refresh_token_value)
      token = OAuth2::AccessToken.new(client, nil, refresh_token: refresh_token_value)
      token.refresh!
    end

    private

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
            timeout: configuration.timeout || 30
          }
        }
      )
    end
  end
end
