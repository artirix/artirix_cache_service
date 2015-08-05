module ArtirixCacheService
  module VariablesStores
    class Internal < Base
      def type
        :internal
      end

      def variables
        map.keys.map &:to_s
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