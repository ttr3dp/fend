# Fend

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fend'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fend


## Core functionality

```ruby
require "fend"

class UserValidation < Fend
  validate do |i|
    # Here, 'i' is a shorthand for input param
    i.param(:name) do |name|
      name.add_error("must be string") unless name.value.is_a?(String)
    end

    i.param(:email) do |email|
      email.add_error("is in invalid format") unless email.value.is_a?(String) && email.value.match?(EMAIL_REGEX)
    end

    i.param(:address) do |address|
      address.add_error("must be a hash") unless address.value.is_a?(Hash)

      address.param(:street) { |street| street.add_error("must be present") if street.value.nil? }
    end

    i.param(:profile) do |profile|
      profile.param(:username) do |username|
        username.add_error("cannot be longer than 10 characters") if username.value.length > 10
      end

      profile.param(:admin) do |admin|
        admin.add_error("must be either true or false") unless [TrueClass, FalseClass].include?(admin.value)
      end
    end

    i.param(:interests) do |interests|
      interests.add_error("must be an array") unless interests.value.is_a?(Array)

      interests.each do |interest|
        interest.add_error("must be string") unless interest.value.is_a?(String)
        interest.add_error("#{interest.value} is not a valid interest") unless ["cooking", "video games", "coding"].include?(interest.value)
      end
    end
  end
end

result = UserValidation.call(
  name:      :invalid,
  email:     "",
  address:   "not a hash",
  profile:   { username: "too long username", admin: "1" },
  interests: [1, "foo", "cooking"]
)

result.success? #=> false
result.failure? #=> true

result.input  #=> { name: :invalid, email: "", address: "not a hash", profile: { username: "too long username", admin: "1" }, interests: [1, "foo", "cooking"] }
result.output #=> { name: :invalid, email: "", address: "not a hash", profile: { username: "too long username", admin: "1" }, interests: [1, "foo", "cooking"] }

result.messages
# {
#  name: ["must be string"],
#  email: ["is in invalid format"],
#  address: ["must be a hash"],
#  profile: { username: ["cannot be longer than 10 characters"], admin: ["must be boolean"] },
#  interests: { 0 => ["must be string"], 1 => ["foo is not a valid interest"] }
# }
```

As you can see, by default, `Fend` doesn't do much. Now, let's improve this implementation with some plugins.

## Plugins

### Validation helpers

`:validation_helpers` plugin provides methods for common validations.

```ruby
class UserValidation < Fend
  plugin :validation_helpers

  validate do |i|
    i.param(:name) { |name| name.validate_type(String) }

    i.param(:email) do |email|
      email.validate_type(String)
      email.validate_format(EMAIL_REGEX)
    end

    i.param(:address) do |address|
      address.validate_type(Hash)

      address.param(:street) { |street| street.validate_presence }
    end

    i.param(:profile) do |profile|
      profile.param(:username) do |username|
        username.validate_type(String)
        username.validate_max_length(10)
      end

      profile.param(:admin) do { |admin| admin.validate_type(:boolean, message: "must be either true or false") }
    end

    i.param(:interests) do |interests|
      interests.validate_type(Array)

      interests.each do |interest|
        interest.validate_type(String)
        interest.validate_inclusion(["cooking", "video games", "coding"],
                                    message: "#{interest.value} is not a valid interest")
      end
    end
  end
end
```

### Validation options

Instead of calling validation helper methods separately, we can use `:validation_options` plugin in order to specify all validations as options.

```ruby
class UserValidation < Fend
  # validation_options depends on validation_helpers plugin which will be loaded automatically
  plugin :validation_options

  validate do |i|
    i.param(:name) { |name| name.validate(type: String) }

    i.param(:email) { |email| email.validate(type: String, format: EMAIL_REGEX) }

    i.param(:address) do |address|
      address.validate_type(Hash)

      address.param(:street) { |street| street.validate_presence }
    end

    i.param(:profile) do |profile|
      profile.param(:username) { |username| username.validate(type: String, max_length: 10) }
      profile.param(:admin) { |admin| admin.validate_type(:boolean, message: "must be either true or false") }
    end

    i.param(:interests) do |interests|
      interests.validate_type(Array)

      interests.each do |interest|
        interest.validate(type: String, inclusion: { in: ["cooking", "video games", "coding"],
                                                    message: "#{interest.value} is not a valid interest" })
      end
    end
  end
end
```

### Collective params

Specifying each param can be tedious in some/most cases. With `collective_params` plugin, this can be done more efficiently.

