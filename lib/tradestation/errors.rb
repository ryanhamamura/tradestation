# frozen_string_literal: true

module Tradestation
  class Error < StandardError; end

  class AuthenticationError < Error
    attr_reader :error_code, :error_description

    def initialize(message = nil, error_code: nil, error_description: nil)
      super(message || error_description || "Authentication failed")
      @error_code = error_code
      @error_description = error_description
    end
  end

  class TokenExpiredError < Error
    def initialize(message = nil)
      super(message || "Token has expired")
    end
  end

  class ConfigurationError < Error
    def initialize(message = nil)
      super(message || "Invalid configuration")
    end
  end

  class ApiError < Error
    attr_reader :status_code, :response_body

    def initialize(message = nil, status_code: nil, response_body: nil)
      super(message || "API request failed")
      @status_code = status_code
      @response_body = response_body
    end
  end
end
