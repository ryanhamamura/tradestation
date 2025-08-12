# Tasks for TradeStation OAuth 2.0 Authentication Client

## Relevant Files

- `lib/tradestation.rb` - Main module and autoloading
- `lib/tradestation/configuration.rb` - Configuration management for OAuth credentials
- `lib/tradestation/client.rb` - Main stateless OAuth client implementation
- `lib/tradestation/oauth2_client.rb` - Internal OAuth2 gem wrapper
- `lib/tradestation/token_response.rb` - Token value object with helper methods
- `lib/tradestation/errors.rb` - Custom exception classes
- `lib/tradestation/endpoints.rb` - API endpoint constants for environments
- `spec/tradestation/configuration_spec.rb` - Configuration tests
- `spec/tradestation/client_spec.rb` - Client tests
- `spec/tradestation/oauth2_client_spec.rb` - OAuth2 client tests
- `spec/tradestation/token_response_spec.rb` - Token object tests
- `spec/integration/oauth_flow_spec.rb` - Integration tests
- `spec/support/vcr.rb` - VCR configuration
- `tradestation.gemspec` - Update dependencies
- `README.md` - Documentation with examples
- `examples/basic_auth.rb` - Simple authentication example
- `examples/rails_example.rb` - Rails usage example (without special integration)

## Notes

- The gem will be stateless - consumers manage token storage
- Focus on core OAuth functionality first, no Rails-specific integration
- The oauth2 gem will be the primary dependency for OAuth functionality
- JWT gem needed for parsing ID tokens
- Tests should use VCR for recording API interactions with sandbox
- Client methods will accept tokens as parameters rather than storing them
- Use RSpec for all unit tests
- Provide clear examples for Rails usage without requiring special Rails integration

## Tasks

- [x] 1. Set up core gem structure and dependencies
  - [x] 1.1 Add oauth2, jwt, and faraday gems to gemspec with proper version constraints
  - [x] 1.2 Create lib/tradestation/errors.rb with custom exception classes (AuthenticationError, TokenExpiredError, ConfigurationError, ApiError)
  - [x] 1.3 Create lib/tradestation/configuration.rb with class-level configuration for client_id, client_secret, and environment
  - [x] 1.4 Create lib/tradestation/endpoints.rb with environment-specific URL constants (production/sandbox)
  - [x] 1.5 Update lib/tradestation.rb to require all new files and set up module structure
  - [x] 1.6 Write specs for configuration module in spec/tradestation/configuration_spec.rb

- [x] 2. Implement stateless OAuth2 client with authorization flow
  - [x] 2.1 Create lib/tradestation/client.rb as main public interface accepting configuration on initialization
  - [x] 2.2 Create lib/tradestation/oauth2_client.rb as internal wrapper around oauth2 gem with TradeStation endpoints
  - [x] 2.3 Implement authorization_url method that generates OAuth URL with state, scope, audience, and redirect_uri
  - [x] 2.4 Create exchange_code method that trades authorization code for tokens and returns TokenResponse object
  - [x] 2.5 Implement proper error handling wrapping OAuth2::Error into custom Tradestation exceptions
  - [x] 2.6 Add support for PKCE flow with code_challenge and code_verifier parameters
  - [x] 2.7 Write comprehensive specs in spec/tradestation/client_spec.rb with mocked OAuth2 responses

- [x] 3. Build token handling and refresh methods
  - [x] 3.1 Create lib/tradestation/token_response.rb value object to encapsulate access_token, refresh_token, expires_at, and id_token
  - [x] 3.2 Add helper methods to TokenResponse: expired?, expires_in, time_until_expiry, and to_h for serialization
  - [x] 3.3 Implement refresh_token method in client.rb that accepts refresh token and returns new TokenResponse
  - [x] 3.4 Add JWT parsing for id_token to extract user claims and profile information
  - [x] 3.5 Create token_expired? helper method in client that accepts expires_at timestamp
  - [x] 3.6 Write specs for TokenResponse and token refresh logic in spec/tradestation/token_response_spec.rb

- [ ] 4. Add API request capabilities
  - [ ] 4.1 Implement authenticated_request method in client.rb that accepts token and makes API calls
  - [ ] 4.2 Add convenience methods for common endpoints (get_accounts, get_user_info) that accept tokens
  - [ ] 4.3 Implement automatic retry logic for failed requests (with exponential backoff)
  - [ ] 4.4 Add request/response logging capability (optional, configurable)
  - [ ] 4.5 Write specs for API request methods with mocked responses

- [ ] 5. Create comprehensive testing and documentation
  - [ ] 5.1 Set up VCR for recording API interactions with TradeStation sandbox in spec/support/vcr.rb
  - [ ] 5.2 Create integration tests for complete OAuth flow in spec/integration/oauth_flow_spec.rb
  - [ ] 5.3 Write detailed README.md with quick start, configuration, and usage examples
  - [ ] 5.4 Create examples/basic_auth.rb showing simple authentication flow
  - [ ] 5.5 Create examples/rails_example.rb showing Rails controller implementation
  - [ ] 5.6 Add YARD documentation to all public methods with examples
  - [ ] 5.7 Create CHANGELOG.md to track version changes