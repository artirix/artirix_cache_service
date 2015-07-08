module ArtirixCacheService
  class VariablesStoreService

    def register_variables_store(type)
      @variable_store = build_by_type type
    end

    def variables_store
      @variables_store ||= build_internal
    end

    delegate :variable_get, :variable_set, to: :variables_store

    private

    def build_by_type(type)
      case type
      when :internal
        build_internal
      else
        raise ArgumentError, 'type not recognized'
      end
    end

    def build_internal
      if @variable_store.kind_of? VariablesStores::Internal
        @variable_store
      else
        VariablesStores::Internal.new
      end
    end
  end
end