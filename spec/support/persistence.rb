require 'routemaster/mixins/redis'
require 'singleton'
require 'faraday'
require 'rspec'
require 'uri'

class RedisCleaner
  include Singleton
  include Routemaster::Mixins::Redis

  def clean!
    _redis.flushdb
  end
end

RSpec.configure do |config|
  config.before(:each) do
    RedisCleaner.instance.clean!
    extend Routemaster::Mixins::Redis
  end
end
