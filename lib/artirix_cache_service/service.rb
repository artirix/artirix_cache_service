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

    def default_options
      @default_options ||= {}
    end

    def register_default_options(default_options)
      @default_options = Hash(default_options)
      self
    end

    def register_options(name, options)
      raise ArgumentError if name.blank?
      options_map[name.to_sym] = Hash(options)
      self
    end

    def registered_options(name)
      return nil unless name.present?
      options_map[name.to_sym]
    end

    def registered_options?(name)
      !registered_options(name).nil?
    end

    def options(*names, return_if_missing: :empty)
      name = names.detect { |name| registered_options? name }
      if name.present?
        get_options(name)
      else
        missing_options(return_if_missing)
      end
    end

    private

    def missing_options(return_if_missing)
      case return_if_missing
      when :default
        default_options.dup
      when :nil, nil
        nil
      else
        {}
      end
    end

    def get_options(name)
      default_options.merge registered_options(name)
    end

    def options_map
      @options_map ||= {}
    end

  end
end