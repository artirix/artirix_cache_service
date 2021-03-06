# ArtirixCacheService

[![Gem Version](https://badge.fury.io/rb/artirix_cache_service.svg)](http://badge.fury.io/rb/artirix_cache_service)
[![Build Status](https://travis-ci.org/artirix/artirix_cache_service.svg?branch=master)](https://travis-ci.org/artirix/artirix_cache_service)
[![Code Climate](https://codeclimate.com/github/artirix/artirix_cache_service.png)](https://codeclimate.com/github/artirix/artirix_cache_service)
[![Code Climate Coverage](https://codeclimate.com/github/artirix/artirix_cache_service/coverage.png)](https://codeclimate.com/github/artirix/artirix_cache_service)

The basic use of this gem is to compile a cache key based on a given key prefix
and some extra variables or arguments, with some helper methods. It also helps
with the cache options.

## Usage: `.key`

The basic way of using it is with the `key` method, which will return the key based on the given arguments. 

```ruby
ArtirixCacheService.key :some_key # => will return a string with the cache key to use
```

### Prefix

The service can use a prefix to be applied to all keys

```ruby
ArtirixCacheService.register_key_prefix = :configured_prefix
ArtirixCacheService.key :some_key # => "configured_prefix/some_key"
ArtirixCacheService.key :another # => "configured_prefix/another"
```

### Extra Arguments

We can pass other arguments, that will be treated and appended to the cache key.

note: `blank?` arguments will be skipped.

```ruby
ArtirixCacheService.register_key_prefix :configured_prefix

ArtirixCacheService.key :some_key, :arg1, nil, 'arg2' 
  # => "configured_prefix/some_key/arg1/arg2"
```

#### `cache_key` compliant arguments

if an argument (including the first argument) responds to `cache_key`, 
it will be called.

```ruby
ArtirixCacheService.register_key_prefix :configured_prefix

article = Article.find 17
article.cache_key # => "cache_key_article_17"

ArtirixCacheService.key :some_key, :arg1, article, 'arg2' 
  # => "configured_prefix/some_key/arg1/cache_key_article_17/arg2"
```

#### Digest

we may want to add a digest to the cache key instead of all arguments, 
for example in case that we're giving it a long list.

It will use SHA1.

```ruby
ArtirixCacheService.register_key_prefix :prfx

arg3 = { a: 1, b: 2 }
ArtirixCacheService.digest arg3 
  # => "032b5f154d4ada01bc89a2e8fae8251c090212db"

ArtirixCacheService.key :some_key, :arg1, 'arg2', digest: arg3
  # => "prfx/some_key/arg1/arg2/032b5f154d4ada01bc89a2e8fae8251c090212db"

arg4 = [1, 2, 3]
ArtirixCacheService.digest [arg3, arg4] 
  # => "7448a071aeee91fc9ee1c705f15445fdd8411224"


ArtirixCacheService.key :some_key, :arg1, 'arg2', digest: [arg3, arg4]
  # => "prfx/some_key/arg1/arg2/7448a071aeee91fc9ee1c705f15445fdd8411224"
```

### `request` as special digest part

we can pass the request as a special argument. The Service will invoke `fullpath` 
on it in the final digest.

It uses a parameterized version of the fullpath followed by a untouched version, 
to avoid any collision.

```ruby
request 
  # => an ActionDispatch::Request, or any object that responds to `fullpath` 
 
request.fullpath # => "/some/path?with=arguments"

ArtirixCacheService.key :some_key, :arg1, 'arg2', request: request
  # => "prfx/some_key/arg1/arg2/1d3c96f449b8d21df75ebcf378c8f2455bf4e93c"

# >> Digest::SHA1.hexdigest [request.fullpath.parameterize, request.fullpath].to_s
# => "1d3c96f449b8d21df75ebcf378c8f2455bf4e93c"
```

## Usage: `.options`

used for getting the cache options based on the registered defaults and the registered options.
 
```ruby

# unless registered otherwise, the default options is an empty array
ArtirixCacheService.default_options # => {}


# sets the options to be used as default when needed
ArtirixCacheService.register_default_options expires_in: 300

# we can register some options based on a name (Symbol)
ArtirixCacheService.registered_options? :my_options # => false
ArtirixCacheService.registered_options :my_options # => nil

ArtirixCacheService.register_options :my_options, race_condition_ttl: 1

ArtirixCacheService.registered_options? :my_options # => true
ArtirixCacheService.registered_options :my_options # => { race_condition_ttl: 1 }

```

once we have our different options registered, we can use the Service to get the 
desired final options.

Given a list of names, it will use the first one that is registered. It will 
return the options on that name, merged over the default options 

```ruby
ArtirixCacheService.options :missing, :my_options 
  # => { expires_in: 300, race_condition_ttl: 1 } 
```

If no registered option is found from the given list, then it will return 
- `nil` (if passing keyword `return_if_missing: :nil`)
- default options (if passing keyword `return_if_missing: :default`)
- an empty hash (default behaviour, or passing keyword `return_if_missing` with any other value)

```ruby
ArtirixCacheService.options :missing, :another_missing
  # => {}
  
ArtirixCacheService.options :missing, :another_missing, return_if_missing: :default
  # => { expires_in: 300 }
  
ArtirixCacheService.options :missing, :another_missing, return_if_missing: :nil
  # => nil

ArtirixCacheService.options :missing, :another_missing, return_if_missing: :empty
  # => {} 
```

## Variables

as part of the cache_key, we can specify the name of a variable that the Service 
can retrieve to use in the digest.

Using this, we can effectively change cache_keys arguments without changing code, 
effectively invalidating cache without coupling.
  
If the variable does not have a value, it will get nil, which is valid for the 
digest.

Note: we retrieve the variables as strings always, and return nil if `blank?`.
  
```ruby

# some_view.html.erb
<%= cache ArtirixCacheService.key(:my_key, variables: :my_var) %>
...
<% end %>

# first request, variable :my_var does not have a value (nil), so 
# the cache_key is "prfx/my_key/333a21750df06ef3c82aece819ded0f6f691638a" 

# Digest::SHA1.hexdigest( { my_var: nil }.to_s )
#  # => "333a21750df06ef3c82aece819ded0f6f691638a"

# model_a.rb
uuid = SecureRandom.uuid # => "6d6eb11e-0241-4f97-b706-91982eb8e69b"
ArtirixCacheService.variable_set :my_var, uuid

# now the next request on the view, the cache key is different:
# cache key is "prfx/my_key/a8484d25b7c57b1f93a05ad82422d7b45c4ad83e"

# Digest::SHA1.hexdigest( { my_var: uuid }.to_s )
#  # => "a8484d25b7c57b1f93a05ad82422d7b45c4ad83e"

# => 
```

This way we can invalidate based on a variable value, without directly 
invalidating cache, for the use cases when we cannot rely on the argument's `cache_key`. 

We use `variable_set` to set new values, and `variable_get` to retrieve them.

We can also pass an optional block to `variable_get` to set the value if it's nil.

```ruby

ArtirixCacheService.variable_get :my_var # => nil
ArtirixCacheService.variable_get(:my_var) { 990 } # => "990"
ArtirixCacheService.variable_get :my_var # => "990" 
```

We can list the variables that the service has currently access to with `.variables`
 
```ruby
ArtirixCacheService.variables # => [ "my_var" ]
```

### Variable Store

by default (dev mode) the values are stored in an internal hash.
 
#### Redis

it can connect to Redis, using the given options, and store the variables with
a given prefix.

```ruby
redis_options = {
                  namespace: 'xyz',
                  host:      'localhost',
                  port:      6379,
                  db:        0,
                }

ArtirixCacheService.redis_options = redis_options
ArtirixCacheService.register_variables_store :redis, force: true
```

A prefix on the variable name will be used. By default it's `artirix_cache_service`.
It gets prepended to the given variable name, and separated by `_`.

```ruby
# default prefix
ArtirixCacheService.redis_variable_prefix # => "artirix_cache_service"

# setting a new prefix (don't forget to reload the store)
ArtirixCacheService.redis_variable_prefix = 'my_app_prefix'
ArtirixCacheService.register_variables_store :redis, force: true

# checking variables
ArtirixCacheService.variable_set 'myvar', 'paco'

redis_client = Redis.new redis_options
redis_client.get 'my_app_prefix_myvar' # => 'paco'
```

## View Helper

Calling `ArtirixCacheService.view_helper` we can access a module with a 
`artirix_cache` helper method that acts as a proxy to normal Rails cache 
view helper method.

It will use the Service to get the final key using the `.key` Service method, 
and will load up the options to pass to `cache` method looking for the second 
argument on the registered options (using `.options` Service method).

```ruby
# in ApplicationHelper
include ArtirixCacheService.view_helper

# in the view
<%= artirix_cache :my_key, :registered_options_name, :arg1, request: request do %>
...
<% end %>

# same as 
<%= cache ArtirixCacheService.key(:my_key, :arg1, request: request), 
          ArtirixCacheService.options(:registered_options_name) do %>
...
<% end %>
```

First argument is required and it's the first argument to 
`ArtirixCacheService.key` call. The 3rd and subsequent arguments are the extra 
arguments in that call

The second argument will be used to call `.options`. We can supply an array of 
possible option names to lookup (see `.options` method).


```ruby
<%= artirix_cache :my_key, [:opts1, :otps2], :arg1, request: request do %>
...
<% end %>
```

### with `disable_cache: true` in the options

There is one important difference from using the `artirix_cache` view helper and
calling `cache` directly. If the options hash to be used has a truthy value on
`disable_cache` key, then it will `yield` directly and it will not call the 
`cache` method

example:

```ruby
# having:
ArtirixCacheService.options :options_with_disabled
  # => { expires_in: 300, disable_cache: true }


# in the view
<%= artirix_cache :my_key, :options_with_disabled, :arg1, request: request do %>
...
<% end %>

# will never call `cache` method, it will yield directly
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


# CHANGELOG

## v0.7.0

opening dependency on ActiveSupport to include v5

## v0.6.0

(renamed `v.0.5.1` to `v.0.6.0` since it is a change in the API)

- `redis_client` can now be injected into the service.

## v0.5.0

- added `.variables`

## v0.4.0

- View Helper with `artirix_cache` helper method

## v0.3.1

- add request support

## v0.3.0

- add Redis support

## v0.2.0

- removed `ArtirixCacheService.config_params` support, now using `register_key_prefix` method
- add `options` support
