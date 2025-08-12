# Documentation Best Practices for Ruby Gems

## YARD Documentation Standards

### 1. Class Documentation
```ruby
# Client for interacting with the TradeStation API
# 
# @example Creating a client with configuration
#   client = Tradestation::Client.new(
#     client_id: "your_client_id",
#     client_secret: "your_secret",
#     redirect_uri: "http://localhost:3000/callback"
#   )
#
# @example Using global configuration
#   Tradestation.configure do |config|
#     config.client_id = "your_client_id"
#   end
#   client = Tradestation::Client.new
#
# @see https://api.tradestation.com/docs Documentation
class Client
  # ...
end
```

### 2. Method Documentation Template
```ruby
# Short description of what the method does
#
# Longer description if needed, explaining important details,
# edge cases, or implementation notes.
#
# @param access_token [String] OAuth access token for authentication
# @param account_ids [String, Array<String>] Single account ID or array of IDs
# @param options [Hash] Optional parameters
# @option options [Integer] :limit Maximum number of results (default: 100)
# @option options [String] :since Date filter in ISO8601 format
#
# @return [Hash] Response from the API containing account data
# @return [nil] if no data is found
#
# @raise [ArgumentError] if required parameters are missing
# @raise [AuthenticationError] if the token is invalid or expired
# @raise [ApiError] if the API returns an error response
#
# @example Get balances for a single account
#   balances = client.get_account_balances(
#     access_token: token,
#     account_ids: "12345"
#   )
#
# @example Get balances for multiple accounts
#   balances = client.get_account_balances(
#     access_token: token,
#     account_ids: ["12345", "67890"]
#   )
#
# @see https://api.tradestation.com/docs/api#get-account-balances API Documentation
# @since 0.2.0
# @deprecated Use {#get_balances_v2} instead (optional, only if deprecated)
def get_account_balances(access_token:, account_ids:, **options)
  # implementation
end
```

### 3. Common YARD Tags

#### Essential Tags:
- `@param` - Document each parameter
- `@return` - Document return value(s)
- `@raise` - Document exceptions that might be raised
- `@example` - Provide usage examples

#### Additional Useful Tags:
- `@see` - Link to related documentation
- `@since` - Version when method was added
- `@deprecated` - Mark deprecated methods
- `@note` - Important notes or warnings
- `@todo` - Document planned improvements
- `@api private` - Mark internal methods
- `@api public` - Explicitly mark public API

### 4. Type Specifications

YARD supports type annotations:
- `[String]` - Single type
- `[String, nil]` - Multiple possible types
- `[Array<String>]` - Array of specific type
- `[Hash{Symbol => String}]` - Hash with specific key/value types
- `[#to_s]` - Duck typing (any object responding to #to_s)

### 5. Best Practices

1. **Every public method should be documented**
2. **Include at least one @example for complex methods**
3. **Document all parameters, even optional ones**
4. **Be specific about return types**
5. **Document all exceptions that users might encounter**
6. **Use @api private for internal methods**
7. **Keep descriptions concise but complete**
8. **Link to external documentation when relevant**

### 6. Generating Documentation

```bash
# Generate HTML documentation
bundle exec yard doc

# Generate with statistics
bundle exec yard stats

# Serve documentation locally
bundle exec yard server

# Check documentation coverage
bundle exec yard stats --list-undoc
```

### 7. Configuration (.yardopts file)

Create a `.yardopts` file in the root:
```
--markup markdown
--title "TradeStation Ruby SDK"
--charset utf-8
--no-private
--embed-mixins
--output-dir ./doc
--readme README.md
-
CHANGELOG.md
LICENSE.txt
```

### 8. Example: Documenting the Client Class

```ruby
module Tradestation
  # Client for interacting with the TradeStation API
  #
  # This client provides methods for OAuth authentication and making
  # authenticated requests to the TradeStation API endpoints.
  #
  # @example Basic usage
  #   client = Tradestation::Client.new(
  #     client_id: ENV['TRADESTATION_CLIENT_ID'],
  #     client_secret: ENV['TRADESTATION_CLIENT_SECRET'],
  #     redirect_uri: 'http://localhost:3000/callback',
  #     environment: :sandbox
  #   )
  #
  #   # Get authorization URL
  #   auth = client.authorization_url
  #   redirect_to auth[:url]
  #
  #   # Exchange code for token
  #   token = client.exchange_code_for_token(
  #     code: params[:code],
  #     code_verifier: session[:code_verifier]
  #   )
  #
  # @see https://api.tradestation.com/docs TradeStation API Documentation
  # @since 0.1.0
  class Client
    # @return [Configuration] the client's configuration
    attr_reader :configuration

    # Initialize a new TradeStation API client
    #
    # @param config [Configuration, Hash, nil] Configuration object, hash, or nil to use global config
    # @option config [String] :client_id OAuth client ID (required)
    # @option config [String] :client_secret OAuth client secret (required)
    # @option config [String] :redirect_uri OAuth redirect URI (required)
    # @option config [Symbol] :environment (:sandbox or :production, default: :sandbox)
    # @option config [Array<String>] :scopes OAuth scopes (default: ['openid', 'offline_access'])
    #
    # @raise [ConfigurationError] if required configuration is missing
    # @raise [ArgumentError] if config is not a valid type
    #
    # @example Initialize with hash
    #   client = Tradestation::Client.new(
    #     client_id: "abc123",
    #     client_secret: "secret",
    #     redirect_uri: "http://localhost:3000"
    #   )
    #
    # @example Initialize with Configuration object
    #   config = Tradestation::Configuration.new
    #   config.client_id = "abc123"
    #   client = Tradestation::Client.new(config)
    def initialize(config = nil)
      # ...
    end
  end
end
```

### 9. RubyDoc.info Integration

When you push to RubyGems, your documentation will automatically appear on RubyDoc.info if you:

1. Have proper YARD documentation
2. Include the `yard` gem as a development dependency
3. Don't have a `.document` file that excludes files

### 10. Documentation Coverage Goals

Aim for:
- 100% documentation of public methods
- At least one example per public method
- All parameters documented with types
- All return values documented
- All exceptions documented

Check coverage with:
```bash
bundle exec yard stats --list-undoc
```