# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
  add_group "Client", "lib/tradestation/client"
  add_group "OAuth", "lib/tradestation/oauth"
  add_group "Errors", "lib/tradestation/errors"
  add_group "Models", ["lib/tradestation/token_response", "lib/tradestation/configuration"]
end

require "tradestation"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end
end
