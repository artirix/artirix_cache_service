module ArtirixCacheService
  class VariablesStoreService
    DEFAULT_PREFIX = 'artirix_cache_service'.freeze

    attr_writer :redis_options
    attr_writer :redis_variable_prefix

    def redis_options
      @redis_options ||= {}
    end

    def redis_variable_prefix
      @redis_variable_prefix ||= DEFAULT_PREFIX
    end

    def register_variables_store(type, force: false)
      @variables_store = build_by_type type, force
    end

    def reload_variables_store
      register_variables_store type, force: true
    end

    def variables_store
      @variables_store ||= build_internal
    end

    delegate :variable_get, :variable_set, :type, to: :variables_store

    private

    def build_by_type(type, force = false)
      case type
      when :internal
        build_internal force
      when :redis
        build_redis force
      else
        raise ArgumentError, 'type not recognized'
      end
    end

    def build_internal(force = false)
      return @variables_store if !force && @variables_store.kind_of?(VariablesStores::Internal)
      VariablesStores::Internal.new
    end

    def build_redis(force = false)
      return @variables_store if !force && @variables_store.kind_of?(VariablesStores::Redis)
      VariablesStores::Redis.new redis_variable_prefix, redis_options
    end
  end
end