require 'active_support/all'
require 'artirix_cache_service/version'
require 'artirix_cache_service/key'
require 'artirix_cache_service/service'

module ArtirixCacheService

  # Delegation of static methods to the Service instance
  class << self
    delegate :key, :digest,
             :register_key_prefix, :key_prefix,
             :default_options, :register_default_options,
             :register_options, :registered_options,
             :registered_options?, :registered_options,
             :options,
             to: :service
  end

  def self.service
    @service ||= reload_service
  end

  def self.reload_service
    @service = Service.new
  end

end
