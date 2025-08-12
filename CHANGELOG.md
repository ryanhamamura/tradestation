# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2025-08-12

### Added
- Comprehensive authenticated request support with `authenticated_request` method
- Convenience methods for common TradeStation API operations:
  - `get_accounts` - Fetch account list
  - `get_account_balances` - Get balances for single or multiple accounts
  - `get_positions` - Get positions for accounts
  - `get_orders` - Get today's and open orders
  - `get_historical_orders` - Get historical orders with date filter
  - `confirm_order` - Get cost and commission estimates
  - `place_order` - Place new orders
  - `replace_order` - Replace existing orders
  - `cancel_order` - Cancel orders
  - `get_quotes` - Get market quotes for symbols
- Support for multiple account IDs in account-related endpoints
- PKCE (Proof Key for Code Exchange) support for enhanced OAuth security
- Token expiry checking with `token_expired?` and `token_expires_soon?` methods
- Support for various timestamp formats (Time, Integer, Float, String) in token expiry methods
- SimpleCov test coverage reporting (96% coverage achieved)
- Complete YARD documentation for all public methods and classes
- Adopted Shopify Ruby Style Guide via rubocop-shopify gem

### Changed
- Refactored API versioning to use v3 API exclusively
- Improved error handling with specific error classes
- Enhanced test suite with comprehensive coverage
- All API requests now use `/v3` prefix consistently
- YARD documentation examples updated to match OpenAPI specification field names (PascalCase)
- TimeInForce parameter corrected to be an object with Duration key
- Code style refactored to comply with Shopify's Ruby style guide
- Class method definitions now use `class << self` syntax

### Removed
- v2 API support (not needed for current TradeStation API)
- `suggest_symbols` method (v2-only endpoint)
- `get_user_info` method (no clear user endpoint in TradeStation API)
- Retry logic temporarily removed (to be reimplemented properly later)

### Fixed
- WebMock test stubs now properly include Content-Type headers for JSON responses
- API endpoint paths corrected to match official TradeStation documentation
- Account endpoints now properly support comma-separated account IDs
- Documentation examples now use correct PascalCase field names per API spec

## [0.1.0] - 2024-01-01

### Added
- Initial gem structure and configuration
- OAuth 2.0 authentication flow with TradeStation
- Support for production and sandbox environments
- Basic client configuration with required OAuth parameters
- Token refresh functionality
- Error handling for authentication failures