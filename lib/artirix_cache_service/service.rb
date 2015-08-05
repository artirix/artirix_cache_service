module ArtirixCacheService
  class Service
    def register_key_prefix(key_prefix)
      @key_prefix = key_prefix
      self
    end

    def key_prefix
      @key_prefix
    end

    def key(*given_args)
      Key.new(given_args, self).call
    end

    def digest(arg)
      Digest::SHA1.hexdigest arg.to_s
    end

    delegate :default_options, :register_default_options,
             :register_options, :registered_options,
             :registered_options?, :options,
             to: :options_service

    delegate :register_variables_store, :variables_store, :reload_variables_store,
             :redis_options, :redis_options=,
             :redis_variable_prefix, :redis_variable_prefix=,
             :variable_get, :variable_set, :variables,
             to: :variables_store_service

    private

    def options_service
      @options_service ||= OptionsService.new
    end

    def variables_store_service
      @variables_store_service ||= VariablesStoreService.new
    end
  end
end