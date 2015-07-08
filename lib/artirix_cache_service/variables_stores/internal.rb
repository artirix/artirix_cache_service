module ArtirixCacheService
  module VariablesStores
    class Internal
      def type
        :internal
      end

      def variable_get(given_key, &block)
        key = given_key.to_sym
        value   = retrieve(key)

        if value
          value
        elsif block_given?
          store key, block.call
        else
          nil
        end
      end

      def variable_set(key, value)
        store key.to_sym, value
        self
      end

      private

      def retrieve(key)
        map[key]
      end

      def store(key, value)
        map[key] = value
      end

      def map
        @map ||= {}
      end
    end
  end
end