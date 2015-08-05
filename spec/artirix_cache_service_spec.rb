require 'spec_helper'
require 'ostruct'
require 'faker'
require 'redis'
require 'fake_redis'

describe ArtirixCacheService do
  it 'has a version number' do
    expect(ArtirixCacheService::VERSION).not_to be nil
  end

  before(:each) do
    described_class.reload_service
  end

  let(:prefix) { 'my_prefix' }

  context 'key_prefix' do
    let(:default_key_prefix) { nil }

    describe '.key_prefix' do
      it 'returns the current key prefix to be used (empty by default)' do
        expect(described_class.key_prefix).to eq default_key_prefix
      end
    end

    describe '.register_key_prefix' do
      it 'allows us to modify it' do
        expect(described_class.key_prefix).to eq default_key_prefix
        described_class.register_key_prefix prefix
        expect(described_class.key_prefix).to eq prefix
      end
    end
  end

  describe '.digest' do
    let(:arg1) { { a: 1, b: 2 } }
    let(:arg2) { [1, 2, 3] }

    it 'returns the digest of the given argument (using SHA1)' do
      expect(described_class.digest arg1).to eq Digest::SHA1.hexdigest(arg1.to_s)
      expect(described_class.digest arg2).to eq Digest::SHA1.hexdigest(arg2.to_s)
      expect(described_class.digest [arg1, arg2]).to eq Digest::SHA1.hexdigest([arg1, arg2].to_s)
    end
  end

  describe '.key' do
    before(:each) do
      described_class.register_key_prefix prefix
    end

    context 'given no arguments' do
      it 'returns the same key as string with the prefix' do
        expect(described_class.key :i_am_not_there).to eq "#{prefix}/i_am_not_there"
      end
    end

    context 'with extra arguments' do
      let(:key) { :somekey }
      context 'symbols or strings: `service.key :somekey, :arg1, "arg2"`' do
        it 'prefix/somekey/arg1/arg2' do
          expect(described_class.key key, :extra1, 'extra2').to eq "#{prefix}/#{key}/extra1/extra2"
        end
      end

      context 'objects that respond to `cache_key`: `service.key :somekey, :arg1, active_record_model, "arg3"`' do
        let(:cache_key) { 'my_cache_key' }
        let(:model) { OpenStruct.new cache_key: cache_key }

        it 'prefix/somekey/arg1/active_record_model.cache_key/arg3' do
          expected = "#{prefix}/#{key}/arg1/#{cache_key}/arg3"

          expect(described_class.key key, :arg1, model, 'arg3').to eq expected
        end
      end

      context 'digest' do
        let(:cache_key) { 'my_cache_key' }
        let(:model) { OpenStruct.new cache_key: cache_key }
        let(:long_object) { Faker::Lorem.sentences 6 }
        let(:object2) { [1, 2, 3] }

        context '`service.key :somekey, :arg1, active_record_model, "arg3", digest: long_object`' do
          let(:sha1) { Digest::SHA1.hexdigest long_object.to_s }

          it 'prefix/somekey/arg1/active_record_model.cache_key/arg3/long_object_sha1' do
            expected = "#{prefix}/#{key}/arg1/#{cache_key}/arg3/#{sha1}"

            expect(described_class.key key, :arg1, model, 'arg3', digest: long_object).to eq expected
          end
        end

        context '`service.key :somekey, :arg1, active_record_model, "arg3", digest: [long_object, object2]`' do
          let(:sha1) { Digest::SHA1.hexdigest [long_object, object2].to_s }

          it 'prefix/somekey/arg1/active_record_model.cache_key/arg3/combined_long_object_and_object2_array_sha1' do
            expected = "#{prefix}/#{key}/arg1/#{cache_key}/arg3/#{sha1}"

            expect(described_class.key key, :arg1, model, 'arg3', digest: [long_object, object2]).to eq expected
          end
        end
      end

      context 'variables' do
        before(:each) do
          described_class.variable_set variable_name1, variable_value1
          described_class.variable_set variable_name2, variable_value2
          described_class.variable_set :my_var, 1
        end

        let(:variable_name1) { :var1 }
        let(:variable_value1) { Faker::Lorem.sentence }
        let(:variable_name2) { :var2 }
        let(:variable_value2) { 123 }

        let(:expected_variable_hash) do
          {
            variable_name1 => variable_value1.to_s,
            variable_name2 => variable_value2.to_s,
            unset:         nil,
          }
        end

        describe '`service.key :somekey, arg1, variables: [:var1, :var2, :unset]`' do
          let(:sha1) { Digest::SHA1.hexdigest expected_variable_hash.to_s }

          it 'prefix/somekey/arg1/sha1_of_hash_with_variable_names_and_values_from_store' do
            expected = "#{prefix}/#{key}/arg1/#{sha1}"

            expect(described_class.key key, :arg1, variables: [variable_name1, variable_name2, :unset]).to eq expected
          end
        end

        context 'with digest at the same time: joint digest from normal digest and variables hash' do
          describe '`service.key :somekey, arg1, digest: [:dig1, :dig2] variables: :my_var`' do
            let(:expected_variable_hash) { { my_var: '1' } }
            let(:sha1) { Digest::SHA1.hexdigest [[:dig1, :dig2], expected_variable_hash].to_s }

            it 'prefix/somekey/arg1/sha1_of_hash_with_digest_array_and_variable_names_and_values_from_store' do
              expected = "#{prefix}/#{key}/arg1/#{sha1}"

              expect(described_class.key key, :arg1, digest: [:dig1, :dig2], variables: :my_var).to eq expected
            end
          end
        end

      end

      context 'request' do
        let(:fullpath) { '/some/path?with=http&arguments=1' }

        let(:request) do
          OpenStruct.new fullpath: fullpath
        end

        let(:to_digest) do
          [fullpath.parameterize, fullpath]
        end

        context 'given an option with the rails request (or any object that returns a string with `fullpath`)' do
          context '`service.key :somekey, :arg1, request: rails_request`' do
            let(:sha1) { Digest::SHA1.hexdigest to_digest.to_s }

            it 'prefix/somekey/arg1/request_fullpath_based_sha1' do
              expected = "#{prefix}/#{key}/arg1/#{sha1}"

              expect(described_class.key key, :arg1, request: request).to eq expected
            end
          end
        end
      end
    end
  end

  describe '.register_default_options' do
    let(:default_default_options) { {} }
    let(:default_options) { { expires_in: 5.minutes } }

    it 'sets the options to be used as default when needed' do
      expect(described_class.default_options).to eq default_default_options
      described_class.register_default_options default_options
      expect(described_class.default_options).to eq default_options
    end
  end

  describe '.register_options' do
    let(:name) { :my_name }
    let(:options) { { expires_in: 1.hour } }
    it 'register on the given name the given array of options to be used when needed' do
      expect(described_class.registered_options? name).to be_falsey
      expect(described_class.registered_options name).to be_nil

      described_class.register_options name, options

      expect(described_class.registered_options? name).to be_truthy
      expect(described_class.registered_options name).to eq options
    end

    it 'needs a valid (not blank) name' do
      expect { described_class.register_options nil }.to raise_error ArgumentError
      expect { described_class.register_options '' }.to raise_error ArgumentError
    end
  end

  describe '.options' do
    let(:default_options) { { expires_in: 5.minutes } }
    let(:options) { { race_condition_ttl: 1 } }
    let(:name) { :my_name }

    let(:other_options) { { race_condition_ttl: 4 } }
    let(:other_name) { :other_name }

    let(:expected) { default_options.merge options }

    before(:each) do
      described_class.register_default_options default_options
    end

    context 'with a couple of registered' do
      before(:each) do
        described_class.register_options name, options
        described_class.register_options other_name, other_options
      end

      context 'given a registered option name' do
        it 'merges into default the options stored into' do
          expect(described_class.options name).to eq expected
        end
      end

      context 'given a list of names, at least one of which is registered' do
        it 'merges the registered one with defaults' do
          expect(described_class.options :missing, name, other_name).to eq expected
        end
      end

      context 'given no registered options name' do
        context 'without extra arguments' do
          it 'returns an empty hash' do
            expect(described_class.options :missing, :another_missing).to eq({})
          end
        end

        context 'with return_if_missing: :default' do
          it 'returns the default options' do
            expect(described_class.options :missing, :another_missing, return_if_missing: :default).to eq default_options
          end
        end

        context 'with return_if_missing: :nil' do
          it 'returns nil' do
            expect(described_class.options :missing, :another_missing, return_if_missing: :nil).to be_nil
          end
        end

        context 'with return_if_missing: :empty' do
          it 'returns an empty hash' do
            expect(described_class.options :missing, :another_missing, return_if_missing: :empty).to eq({})
          end
        end
      end
    end
  end

  describe 'variables' do
    describe '.register_variables_store' do

      context ':another' do
        it 'raises error' do
          expect { described_class.register_variables_store :another }.to raise_error ArgumentError
        end
      end

      context ':redis' do
        it 'creates a new variable store of type redis' do
          described_class.register_variables_store :redis
          s = described_class.variables_store
          expect(s.type).to eq :redis
        end
      end

      context ':internal' do
        context 'first call' do
          it 'creates a new variable store of type internal' do
            described_class.register_variables_store :internal
            s = described_class.variables_store
            expect(s.type).to eq :internal
          end
        end

        context 'with an already established internal variable store' do
          it 'keeps the same variable store' do
            described_class.register_variables_store :internal

            s = described_class.variables_store

            described_class.register_variables_store :internal
            expect(described_class.variables_store.object_id).to eq s.object_id
          end
        end


        context 'passing force: true' do
          it 'creates a new variable store of type internal' do
            described_class.register_variables_store :internal

            s = described_class.variables_store

            described_class.register_variables_store :internal, force: true
            expect(described_class.variables_store.object_id).not_to eq s.object_id
          end
        end
      end
    end

    describe '.variables_store' do
      context 'without any registered' do
        it 'returns an internal store' do
          s = described_class.variables_store
          expect(s.type).to eq :internal
          expect(described_class.variables_store.object_id).to eq s.object_id
        end
      end
    end

    describe '.reload_variables_store' do
      it 'returns another store of the same type' do
        s = described_class.variables_store
        expect(s.type).to eq :internal
        sid = s.object_id
        expect(described_class.variables_store.object_id).to eq sid

        described_class.reload_variables_store

        expect(described_class.variables_store.object_id).not_to eq sid
      end
    end

    describe 'with store :internal' do
      before(:each) do
        described_class.register_variables_store :internal
      end

      let(:variable_key) { :my_var }
      let(:variable_value) { 1234 }

      describe '.variables' do
        let(:variable_keys) { [:key_a, :key_b, :key_c] }
        let(:expected_variable) { variable_keys.map &:to_s }

        it 'returns a list of variable keys already set' do
          variable_keys.each_with_index do |key, index|
            described_class.variable_set key, index
          end

          expect(described_class.variables.sort).to eq expected_variable.sort
        end
      end

      describe '.variable_set(key, value)' do
        it 'sets the given value in the given key' do
          expect(described_class.variable_get variable_key).to be_nil
          described_class.variable_set variable_key, variable_value
          expect(described_class.variable_get variable_key).to eq variable_value.to_s
        end
      end

      describe '.variable_get' do
        context 'with a key with a value' do
          it 'returns the value' do
            described_class.variable_set variable_key, variable_value
            expect(described_class.variable_get variable_key).to eq variable_value.to_s
          end
        end

        context 'with a key without a value' do
          it 'returns nil' do
            expect(described_class.variable_get variable_key).to be_nil
          end
        end

        context 'with a key without a value and a block' do
          it 'sets the result of the block and returns it' do
            expect(described_class.variable_get variable_key).to be_nil
            expect(described_class.variable_get(variable_key) { 990 }).to eq '990'
            expect(described_class.variable_get variable_key).to eq '990'
          end
        end
      end

    end

    describe 'with store :redis' do
      let(:redis_options) do
        {
          namespace: 'xyz',
          host:      'localhost',
          port:      6379,
          db:        0,
        }
      end

      let(:redis_prefix) { 'my_redis_prefix' }

      let(:redis_client) { Redis.new redis_options }

      context 'settings' do
        describe '.redis_options' do
          it 'default options: an empty hash' do
            expect(described_class.redis_options).to eq({})
          end

          it 'hash of options to pass to the Redis client initializer' do
            bad_options = { caca: :futi }
            expect(Redis).to receive(:new).with(bad_options).and_return(redis_client)

            described_class.redis_options = bad_options
            described_class.register_variables_store :redis, force: true
            described_class.variable_get :something
          end
        end

        describe '.redis_variable_prefix' do
          before(:each) do
            described_class.redis_options = redis_options
            described_class.register_variables_store :redis, force: true
          end

          context 'unset: default value' do
            it { expect(described_class.redis_variable_prefix).to eq 'artirix_cache_service' }
          end

          it 'will be used as a prefix (separated by "_") on the keys' do
            described_class.variable_set 'myvar', 'paco'
            expect(redis_client.get 'artirix_cache_service_myvar').to eq 'paco'
          end
        end
      end

      context 'operations' do
        before(:each) do
          redis_client.flushdb
          described_class.reload_service
          described_class.redis_variable_prefix = redis_prefix
          described_class.redis_options         = redis_options
          described_class.register_variables_store :redis, force: true
        end

        let(:variable_key) { :my_var }
        let(:variable_value) { 1234 }

        describe '.variables' do
          let(:variable_keys) { [:key_a, :key_b, :key_c] }
          let(:expected_variable) { variable_keys.map &:to_s }

          it 'returns a list of variable keys already set' do
            variable_keys.each_with_index do |key, index|
              described_class.variable_set key, index
            end

            expect(described_class.variables.sort).to eq expected_variable.sort
          end
        end

        describe '.variable_set(key, value)' do
          it 'sets the given value in the given key' do
            expect(described_class.variable_get variable_key).to be_nil
            described_class.variable_set variable_key, variable_value
            expect(described_class.variable_get variable_key).to eq variable_value.to_s

            expect(redis_client.get "#{redis_prefix}_#{variable_key}").to eq variable_value.to_s
          end
        end

        describe '.variable_get' do
          context 'with a key with a value' do
            it 'returns the value' do
              described_class.variable_set variable_key, variable_value
              expect(described_class.variable_get variable_key).to eq variable_value.to_s
            end
          end

          context 'with a value stored directly in redis' do
            it 'returns the value' do
              expect(described_class.variable_get variable_key).to be_nil
              redis_client.set "#{redis_prefix}_#{variable_key}", variable_value
              expect(described_class.variable_get variable_key).to eq variable_value.to_s
            end
          end

          context 'with a key without a value' do
            it 'returns nil' do
              expect(described_class.variable_get variable_key).to be_nil
            end
          end

          context 'with a key without a value and a block' do
            it 'sets the result of the block and returns it' do
              expect(described_class.variable_get variable_key).to be_nil
              expect(described_class.variable_get(variable_key) { 990 }).to eq '990'
              expect(described_class.variable_get variable_key).to eq '990'
            end
          end
        end
      end

    end

  end

  describe '.view_helper' do
    context 'return a view_helper with `artirix_cache` method' do
      it 'is a Module with the artirix_cache method' do
        helper = described_class.view_helper
        expect(helper).to be_a_kind_of Module

        instance = view_instance_with_helper(helper)
        expect(instance).to respond_to :artirix_cache
      end

      context '`artirix_cache(key_prefix, options_name = [], *key_params, &block)`' do
        let(:fullpath) { '/some/path?with=http&arguments=1' }

        let(:request) do
          OpenStruct.new fullpath: fullpath
        end

        let(:default_options) { { expires_in: 5.minutes } }

        let(:options1) { { disable_cache: true } }
        let(:options2) { { expires_in: 15.minutes } }
        let(:options3) { { expires_in: 1.hour } }

        let(:merged_options1) { default_options.merge options1 }
        let(:merged_options2) { default_options.merge options2 }
        let(:merged_options3) { default_options.merge options3 }


        before(:each) do
          described_class.register_default_options default_options
          described_class.register_options :options1, options1
          described_class.register_options :options2, options2
          described_class.register_options :options3, options3
        end

        let(:view) { view_instance_with_helper described_class.view_helper }

        context 'first argument' do
          it 'first argument is the base for `.key` call' do
            expect(ArtirixCacheService).to receive(:key).with(:my_key, :other, :arg)
            res = view.artirix_cache :my_key, :options2, :other, :arg do
              'SOME STRING'
            end

            expect(res).to eq 'SOME STRING'
          end

          it 'is required' do
            expect do
              view.artirix_cache do
                'SOME STRING'
              end
            end.to raise_error ArgumentError

            expect do
              view.artirix_cache nil do
                'SOME STRING'
              end
            end.to raise_error ArgumentError

            expect do
              view.artirix_cache '' do
                'SOME STRING'
              end
            end.to raise_error ArgumentError
          end
        end

        context 'third and subsequent arguments' do
          it 'extra arguments to `.key`' do
            expect(ArtirixCacheService).to receive(:key).with(:my_key, :other, :arg, { request: request })
            res = view.artirix_cache :my_key, :options2, :other, :arg, request: request do
              'SOME STRING'
            end

            expect(res).to eq 'SOME STRING'
          end
        end

        context 'second argument' do
          context 'given a registered option' do
            it 'gets that option from the Service and passes it to the `cache` method' do
              expected_key = described_class.key :my_key, :arg

              expect(view).to receive(:cache).with(expected_key, options2)

              view.artirix_cache :my_key, :options2, :arg do
                'STRING'
              end
            end
          end

          context 'given a list of options, at least one registered' do
            it 'gets that option from the Service and passes it to the `cache` method' do
              expected_key = described_class.key :my_key, :arg

              expect(view).to receive(:cache).with(expected_key, options2)

              view.artirix_cache :my_key, [:nope, :options2, :options3], :arg do
                'STRING'
              end
            end
          end

          context 'given a list of options, none registered' do
            it 'gets the default options from the Service and passes it to the `cache` method' do
              expected_key = described_class.key :my_key, :arg

              expect(view).to receive(:cache).with(expected_key, default_options)

              view.artirix_cache :my_key, [:nope, :neither], :arg do
                'STRING'
              end
            end
          end

          context 'with selected option with `disable_cache: true`' do
            it 'yields without invoking `cache`' do
              expect(view).not_to receive(:cache)
              res = view.artirix_cache :key, [:no_options, :options1] do
                'SOME STRING'
              end

              expect(res).to eq 'SOME STRING'
            end
          end
        end
      end
    end
  end
end
