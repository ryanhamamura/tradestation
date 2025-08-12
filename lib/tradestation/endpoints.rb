# frozen_string_literal: true

module Tradestation
  # Module containing TradeStation API endpoints and OAuth scopes
  #
  # @api private
  module Endpoints
    # Production environment endpoints
    PRODUCTION = {
      base_url: "https://api.tradestation.com",
      auth_url: "https://signin.tradestation.com/oauth/authorize",
      token_url: "https://signin.tradestation.com/oauth/token",
      audience: "https://api.tradestation.com",
    }.freeze

    # Sandbox environment endpoints
    SANDBOX = {
      base_url: "https://sim-api.tradestation.com",
      auth_url: "https://signin.tradestation.com/oauth/authorize",
      token_url: "https://signin.tradestation.com/oauth/token",
      audience: "https://api.tradestation.com",
    }.freeze

    # All available OAuth scopes for TradeStation API
    #
    # @note Not all scopes may be available for your application
    ALL_SCOPES = [
      "openid",
      "profile",
      "offline_access",
      "MarketData",
      "ReadAccount",
      "Trade",
      "Matrix",
      "OptionSpreads",
    ].freeze

    # Required OAuth scopes that must be requested
    REQUIRED_SCOPES = ["openid"].freeze

    class << self
      # Get endpoints for the specified environment
      #
      # @param environment [Symbol, String] The environment (:production or :sandbox)
      # @return [Hash] Hash containing base_url, auth_url, token_url, and audience
      # @raise [ConfigurationError] if environment is invalid
      #
      # @api private
      def for_environment(environment)
        case environment.to_sym
        when :production
          PRODUCTION
        when :sandbox
          SANDBOX
        else
          raise ConfigurationError, "Invalid environment: #{environment}. Must be :production or :sandbox"
        end
      end
    end
  end
end
