require 'active_support/all'
require 'redis'
require 'artirix_cache_service/version'
require 'artirix_cache_service/view_helper'
require 'artirix_cache_service/key'
require 'artirix_cache_service/options_service'
require 'artirix_cache_service/variables_store_service'
require 'artirix_cache_service/variables_stores/base'
require 'artirix_cache_service/variables_stores/internal'
require 'artirix_cache_service/variables_stores/redis'
require 'artirix_cache_service/service'

module ArtirixCacheService

  # Delegation of static methods to the Service instance
  class << self
    delegate :key, :digest,
             :register_key_prefix, :key_prefix,
             :default_options, :register_default_options,
             :register_options, :registered_options,
             :registered_options?, :registered_options, :options,
             :variables_store, :register_variables_store, :reload_variables_store,
             :redis_options, :redis_options=,
             :redis_variable_prefix, :redis_variable_prefix=,
             :variable_set, :variable_get, :variables,
             to: :service
  end

  def self.view_helper
    ViewHelper
  end

  def self.service
    @service ||= reload_service
  end

  def self.reload_service
    @service = Service.new
  end

end
