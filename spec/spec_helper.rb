# frozen_string_literal: true

require "pretty_rspec"
require "rspec/expectations"
require "rspec/mocks"

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
