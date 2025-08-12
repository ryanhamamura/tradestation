require 'oauth2'

begin
  client = OAuth2::Client.new('test', 'test', site: 'https://example.com')
  token = OAuth2::AccessToken.new(client, nil, refresh_token: 'test')
  
  # Mock a failed response
  response = double('response', status: 400, body: '{"error":"invalid_grant","error_description":"Token expired"}')
  error = OAuth2::Error.new(response)
  
  puts "Error class: #{error.class}"
  puts "Error message: #{error.message}"
  puts "Error code: #{error.code if error.respond_to?(:code)}"
  puts "Error description: #{error.description if error.respond_to?(:description)}"
rescue => e
  puts "Exception: #{e.message}"
end
