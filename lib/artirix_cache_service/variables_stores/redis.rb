module ArtirixCacheService
  module VariablesStores
    class Redis < Base

      EMPTY_STRING = ''.freeze
      WILDCARD     = '*'.freeze

      attr_reader :redis_variable_prefix, :redis_client

      def type
        :redis
      end

      def initialize(redis_variable_prefix:, redis_client:, redis_options: {})
        @redis_variable_prefix = redis_variable_prefix
        @redis_options         = redis_options
        @redis_client          = redis_client
      end

      def variables
        list.map { |key| clean_listed_variable key }
      end

      private

      def list
        redis_client.keys(complete_key(WILDCARD))
      end

      def retrieve(key)
        redis_client.get(complete_key(key))
      end

      def store(key, value)
        redis_client.set(complete_key(key), value)
      end

      def complete_key(key)
        "#{redis_variable_prefix}_#{key}"
      end

      def clean_listed_variable(key)
        key.sub clean_listed_regex, EMPTY_STRING
      end

      def clean_listed_regex
        @clean_listed_regex ||= /^#{redis_variable_prefix}_/
      end

    end
  end
end