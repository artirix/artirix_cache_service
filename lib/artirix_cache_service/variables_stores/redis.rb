module ArtirixCacheService
  module VariablesStores
    class Redis < Base

      attr_reader :redis_variable_prefix

      def type
        :redis
      end

      def initialize(redis_variable_prefix, redis_options = {})
        @redis_variable_prefix = redis_variable_prefix
        @redis_options         = redis_options
      end

      private

      def retrieve(key)
        redis.get(complete_key(key))
      end

      def store(key, value)
        redis.set(complete_key(key), value)
      end

      def complete_key(key)
        "#{redis_variable_prefix}_#{key}"
      end

      def redis
        @redis ||= ::Redis.new @redis_options
      end
    end
  end
end