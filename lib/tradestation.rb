# frozen_string_literal: true

require_relative "tradestation/version"
require_relative "tradestation/errors"
require_relative "tradestation/configuration"
require_relative "tradestation/endpoints"

module Tradestation
  class Error < StandardError; end
end
