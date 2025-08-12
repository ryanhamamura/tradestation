# frozen_string_literal: true

require "time"
require "jwt"

module Tradestation
  # Represents an OAuth token response from TradeStation
  #
  # Wraps the OAuth2 token response and provides convenience methods
  # for token management and expiration checking.
  #
  # @example Creating from OAuth2::AccessToken
  #   oauth_token = client.exchange_code_for_token(code: auth_code)
  #   token = TokenResponse.new(oauth_token)
  #   puts token.access_token
  #   puts token.expired?
  #
  # @example Creating from Hash
  #   token = TokenResponse.new({
  #     "access_token" => "abc123",
  #     "refresh_token" => "def456",
  #     "expires_in" => 3600
  #   })
  class TokenResponse
    # @return [String] OAuth access token
    attr_reader :access_token

    # @return [String, nil] OAuth refresh token
    attr_reader :refresh_token

    # @return [Integer, nil] Token lifetime in seconds
    attr_reader :expires_in

    # @return [Time, nil] Absolute time when token expires
    attr_reader :expires_at

    # @return [String] Token type (usually "Bearer")
    attr_reader :token_type

    # @return [Array<String>] OAuth scopes granted
    attr_reader :scope

    # @return [String, nil] OpenID Connect ID token
    attr_reader :id_token

    # @return [OAuth2::AccessToken, Hash] Original response object
    attr_reader :raw_response

    # Initialize a new TokenResponse
    #
    # @param oauth_token [OAuth2::AccessToken, Hash] Token data from OAuth2 gem or raw hash
    # @raise [ArgumentError] if oauth_token is not OAuth2::AccessToken or Hash
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

    # Check if the token has expired
    #
    # @return [Boolean] true if token is expired, false otherwise
    def expired?
      return false unless expires_at

      Time.now >= expires_at
    end

    # Check if the token expires soon
    #
    # @param seconds [Integer] Buffer time in seconds (default: 300)
    # @return [Boolean] true if token expires within the buffer time
    def expires_soon?(seconds = 300)
      return false unless expires_at

      Time.now >= (expires_at - seconds)
    end

    # Get the time remaining until token expiry
    #
    # @return [Float, nil] Seconds until expiry, 0 if expired, nil if no expiry
    def time_until_expiry
      return unless expires_at

      seconds = expires_at - Time.now
      seconds.positive? ? seconds : 0
    end

    # Decode the OpenID Connect ID token
    #
    # @return [Hash, nil] Decoded JWT claims or nil if no ID token
    # @raise [AuthenticationError] if ID token cannot be decoded
    #
    # @note This does not verify the token signature
    def decoded_id_token
      return unless id_token

      @decoded_id_token ||= JWT.decode(
        id_token,
        nil,
        false, # Don't verify signature for now
      ).first
    rescue JWT::DecodeError => e
      raise AuthenticationError, "Failed to decode ID token: #{e.message}"
    end

    # Get the user ID from the ID token
    #
    # @return [String, nil] User ID (subject claim) from ID token
    def user_id
      decoded_id_token&.dig("sub")
    end

    # Convert token data to a hash
    #
    # @return [Hash] Token data as a hash with symbol keys
    def to_h
      {
        access_token: access_token,
        refresh_token: refresh_token,
        expires_in: expires_in,
        expires_at: expires_at&.iso8601,
        token_type: token_type,
        scope: scope,
        id_token: id_token,
      }.compact
    end

    # Get the formatted bearer token for Authorization headers
    #
    # @return [String] Formatted token (e.g., "Bearer abc123")
    #
    # @example Using in a request
    #   headers = { "Authorization" => token.bearer_token }
    def bearer_token
      "#{token_type} #{access_token}"
    end

    private

    # Parse scope value into an array
    #
    # @param scope_value [String, Array, nil] Scope value
    # @return [Array<String>] Array of scopes
    # @api private
    def parse_scope(scope_value)
      return [] if scope_value.nil?

      scope_value.is_a?(Array) ? scope_value : scope_value.to_s.split
    end

    # Calculate absolute expiration time from expires_in
    #
    # @param expires_in_value [Integer, nil] Seconds until expiry
    # @return [Time, nil] Absolute expiration time
    # @api private
    def calculate_expires_at(expires_in_value)
      return unless expires_in_value

      Time.now + expires_in_value.to_i
    end
  end
end
