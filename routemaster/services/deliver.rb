require 'routemaster/services'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'config/openssl'
require 'faraday'
require 'json'

module Routemaster
  module Services
    # Manage delivery buffer and emitting the HTTP delivery
    class Deliver
      include Mixins::Log
      include Mixins::LogException

      CantDeliver = Class.new(Exception)

      def initialize(subscription, events)
        @subscription = subscription
        @buffer       = events
      end

      def run
        return false unless @buffer.any?
        return false unless _should_deliver?(@buffer)
        _log.debug { "starting delivery to '#{@subscription.subscriber}'" }


        # assemble data
        data = @buffer.map do |event|
          {
            topic: event.topic,
            type:  event.type,
            url:   event.url,
            t:     event.timestamp
          }
        end

        # send data
        begin
          response = _conn.post do |post|
            post.headers['Content-Type'] = 'application/json'
            post.body = data.to_json
          end
        rescue Faraday::Error::ClientError => e
          raise CantDeliver.new("delivery failure (#{e.class.name}: #{e.message})")
        end

        if response.success?
          _log.debug { "delivered #{@buffer.length} events to '#{@subscription.subscriber}'" }
          return true
        end

        _log.warn { "failed to deliver #{@buffer.length} events to '#{@subscription.subscriber}'" }
        raise CantDeliver.new("delivery failure (HTTP #{response.status})")
      end


      private


      def _should_deliver?(buffer)
        return true  if buffer.first.timestamp + @subscription.timeout <= Routemaster.now
        return false if buffer.length == 0
        return true  if buffer.length >= @subscription.max_events
        false
      end


      def _conn
        @_conn ||= Faraday.new(@subscription.callback) do |c|
          c.adapter Faraday.default_adapter
          c.basic_auth(@subscription.uuid, 'x')
        end
      end
    end
  end
end
