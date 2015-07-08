module ArtirixCacheService
  class Service
    # Instance
    def config_params
      @config_params ||= { key_prefix: nil }
    end

    def key_prefix
      config_params[:key_prefix]
    end

    def key(*given_args)
      Key.new(given_args, self).call
    end

    def digest(arg)
      Digest::SHA1.hexdigest arg.to_s
    end
  end
end