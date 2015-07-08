require 'active_support/all'
require 'artirix_cache_service/version'
require 'artirix_cache_service/key'
require 'artirix_cache_service/options_service'
require 'artirix_cache_service/variables_store_service'
require 'artirix_cache_service/variables_stores/internal'
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
             :variables_store, :register_variables_store,
             :variable_set, :variable_get,
             to: :service
  end

  def self.service
    @service ||= reload_service
  end

  def self.reload_service
    @service = Service.new
  end

end
