require 'routemaster/models/base'
require 'routemaster/models/event'
require 'routemaster/models/user'
require 'routemaster/models/message'
require 'routemaster/models/subscription'
require 'routemaster/services/codec'
require 'forwardable'

module Routemaster
  module Models
    class Topic < Base
      TopicClaimedError = Class.new(Exception)

      attr_reader :name, :publisher

      def initialize(name:, publisher:)
        @name      = Name.new(name)
        @publisher = Publisher.new(publisher) if publisher

        _redis.sadd('topics', name)

        return if publisher.nil?

        if _redis.hsetnx(_key, 'publisher', publisher)
          _log.info { "topic '#{@name}' claimed by '#{@publisher}'" }
        end

        current_publisher = _redis.hget(_key, 'publisher')
        unless _redis.hget(_key, 'publisher') == @publisher
          raise TopicClaimedError.new("topic claimed by #{current_publisher}")
        end
      end

      def destroy
        _redis.multi do |m|
          m.srem('topics', name)
          m.del(_key)
        end
      end

      def subscribers
        Subscription.where(topic: self).map(&:subscriber)
      end

      def ==(other)
        name == other.name
      end

      def self.all
        _redis.smembers('topics').map do |n|
          p = _redis.hget("topic:#{n}", 'publisher')
          new(name: n, publisher: p)
        end
      end

      def self.find(name)
        return unless _redis.sismember('topics', name)
        publisher = _redis.hget("topic:#{name}", 'publisher')
        new(name: name, publisher: publisher)
      end

      def get_count
        _redis.hget(_key, 'counter').to_i
      end

      def increment_count
        _redis.hincrby(_key, 'counter', 1)
      end

      def inspect
        "<#{self.class.name} name=#{@name}>"
      end

      private

      def _key
        @_key ||= "topic:#{@name}"
      end

      class Name < String
        def initialize(str)
          raise ArgumentError unless str.kind_of?(String)
          raise ArgumentError unless str =~ /^[a-z_]{1,64}$/
          super
        end
      end

      Publisher = Class.new(User)
    end
  end
end
