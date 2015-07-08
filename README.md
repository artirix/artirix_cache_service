# ArtirixCacheService

[![Gem Version](https://badge.fury.io/rb/artirix_cache_service.svg)](http://badge.fury.io/rb/artirix_cache_service)
[![Build Status](https://travis-ci.org/artirix/artirix_cache_service.svg?branch=master)](https://travis-ci.org/artirix/artirix_cache_service)
[![Code Climate](https://codeclimate.com/github/artirix/artirix_cache_service.png)](https://codeclimate.com/github/artirix/artirix_cache_service)
[![Code Climate Coverage](https://codeclimate.com/github/artirix/artirix_cache_service/coverage.png)](https://codeclimate.com/github/artirix/artirix_cache_service)

The basic use of this gem is to compile a cache key based on a given key prefix 
and some extra variables or options, with some helper methods.

TODO: also help with the cache options.

## Usage

The basic way of using it is with the `key` method, which will return the key based on the given arguments. 

```ruby
ArtirixCacheService.key :some_key # => will return a string with the cache key to use
```

### Prefix

The service can use a prefix to be applied to all keys

```ruby
ArtirixCacheService.config_params[:key_prefix] = :configured_prefix
ArtirixCacheService.key :some_key # => "configured_prefix/some_key"
ArtirixCacheService.key :another # => "configured_prefix/another"
```

### Extra Arguments

We can pass other arguments, that will be treated and appended to the cache key.

note: `blank?` arguments will be skipped.

```ruby
ArtirixCacheService.config_params[:key_prefix] = :configured_prefix

ArtirixCacheService.key :some_key, :arg1, nil, 'arg2' # => "configured_prefix/some_key/arg1/arg2"
```

#### `cache_key` compliant arguments

if an argument (including the first argument) responds to `cache_key`, it will be called.

```ruby
ArtirixCacheService.config_params[:key_prefix] = :configured_prefix

article = Article.find 17
article.cache_key # => "cache_key_article_17"

ArtirixCacheService.key :some_key, :arg1, article, 'arg2' 
  # => "configured_prefix/some_key/arg1/cache_key_article_17/arg2"
```

#### Digest

we may want to add a digest to the cache key instead of all arguments, for example in case that we're giving it a long list.

It will use SHA1.

```ruby
ArtirixCacheService.config_params[:key_prefix] = :prfx

arg3 = { a: 1, b: 2 }
ArtirixCacheService.digest arg3 # => "032b5f154d4ada01bc89a2e8fae8251c090212db"

ArtirixCacheService.key :some_key, :arg1, 'arg2', digest: arg3
  # => "prfx/some_key/arg1/arg2/032b5f154d4ada01bc89a2e8fae8251c090212db"

arg4 = [1, 2, 3]
ArtirixCacheService.digest [arg3, arg4] # => "7448a071aeee91fc9ee1c705f15445fdd8411224"


ArtirixCacheService.key :some_key, :arg1, 'arg2', digest: [arg3, arg4]
  # => "prfx/some_key/arg1/arg2/7448a071aeee91fc9ee1c705f15445fdd8411224"
```


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'artirix_cache_service'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install artirix_cache_service

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/artirix/artirix_cache_service.

