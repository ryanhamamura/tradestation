# frozen_string_literal: true

require "securerandom"
require "digest"
require "base64"

module Tradestation
  class Client
    attr_reader :configuration

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

    def authorization_url(state: nil, scopes: nil, code_challenge_method: "S256")
      state ||= generate_state
      scopes ||= configuration.scopes

      params = {
        response_type: "code",
        client_id: configuration.client_id,
        redirect_uri: configuration.redirect_uri,
        state: state,
        scope: Array(scopes).join(" ")
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
          code_verifier: code_verifier
        }
      else
        {
          url: build_auth_url(params),
          state: state
        }
      end
    end

    def exchange_code_for_token(code:, code_verifier: nil)
      raise ArgumentError, "Authorization code is required" if code.nil? || code.empty?

      oauth_token = oauth_client.auth_code.get_token(
        code,
        redirect_uri: configuration.redirect_uri,
        code_verifier: code_verifier
      )

      TokenResponse.new(oauth_token)
    rescue OAuth2::Error => e
      handle_oauth_error(e)
    end

    def refresh_token(refresh_token:)
      raise ArgumentError, "Refresh token is required" if refresh_token.nil? || refresh_token.empty?

      token = OAuth2::AccessToken.new(oauth_client.client, nil, refresh_token: refresh_token)
      refreshed_token = token.refresh!

      TokenResponse.new(refreshed_token)
    rescue OAuth2::Error => e
      handle_oauth_error(e)
    end

    private

    def oauth_client
      @oauth_client ||= OAuth2Client.new(configuration)
    end

    def build_configuration_from_hash(hash)
      config = Configuration.new
      hash.each do |key, value|
        setter = "#{key}="
        config.send(setter, value) if config.respond_to?(setter)
      end
      config
    end

    def generate_state
      SecureRandom.urlsafe_base64(32)
    end

    def generate_code_verifier
      SecureRandom.urlsafe_base64(32)
    end

    def generate_code_challenge(verifier, method)
      case method
      when "S256"
        Base64.urlsafe_encode64(
          Digest::SHA256.digest(verifier),
          padding: false
        )
      when "plain"
        verifier
      else
        raise ArgumentError, "Unsupported code challenge method: #{method}"
      end
    end

    def build_auth_url(params)
      endpoints = Endpoints.for_environment(configuration.environment)
      base_url = endpoints[:auth_url]
      uri = URI(base_url)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def handle_oauth_error(error)
      case error.response.status
      when 401
        raise AuthenticationError.new(
          "Authentication failed",
          error_code: error.code,
          error_description: error.description
        )
      when 400
        raise TokenExpiredError, error.description if error.description&.downcase&.include?("expired")

        raise AuthenticationError.new(
          error.description,
          error_code: error.code,
          error_description: error.description
        )

      else
        raise ApiError.new(
          error.message,
          status_code: error.response.status,
          response_body: error.response.body
        )
      end
    end
  end
end
