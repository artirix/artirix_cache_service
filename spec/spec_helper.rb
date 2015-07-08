$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'bundler/setup'
Bundler.setup

require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'pry'
require 'artirix_cache_service'

def view_instance_with_helper(view_helper)
  klass = Class.new do
    include view_helper

    def cache(_key, _options = {}, &block)
      yield
    end
  end

  klass.new
end

RSpec.configure do |config|
  # some (optional) config here
end