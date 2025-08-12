# frozen_string_literal: true

require_relative "tradestation/version"
require_relative "tradestation/errors"
require_relative "tradestation/configuration"
require_relative "tradestation/endpoints"
require_relative "tradestation/oauth2_client"
require_relative "tradestation/token_response"
require_relative "tradestation/client"

# Ruby client library for the TradeStation API
#
# This gem provides OAuth 2.0 authentication and API access to TradeStation's
# trading platform. It supports both sandbox and production environments.
#
# @example Basic configuration and usage
#   Tradestation.configure do |config|
#     config.client_id = ENV['TRADESTATION_CLIENT_ID']
#     config.client_secret = ENV['TRADESTATION_CLIENT_SECRET']
#     config.redirect_uri = 'http://localhost:3000/callback'
#     config.environment = :sandbox
#   end
#
#   client = Tradestation::Client.new
#   auth = client.authorization_url
#   # Redirect user to auth[:url]
#
# @see https://api.tradestation.com/docs TradeStation API Documentation
# @since 0.1.0
module Tradestation
  # Base error class for all TradeStation gem errors
  class Error < StandardError; end
end
