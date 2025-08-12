# frozen_string_literal: true

module Tradestation
  module Endpoints
    PRODUCTION = {
      base_url: "https://api.tradestation.com",
      auth_url: "https://signin.tradestation.com/oauth/authorize",
      token_url: "https://signin.tradestation.com/oauth/token",
      api_url: "https://api.tradestation.com/v3",
      audience: "https://api.tradestation.com"
    }.freeze

    SANDBOX = {
      base_url: "https://sim-api.tradestation.com",
      auth_url: "https://signin.tradestation.com/oauth/authorize",
      token_url: "https://signin.tradestation.com/oauth/token",
      api_url: "https://sim-api.tradestation.com/v3",
      audience: "https://api.tradestation.com"
    }.freeze

    ALL_SCOPES = %w[
      openid
      profile
      offline_access
      MarketData
      ReadAccount
      Trade
      Matrix
      OptionSpreads
    ].freeze

    REQUIRED_SCOPES = %w[openid].freeze

    def self.for_environment(environment)
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
