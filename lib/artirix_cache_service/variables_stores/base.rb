module ArtirixCacheService
  module VariablesStores
    class Base

      def variables
        raise 'abstract method not overridden'
      end

      def variable_get(given_key, &block)
        key = given_key.to_sym
        val = retrieve(key).presence
        return val.to_s if val
        return nil unless block_given?

        val = block.call
        store key, val
        val.presence && val.to_s
      end

      def variable_set(key, value)
        store key.to_sym, value
        self
      end
    end
  end
end