require 'active_support/all'
require 'artirix_cache_service/version'
require 'artirix_cache_service/key'
require 'artirix_cache_service/service'

module ArtirixCacheService

  # Delegation of static methods to the Service instance
  class << self
    delegate :key, :config_params, :key_prefix, :digest, to: :service
  end

  def self.service
    @service ||= reload_service
  end

  def self.reload_service
    @service = Service.new
  end

end
