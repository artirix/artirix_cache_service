module ArtirixCacheService
  module ViewHelper

    def artirix_cache(key_prefix, options_name = [], *key_params, &block)
      raise ArgumentError, 'key_prefix is required' unless key_prefix.present?

      options = ArtirixCacheService.options *Array(options_name),
                                            return_if_missing: :default

      # if `disable_cache` in the options -> yield without caching
      if options[:disable_cache]
        yield
      else
        key = ArtirixCacheService.key key_prefix, *key_params
        cache(key, options, &block)
      end
    end
  end
end