```ruby
class UserValidation < Fend
  plugin :validation_options
  plugin :collective_params

  validate do |i|
    i.params(:name, :email, :address, :profile, :iterests) do |name, email, address, profile, interests|
      name.validate(type: String)

      email.validate(type: String, format: EMAIL_REGEX)

      address.validate(type: Hash)

      address.params(:street, :city) do |street, city|
        street.validate(presence: true, type: String)
        city.validate(presence: true, type: String)
      end

      profile.params(:username, :admin) do |username, admin|
        username.validate(type: String, max_length: 10)
        admin.validate(type: { of: :boolean, message: "must be either true or false" })
      end

      interests.validate_type(Array)

      interests.each do |interest|
        interest.validate(type: String, inclusion: { in: ["cooking", "video games", "coding"],
                                                     message: "#{interest.value} is not a valid interest" })
      end
    end
  end
end
```

### Coercions

`:coercions` plugin coerces input param values based on provided type schema. By default, uncoercible values are returned unmodified.

```ruby
class UserValidation < Fend
  # ...

  plugin :coercions

  coerce name: :string,
         email: :string,
         address: { street: :string, city: :string },
         profile: { username: :string, admin: :boolean },
         interests: [:string]

  validate do |i|
    # ...
  end
end

result = UserValidation.call(
  name:      :invalid,
  email:     "",
  address:   "not a hash",
  profile:   { username: 12345, admin: "1" },
  interests: [1, "foo", :cooking]
)

result.input #=> { name: :invalid, email: "", address: "not a hash", profile: { username: 12345, admin: "1" }, interests: [1, "foo", :cooking] }

result.output #=> { name: "invalid", email: nil, address: "not a hash", profile: { username: "12345", admin: true }, interests: ["1", "foo", "cooking"] }
```

### Dependencies

`:dependencies` plugin provides a way to define and use dependencies in validation block.

```ruby
class UserValidation < Fend
  # ...
  plugin :validation_options

  # here, user_class is globaly defined dependency which is available in child classes also.
  plugin :dependencies, user_class: Models::User

  validate(inject: [:user_class, :address_checker]) do |i, user_class, address_checker|
    i.params(:email, :address) do |email, address|
      email.validate(type: String, format: EMAIL_REGEX)

      email.add_error("must be unique") if email.valid? && user_class.exists?(email: email.value)

      address.params(:street, :city) do |street, city|
        street.validate(type: String)
        city.validate(type: String)
      end

      address.add_error("is not a real address") if address.valid? && !address_checker.real_address?(address.value)
    end
  end

  def initialize(address_checker)
    # deps is a local dependencies registry, provided by the plugin
    deps[:address_checker] = address_checker
  end
end

user_validation = UserValidation.new(AddressChecker.new)

result = user_validation.call(email: "existing@email.com", address: { street: "Elm street", city: "Matrix" })

result.messages #=> { email: ["must be unique"], address: ["is not a real address"] }
```

### External validation

`:external_validation` plugin provides a way to delegate param validations to a class/object that responds to `call` method and returns error messages hash/array.

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
  plugin :collective_params

  validate do |i|
    i.params(:city, :street) do |city, street|
      city.validate(type: String)
      street.validate(type: String)
    end
  end
end

class UserValidation < Fend
  plugin :collective_params
  plugin :external_validation

  validate do |i|
    i.params(:email, :address) do |email, address|
      email.validate_with(CustomEmailValidation.new)

      address.validate_with(AddressValidation)
    end
  end
end
```

`validation_options` plugin supports `external_validation` which means you can do:

```ruby
 plugin :validation_options
 plugin :external_validation

 email.validate(with: CustomEmailValidation.new)
 address.validate(with: AddressValidation)
```

### Full messages

As the name says, `full_messages` provides error messages with prepended param name.

```ruby
class UserValidation < Fend
  plugin :full_messages

  # ...
end
result = UserValidation.call(email: "invalid", profile: "invalid", address: { })

result.full_messages
#=> { email: ["email is in invalid format"], profile: ["profile must be hash"], address: { city: ["city must be string"] } }
```

#### Array member support

When validating array elements, messages are returned as:

```ruby
tags: { 0 => ["0 must be string"] }
```

In order to make full messages nicer for array elements, pass an option when specifying the plugin, like so:

```ruby
plugin :full_messages, array_member_names: { tags: :tag }
```

Now full messages will look like this:

```ruby
tags: { 0 => ["tag must be string"] }
```


## Code of Conduct

Everyone interacting in the Fend project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/aradunovic/fend/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
