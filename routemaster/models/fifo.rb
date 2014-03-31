require 'routemaster/models/base'
require 'routemaster/models/event'

module Routemaster::Models
  class Fifo < Routemaster::Models::Base

    def initialize(name)
      @name = name
    end

    def push(event)
      conn.rpush(_key_events, event.dump)
      conn.publish(_key_channel, 'ping')
    end

    def peek
      raw_event = conn.lindex(_key_events, 0)
      return if raw_event.nil?
      Event.load(raw_event)
    end

    def pop
      raw_event = conn.lpop(_key_events)
      return if raw_event.nil?
      Event.load(raw_event)
    end

    private

    def _key
      @_key ||= "fifo/#{@name}"
    end

    def _key_events
      @_key_events ||= "#{_key}/events"
    end

    def _key_channel
      @_key_channel ||= "#{_key}/pubsub"
    end
  end
end

