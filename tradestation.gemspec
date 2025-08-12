# frozen_string_literal: true

require_relative "lib/tradestation/version"

Gem::Specification.new do |spec|
  spec.name = "tradestation"
  spec.version = Tradestation::VERSION
  spec.authors = ["Ryan Hamamura"]
  spec.email = ["58859899+ryanhamamura@users.noreply.github.com"]

  spec.summary = "Ruby client for TradeStation API OAuth authentication and trading"
  spec.description = "A Ruby gem that provides OAuth 2.0 authentication and API client functionality for " \
    "TradeStation's trading platform. Supports both production and sandbox environments."
  spec.homepage = "https://github.com/ryanhamamura/tradestation"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ryanhamamura/tradestation"
  spec.metadata["changelog_uri"] = "https://github.com/ryanhamamura/tradestation/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?("bin/", "test/", "spec/", "features/", ".git", ".github", "appveyor", "Gemfile")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # OAuth and HTTP dependencies
  spec.add_dependency("faraday", "~> 2.0")
  spec.add_dependency("faraday-retry", "~> 2.0")
  spec.add_dependency("jwt", "~> 2.5")
  spec.add_dependency("oauth2", "~> 2.0")

  # Development dependencies
  spec.add_development_dependency("rspec", "~> 3.12")
  spec.add_development_dependency("rubocop", "~> 1.50")
  spec.add_development_dependency("rubocop-shopify", "~> 2.14")
  spec.add_development_dependency("vcr", "~> 6.1")
  spec.add_development_dependency("webmock", "~> 3.18")
  spec.add_development_dependency("yard", "~> 0.9")

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
