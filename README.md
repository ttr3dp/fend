# Fend [![Gem Version](https://badge.fury.io/rb/fend.svg)](https://badge.fury.io/rb/fend) [![Build Status](https://travis-ci.org/aradunovic/fend.svg?branch=master)](https://travis-ci.org/aradunovic/fend)

Fend is a small and extensible data validation toolkit.

## Contents

* [**Features**](#features)
* [**Documentation**](#documentation)
* [**Why?**](#why)
* [**Installation**](#installation)
* [**Introduction**](#introduction)
    * [Core functionalities](#core-functionalities)
    * [Nested params](#nested-params)
    * [Arrays](#arrays)
* [**Plugins overview**](#plugins-overview)
    * [Value helpers](#value-helpers)
    * [Validation helpers](#validation-helpers)
    * [Validation options](#validation-options)
    * [Contexts](#contexts)
    * [Data processing](#data-processing)
    * [Dependencies](#dependencies)
    * [Coercions](#coercions)
    * [External validation](#external-validation)
    * [Full messages](#full-messages)
    * [Object validation](#object-validation)
* [**Code of Conduct**](#code-of-conduct)
* [**License**](#license)

## Features

Some of the features include:

* Helpers for common validation cases
* Type coercion
* Dependency management
* Custom/external validation support
* Data processing
* Contextual validations
* Object validation

## Documentation

For detailed documentation visit [aradunovic.github.io/fend](https://aradunovic.github.io/fend)

## Why?

Let's be honest, data validation often tends to get messy and complex.
Most of the time you'll find yourself adding validation logic to domain models
and coming up with workarounds in order handle more complex cases.

What I wanted to make was a library that doesn't do too much. Even better, a
library that **does nothing**, but provide the tools for building custom
validation logic.

## Installation

```ruby
# Gemfile
gem "fend"
```

Or install system wide:

    gem install fend

## Introduction

We'll start with a simple example that show Fend's core functionalities. The
implementation will later be improved through a series of refactoring steps,
which will get you familiar with Fend's plugins.

### Core functionalities

By default, Fend doesn't do much. As the example below shows, it provides
methods for specifying params, fetching their values and appending errors.
All checks need to be implemented manually.

```ruby
require "fend"

# Create a validation class which inherits from `Fend`
class UserValidation < Fend
  # define validation block
  validation do |i|
    # specify username and email params that needs to be validated
    i.params(:username, :email) do |username, email|
      # append error if username value is not string
      username.add_error("must be string") unless username.value.is_a?(String)

      # append error is email is invalid or already exists
      email.add_error("is not a valid email address") unless email.match?(EMAIL_REGEX)
      email.add_error("must be unique") if email.valid? && !unique?(email: email.value)

      username.valid? #=> false
      email.invalid? #=> true
    end
  end

  # you have full access to the constructor
  def initialize(user_model)
    @user_model = user_model
  end

  # custom methods are available in validation block
  def unique?(args)
    user_model.exists?(args)
  end

  def user_model
    @user_model
  end
end
```

* `i` - represents validation input. It's actually an instance of
        `Param` class, same as `username`.

Let's run the validation:

```ruby
# run the validation and store the result
result = UserValidation.new(User).call(username: 1234, email: "invalid@email")

# check if result is a success
result.success? #=> false

# check if result is failure
result.failure? #=> true

# get validation input
result.input #=> { username: 1234, email: "invalid@email" }

# get result output
result.output #=> { username: 1234, email: "invalid@email" }

# get error messages
result.messages #=> { username: ["must be string"], email: ["is not a valid email address"] }
```

`result` is an instance of `Result` class.

### Nested params

Nested params are defined in the same way as regular params:

```ruby
i.params(:address) do |address|
  address.add_error("must be hash") unless address.value.is_a?(Hash)

  address.params(:city, :street) do |city, :street|
    city.add_error("must be string") unless city.value.is_a?(String)
    street.add_error("must be string") unless street.value.is_a?(String)
  end
end
```

Let's execute the validation:

```ruby
result = UserValidation.call(address: :invalid)
result.failure? #=> true
result.messages #=> { address: ["must be hash"] }
```

As you can see, nested param validations are **not** executed when
parent param is invalid.

```ruby
result = UserValidation.call(username: "test", address: {})
result.messages #=> { address: { city: ["must be string"], street: ["must be string"] } }
```

### Arrays

Validating array members is done by passing a block to `Param#each` method:

```ruby
i.param(:tags) do |tags|
  tags.each do |tag|
    tag.add_error("must be string") unless tag.value.is_a?(String)
  end
end
```

Now, if we run the validation:

```ruby
result = UserValidation.call(tags: [1, 2])
result.messages #=> { tags: { 0 => ["must be string"], 1 => ["must be string"] } }
```

Needless to say, member validation won't be run if `tags` is not an array.

Fend makes it possible to validate specific array members, since `#each` method
also provides an `index`:

```ruby
tags.each do |tag, index|
  if index == 0
    tag.add_error("must be integer") unless tag.value.is_a?(Integer)
  else
    tag.add_error("must be string") unless tag.value.is_a?(String)
  end
end
```

## Plugins overview

For complete plugins documentation, go to [aradunovic.github.io/fend](https://aradunovic.github.io/fend).

### Value helpers

The `value_helpers` plugin provides additional `Param` methods that can be used to
check or fetch param values.

```ruby
plugin :value_helpers

validate do |i|
  i.params(:username, :details, :tags) do |username, details, tags|
    username.present? #=> false
    username.blank? #=> true
    username.empty_string? #=> true

    details.type_of?(Hash) #=> true
    details.dig(:address, :info, :coordinates, 0) #=> 35.6895

    details.dig(:invalid_key, 0, :name) #=> nil

    tags.dig(0, :id) #=> 1
    tags.dig(1, :name) #=> "js"
  end
end

UserValidation.call(
  username: "",
  details: { address: { info: { coordinates: [35.6895, 139.6917] } } },
  tags: [{ id: 1, name: "ruby"}, { id: 2, name: "js" }]
)
```

### Validation helpers

The `validation_helpers` plugin provides methods for some common validation cases:

```ruby
plugin :validation_helpers

validation do |i|
  i.params(:username, :address, :tags) do |username, address, tags|
    username.validate_presence
    username.validate_type(String)

    address.validate_type(Hash)

    address.params(:city) do |city|
      city.validate_presence
      city.validate_type(String)
    end

    tags.validate_type(Array)
    tags.validate_min_length(1)

    tags.each do |tag|
      tag.validate_type(String)
      tag.validate_inclusion(%w(ruby js elixir), message: "#{tag.value} is not a valid tag")
    end
  end
end
```

### Validation options

Instead of calling validation helpers separately, `validation_options` plugin
can be used in order to specify all validations as options.

```ruby
plugin :validation_options

validation do |i|
  i.params(:username, :address, :tags) do |username, address, tags|
    username.validate(presence: true, type: String)

    address.validate_type(Hash)
    address.params(:city) { |city| city.validate(presence: true, type: String) }

    tags.validate(type: Array, min_length: 1)
    tags.each do |tag|
      tag.validate(type: String,
                   inclusion: { in: %w(ruby js elixir), message: "#{tag.value} is not a valid tag" })
    end
  end
end
```

`:allow_nil` and `:allow_blank` options are also supported:

```ruby
username.validate(type: String, allow_nil: true)
```

### Contexts

`contexts` plugin adds support for contextual validation, which basically
means you can branch validation logic depending on provided context.

```ruby
class UserValidation < Fend
  plugin :contexts

  validate do |i|
    i.params(:account_type) do |acc_type|
      context(:admin) do
        acc_type.validate_equality("admin")
      end

      context(:editor) do
        acc_type.validate_equality("editor")
      end

      # you can check context against multiple values
      context(:visitor, :demo) do
        acc_type.validate_equality(nil)
      end
    end
  end
end

user_validation = UserValidation.new(context: :editor)
user_validation.call(account_type: "invalid").messages #=> { account_type: ["must be equal to 'editor'"] }
```

If no context is provided, context will be set to `:default`.

### Data processing

With `data_processing` plugin you can process input/output data.

You can use some of the built-in processings, like `:symbolize`, for example:

```ruby
class UserValidation < Fend
  plugin :data_processing, input: [:symbolize]

  # ...
end

UserValidation.call("username" => "john", email: "john@example.com", "admin" => true)
```

You can define custom processings:

```ruby
class UserValidation < Fend
  plugin :data_processing

  process(:input) do |input|
    input.merge(foo: "foo")
  end

  process(:output) do |output|
    output.merge(timestamp: Time.now.utc)
  end

  validate do |i|
    i.params(:username, :foo) do |username, foo|
      username.value #=>"john"
      foo.value #=> "foo"
    end
  end
end

result = UserValidation.call(username: "john")

result.input #=> { username: "john", foo: "foo" }
result.output #=> { username: "john", timestamp: 2018-01-01 00:00:00 UTC }
```

### Dependencies

The `dependencies` plugin enables you to register and resolve global dependencies.

To resolve dependencies, pass `:inject` option with dependency list
to `.validate` method:

```ruby
plugin :validation_options
plugin :dependencies, user_model: User

validate(inject: [:user_model]) do |i, user_model|
  i.params(:email, :password, :password_confirmation) do |email, password, password_confirmation|
    if email.present? && !user_model.exists?(email: email.value)
      email.add_error("not found")
    end
  end
end
```

Here, `:user_model` is an inheritable dependency, which means it will be
available in subclasses also. Global dependencies can be defined on `Fend` directly:

```ruby
Fend.plugin :dependencies, user_model: User
```

### Coercions

`coercions` plugin coerces input param values based on provided type schema.
By default, incoercible values are returned unmodified.

```ruby
plugin :coercions

coerce username: :string,
       address: { street: :string, city: :string },
       tags: [:string]

validate do |i|
  i.params(:username, :address, :tags) do |username, address, tags|
    username.value #=> "foobar"
    address.value  #=> {}
    tags.value     #=> ["1", "foo", "cooking"]
  end
end

result = UserValidation.call(username: :foobar, address: "", tags: [1, "foo", :cooking])

result.input  #=> { username: :foobar, address: "", tags: [1, "foo", :cooking] }
result.output #=> { username: "foobar", address: {}, tags: ["1", "foo", "cooking"] }
```

### External validation

With `external_validation` plugin param validations can be delegated to a
class/object that responds to `call` and returns error messages.

```ruby
class CustomEmailValidator
  def initialize
    @errors = []
  end

  def call(email_value)
    @errors << "must be string" unless email_value.is_a?(String)
    @errors << "must be unique" unless unique?(email_value)

    @errors
  end

  def unique?(value)
    UniquenessCheck.call(value)
  end
end

class AddressValidation < Fend
  plugin :validation_options

  validate do |i|
    i.params(:city, :street) do |city, street|
      city.validate(type: String)
      street.validate(type: String)
    end
  end
end

class UserValidation < Fend
  plugin :external_validation

  validate do |i|
    i.params(:email, :address) do |email, address|
      email.validate_with(CustomEmailValidation.new)

      address.validate_with(AddressValidation)
    end
  end
end
```

### Full messages

`full_messages` plugin defines `Result#full_messages` method which returns
error messages with prepended param name.

```ruby
class UserValidation < Fend
  plugin :full_messages, array_member_names: { tags: :tag }

  # ...
end

result = UserValidation.call(username: nil, address: {}, tags: [1])

result.full_messages
# {
#   username: ["username must be present"],
#   address: { city: ["city must be string"] },
#   tags: { 0 => ["tag must be string"] }
# }
```

### Object validation

`object_validation` plugin adds support for validating object attributes
and methods.

```ruby
class UserModelValidation < Fend
  plugin :object_validation
  plugin :validation_options

  validate do |user|
    # use #attrs when validating object attributes/methods
    user.attrs(:username, :email, :address) do |username, email, address|
      username.validate(presence: true, max_length: 20, type: String)
      email.validate(presence: true, format: EMAIL_REGEX, type: String)

      # keep using #params if attribute value is expected to be hash
      address.params(:city, :street) do |city, street|
        city.validate(presence: true)
        street.validate(presence: true)
      end
    end
  end
end

user = User.new(username: "", email: "invalid@email", address: {})
validation = UserModelValidation.call(user)

validation.success? #=> false
validation.messages
#=> {
#      username: ["must be present"],
#      email: ["is in invalid format"],
#      address: { city: ["must be present"], street: ["must be present"] }
#   }
```

## Code of Conduct

Everyone interacting in the Fend project’s codebases, issue trackers, chat rooms
and mailing lists is expected to follow the
[code of conduct](https://github.com/aradunovic/fend/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
