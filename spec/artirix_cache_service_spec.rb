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

  describe '.config_params' do
    let(:default_config) { { key_prefix: nil } }

    it 'gives access to the hash of config' do
      expect(described_class.config_params).to eq default_config
      expect(described_class.key_prefix).to eq default_config[:key_prefix]
    end

    it 'allows us to modify it BEFORE the service is used' do
      expect(described_class.key_prefix).to eq default_config[:key_prefix]
      described_class.config_params[:key_prefix] = prefix
      expect(described_class.key_prefix).to eq prefix
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
      described_class.config_params[:key_prefix] = prefix
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
end
