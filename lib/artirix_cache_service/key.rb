module ArtirixCacheService
  class Key
    KEY_SEPARATOR = '/'.freeze

    attr_reader :args, :service

    def initialize(given_args, service)
      @service = service
      @args    = clean_key_args given_args
    end

    delegate :key_prefix, :digest, :variable_get, to: :service

    def call
      clean_parts.join KEY_SEPARATOR
    end

    private

    def clean_parts
      parts.map(&:presence).compact.map(&:to_s)
    end

    def parts
      [key_prefix].concat(args)
    end

    def clean_key_args(args)
      args.map { |a| clean_arg a }.flatten
    end

    def clean_arg(arg)
      cache_key_from_model(arg) || cache_key_from_options(arg) || arg
    end

    def cache_key_from_model(model)
      model.try(:cache_key)
    end

    def cache_key_from_options(hash)
      return nil unless hash.kind_of? Hash

      parts = digest_hash_parts(hash).map(&:presence).compact

      case parts.size
      when 0
        nil
      when 1
        digest parts.first
      else
        digest parts
      end
    end

    def digest_hash_parts(hash)
      [
        hash[:digest],
        variables_hash(Array(hash[:variables])),
        request_list(hash[:request]),
      ]
    end

    def request_list(request)
      return nil unless request.present? && request.fullpath.present?

      [request.fullpath.parameterize, request.fullpath]
    end

    def variables_hash(variable_names)
      Hash[variable_names.map { |var| [var, variable_get(var)] }]
    end

  end
end