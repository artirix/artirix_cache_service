require 'spec_helper'
require 'ostruct'
require 'faker'

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
end
