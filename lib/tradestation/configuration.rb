# frozen_string_literal: true

module Tradestation
  # Configuration class for TradeStation API client
  #
  # Holds all configuration options needed for OAuth authentication and API access.
  # Can be configured globally or per-client instance.
  #
  # @example Global configuration
  #   Tradestation.configure do |config|
  #     config.client_id = "your_client_id"
  #     config.client_secret = "your_secret"
  #     config.redirect_uri = "http://localhost:3000/callback"
  #     config.environment = :sandbox
  #   end
  #
  # @example Instance configuration
  #   config = Tradestation::Configuration.new
  #   config.client_id = "your_client_id"
  #   client = Tradestation::Client.new(config)
  class Configuration
    # @return [String] OAuth client ID from TradeStation
    attr_accessor :client_id

    # @return [String] OAuth client secret from TradeStation
    attr_accessor :client_secret

    # @return [String] OAuth redirect URI (must match TradeStation app settings)
    attr_accessor :redirect_uri

    # @return [Symbol] Environment to use (:production or :sandbox)
    attr_accessor :environment

    # @return [Array<String>] OAuth scopes to request
    attr_accessor :scopes

    # @return [Integer] HTTP request timeout in seconds
    attr_accessor :timeout

    # Available TradeStation environments
    ENVIRONMENTS = {
      production: "https://api.tradestation.com",
      sandbox: "https://sim-api.tradestation.com",
    }.freeze

    # Default OAuth scopes for authentication
    DEFAULT_SCOPES = ["openid", "profile"].freeze

    # Initialize a new Configuration with default values
    #
    # @return [Configuration] a new configuration instance
    def initialize
      @environment = :sandbox
      @scopes = DEFAULT_SCOPES.dup
      @timeout = 30
    end

    # Get the OAuth authorization URL for the configured environment
    #
    # @return [String] the authorization endpoint URL
    def auth_url
      "#{base_url}/authorize"
    end

    # Get the OAuth token URL for the configured environment
    #
    # @return [String] the token endpoint URL
    def token_url
      "#{base_url}/token"
    end

    # Get the API base URL for the configured environment
    #
    # @return [String] the API base URL
    def api_url
      base_url
    end

    # Get the base URL for the configured environment
    #
    # @return [String] the base URL
    # @raise [ConfigurationError] if the environment is invalid
    def base_url
      ENVIRONMENTS[environment] || raise(ConfigurationError, "Invalid environment: #{environment}")
    end

    # Validate that all required configuration options are set
    #
    # @return [true] if configuration is valid
    # @raise [ConfigurationError] if any required option is missing or invalid
    def validate!
      raise ConfigurationError, "client_id is required" if client_id.nil? || client_id.empty?
      raise ConfigurationError, "client_secret is required" if client_secret.nil? || client_secret.empty?
      raise ConfigurationError, "redirect_uri is required" if redirect_uri.nil? || redirect_uri.empty?
      raise ConfigurationError, "Invalid environment: #{environment}" unless ENVIRONMENTS.key?(environment)

      true
    end

    # Reset configuration to default values
    #
    # @return [void]
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
    # @return [Configuration] the global configuration instance
    attr_accessor :configuration

    # Configure the TradeStation gem globally
    #
    # @yield [Configuration] yields the configuration instance for setting options
    # @return [Configuration] the configuration instance
    #
    # @example
    #   Tradestation.configure do |config|
    #     config.client_id = "your_client_id"
    #     config.client_secret = "your_secret"
    #   end
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Reset the global configuration to default values
    #
    # @return [Configuration] a new configuration instance with defaults
    def reset_configuration!
      self.configuration = Configuration.new
    end
  end
end
