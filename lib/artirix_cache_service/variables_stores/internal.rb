module ArtirixCacheService
  module VariablesStores
    class Internal < Base
      def type
        :internal
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