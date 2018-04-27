# frozen_string_literal: true

class Fend
  module Plugins
    # `object_validation` plugin adds support for validating object attributes
    # and methods.
    #
    #     class UserModelValidation < Fend
    #       plugin :object_validation
    #       plugin :validation_options
    #
    #       validate do |user|
    #         user.attrs(:username, :email) do |username, email|
    #           username.validate(presence: true, max_length: 20, type: String)
    #           email.validate(presence: true, format: EMAIL_REGEX, type: String)
    #         end
    #       end
    #     end
    #
    #     user = User.new(username: "", email: "invalid@email")
    #     validation = UserModelValidation.call(user)
    #
    #     validation.success? #=> false
    #     validation.messages #=> { username: ["must be present"], email: ["is in invalid format"] }
    #
    # As the example shows, the only change is that instread of the `#params` you
    # should use `#attrs` method.
    #
    # ## Handling hash values
    #
    # If an attribute value is a hash, you can still use the `#params` method
    #
    #     # user.address #=> { city: "My city", street: "My Street" }
    #     user.attrs(:address) do |address|
    #       address.params(:city, :street) { |city, street| # ... }
    #     end
    module ObjectValidation
      module ParamMethods
        def fetch_attr_value(name)
          @value.public_send(name)
        end

        def attrs(*names, &block)
          return if flat? && invalid?

          attrs = names.each_with_object({}) do |name, result|
            attr = _build_param(name, fetch_attr_value(name))
            result[name] = attr
          end

          yield(*attrs.values)

          attrs.each { |name, attr| _nest_errors(name, attr.errors) if attr.invalid? }
        end
      end
    end

    register_plugin(:object_validation, ObjectValidation)
  end
end
