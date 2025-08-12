# TradeStation Ruby Client

A Ruby gem for OAuth 2.0 authentication and API access to TradeStation's trading platform. This gem provides a clean, idiomatic Ruby interface for TradeStation's v3 API with full PKCE support for enhanced security.

## Features

- 🔐 **OAuth 2.0 Authentication** with PKCE support
- 📊 **Complete API Coverage** for trading operations
- 🏭 **Environment Support** for both production and sandbox
- 🔄 **Token Management** with automatic refresh capabilities
- 📝 **Comprehensive Documentation** with YARD
- ✅ **96% Test Coverage** with RSpec
- 🎨 **Shopify Ruby Style Guide** compliant

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tradestation'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install tradestation
```

## Quick Start

### Configuration

```ruby
require 'tradestation'

# Configure globally
Tradestation.configure do |config|
  config.client_id = ENV['TRADESTATION_CLIENT_ID']
  config.client_secret = ENV['TRADESTATION_CLIENT_SECRET']
  config.redirect_uri = 'http://localhost:3000/callback'
  config.environment = :sandbox # or :production
  config.scopes = ['openid', 'profile', 'MarketData', 'ReadAccount', 'Trade']
end

# Or configure per-client
client = Tradestation::Client.new(
  client_id: 'your_client_id',
  client_secret: 'your_client_secret',
  redirect_uri: 'http://localhost:3000/callback'
)
```

### OAuth Flow

```ruby
# Step 1: Generate authorization URL with PKCE
auth = client.authorization_url
# Save the code_verifier in session/secure storage
session[:code_verifier] = auth[:code_verifier]
redirect_to auth[:url]

# Step 2: Exchange authorization code for token
token = client.exchange_code_for_token(
  code: params[:code],
  code_verifier: session[:code_verifier]
)

# Step 3: Store tokens securely
session[:access_token] = token.access_token
session[:refresh_token] = token.refresh_token
session[:expires_at] = token.expires_at
```

### Making API Requests

```ruby
# Get accounts
accounts = client.get_accounts(access_token: token.access_token)

# Get account balances
balances = client.get_account_balances(
  access_token: token.access_token,
  account_ids: ['123456', '789012']
)

# Get positions
positions = client.get_positions(
  access_token: token.access_token,
  account_ids: '123456'
)

# Get market quotes
quotes = client.get_quotes(
  access_token: token.access_token,
  symbols: ['AAPL', 'GOOGL', 'MSFT']
)
```

### Order Management

```ruby
# Confirm order (get estimates)
confirmation = client.confirm_order(
  access_token: token.access_token,
  order: {
    AccountID: '123456',
    Symbol: 'AAPL',
    Quantity: '10',
    OrderType: 'Market',
    TradeAction: 'BUY',
    TimeInForce: { Duration: 'DAY' },
    Route: 'Intelligent'
  }
)

# Place order
response = client.place_order(
  access_token: token.access_token,
  order: {
    AccountID: '123456',
    Symbol: 'AAPL',
    Quantity: '10',
    OrderType: 'Limit',
    LimitPrice: '150.00',
    TradeAction: 'BUY',
    TimeInForce: { Duration: 'DAY' },
    Route: 'Intelligent'
  }
)

# Cancel order
client.cancel_order(
  access_token: token.access_token,
  order_id: response['OrderID']
)
```

### Token Management

```ruby
# Check if token is expired
if client.token_expired?(token.expires_at)
  # Refresh the token
  new_token = client.refresh_token(
    refresh_token: session[:refresh_token]
  )
  session[:access_token] = new_token.access_token
  session[:expires_at] = new_token.expires_at
end

# Proactive refresh (5 minutes before expiry)
if client.token_expires_soon?(token.expires_at, 300)
  # Refresh token...
end
```

## Available Methods

### Authentication
- `authorization_url` - Generate OAuth authorization URL with PKCE
- `exchange_code_for_token` - Exchange authorization code for access token
- `refresh_token` - Refresh an expired access token
- `token_expired?` - Check if token has expired
- `token_expires_soon?` - Check if token expires soon

### Account Management
- `get_accounts` - Get all brokerage accounts
- `get_account_balances` - Get account balances
- `get_positions` - Get account positions

### Order Management
- `get_orders` - Get today's and open orders
- `get_historical_orders` - Get historical orders
- `confirm_order` - Get order cost and commission estimates
- `place_order` - Place a new order
- `replace_order` - Replace an existing order
- `cancel_order` - Cancel an order

### Market Data
- `get_quotes` - Get real-time market quotes

### Generic Request
- `authenticated_request` - Make any authenticated API request

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Running Tests

```bash
# Run all tests
bundle exec rake

# Run tests only
bundle exec rspec

# Run with coverage report
bundle exec rspec --format documentation

# Run RuboCop
bundle exec rubocop
```

### Documentation

```bash
# Generate YARD documentation
bundle exec yard

# View documentation locally
bundle exec yard server
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ryanhamamura/tradestation. This project follows the [Shopify Ruby Style Guide](https://ruby-style-guide.shopify.dev/).

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Disclaimer

This gem is not affiliated with, endorsed by, or sponsored by TradeStation Group, Inc. or any of its affiliates. TradeStation® is a registered trademark of TradeStation Group, Inc.

Always ensure you comply with TradeStation's API terms of service and implement appropriate risk management in your trading applications.