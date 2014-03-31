require 'routemaster/models/base'
require 'routemaster/models/event'
require 'routemaster/models/user'
require 'routemaster/models/subscribers'
require 'routemaster/models/fifo'

module Routemaster::Models
  class Topic < Routemaster::Models::Base
    TopicClaimedError = Class.new(Exception)

    attr_reader :name, :publisher

    def initialize(name:, publisher:)
      @name = Name.new(name)
      conn.sadd('topics', name)

      return if publisher.nil?

      @publisher = Publisher.new(publisher) if publisher
      conn.hsetnx(_key, 'publisher', publisher)

      current_publisher = conn.hget(_key, 'publisher')
      unless conn.hget(_key, 'publisher') == @publisher
        raise TopicClaimedError.new("topic claimed by #{current_publisher}")
      end
    end

    def subscribers
      @_subscribers ||= Subscribers.new(self)
    end

    def fifo
      @_fifo ||= Fifo.new("topic-#{name}")
    end

    def ==(other)
      name == other.name
    end

    def self.all
      conn.smembers('topics').map do |n|
        p = conn.hget("topic/#{n}", 'publisher')
        new(name: n, publisher: p)
      end
    end

    def self.find(name)
      new(name: name, publisher: nil)
    end

    private

    def _key
      @_key ||= "topic/#{@name}"
    end

    class Name < String
      def initialize(str)
        raise ArgumentError unless str.kind_of?(String)
        raise ArgumentError unless str =~ /[a-z_]{1,32}/
        super
      end
    end

    Publisher = Class.new(User)
  end
end
