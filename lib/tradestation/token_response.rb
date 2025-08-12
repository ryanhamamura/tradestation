# frozen_string_literal: true

require "time"
require "jwt"

module Tradestation
  class TokenResponse
    attr_reader :access_token, :refresh_token, :expires_in, :expires_at,
                :token_type, :scope, :id_token, :raw_response

    def initialize(oauth_token)
      @raw_response = oauth_token

      if oauth_token.is_a?(OAuth2::AccessToken)
        @access_token = oauth_token.token
        @refresh_token = oauth_token.refresh_token
        @expires_in = oauth_token.expires_in
        @expires_at = oauth_token.expires_at ? Time.at(oauth_token.expires_at) : nil
        # OAuth2::AccessToken stores additional data in the params hash
        @token_type = oauth_token.params[:token_type] || oauth_token.params["token_type"] || "Bearer"
        @scope = parse_scope(oauth_token.params[:scope] || oauth_token.params["scope"])
        @id_token = oauth_token.params[:id_token] || oauth_token.params["id_token"]
      elsif oauth_token.is_a?(Hash)
        @access_token = oauth_token["access_token"] || oauth_token[:access_token]
        @refresh_token = oauth_token["refresh_token"] || oauth_token[:refresh_token]
        @expires_in = oauth_token["expires_in"] || oauth_token[:expires_in]
        @expires_at = calculate_expires_at(@expires_in)
        @token_type = oauth_token["token_type"] || oauth_token[:token_type] || "Bearer"
        @scope = parse_scope(oauth_token["scope"] || oauth_token[:scope])
        @id_token = oauth_token["id_token"] || oauth_token[:id_token]
      else
        raise ArgumentError, "TokenResponse requires OAuth2::AccessToken or Hash"
      end
    end

    def expired?
      return false unless expires_at

      Time.now >= expires_at
    end

    def expires_soon?(seconds = 300)
      return false unless expires_at

      Time.now >= (expires_at - seconds)
    end

    def time_until_expiry
      return nil unless expires_at

      seconds = expires_at - Time.now
      seconds.positive? ? seconds : 0
    end

    def decoded_id_token
      return nil unless id_token

      @decoded_id_token ||= JWT.decode(
        id_token,
        nil,
        false # Don't verify signature for now
      ).first
    rescue JWT::DecodeError => e
      raise AuthenticationError, "Failed to decode ID token: #{e.message}"
    end

    def user_id
      decoded_id_token&.dig("sub")
    end

    def to_h
      {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: expires_in,
        expires_at: expires_at&.iso8601,
        token_type: token_type,
        scope: scope,
        id_token: id_token
      }.compact
    end

    def bearer_token
      "#{token_type} #{access_token}"
    end

    private

    def parse_scope(scope_value)
      return [] if scope_value.nil?

      scope_value.is_a?(Array) ? scope_value : scope_value.to_s.split(" ")
    end

    def calculate_expires_at(expires_in_value)
      return nil unless expires_in_value

      Time.now + expires_in_value.to_i
    end
  end
end
