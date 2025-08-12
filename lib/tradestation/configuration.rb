# frozen_string_literal: true

module Tradestation
  class Configuration
    attr_accessor :client_id, :client_secret, :redirect_uri, :environment, :scopes, :timeout

    ENVIRONMENTS = {
      production: "https://api.tradestation.com",
      sandbox: "https://sim-api.tradestation.com"
    }.freeze

    DEFAULT_SCOPES = %w[openid profile].freeze

    def initialize
      @environment = :sandbox
      @scopes = DEFAULT_SCOPES.dup
      @timeout = 30
    end

    def auth_url
      "#{base_url}/authorize"
    end

    def token_url
      "#{base_url}/token"
    end

    def api_url
      base_url
    end

    def base_url
      ENVIRONMENTS[environment] || raise(ConfigurationError, "Invalid environment: #{environment}")
    end

    def validate!
      raise ConfigurationError, "client_id is required" if client_id.nil? || client_id.empty?
      raise ConfigurationError, "client_secret is required" if client_secret.nil? || client_secret.empty?
      raise ConfigurationError, "redirect_uri is required" if redirect_uri.nil? || redirect_uri.empty?
      raise ConfigurationError, "Invalid environment: #{environment}" unless ENVIRONMENTS.key?(environment)

      true
    end

    def reset!
      @client_id = nil
      @client_secret = nil
      @redirect_uri = nil
      @environment = :sandbox
      @scopes = DEFAULT_SCOPES.dup
      @timeout = 30
    end
  end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def reset_configuration!
      self.configuration = Configuration.new
    end
  end
end
