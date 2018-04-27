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
    #         user.attr(:username) do |username|
    #           username.validate(presence: true, max_length: 20, type: String)
    #         end
    #
    #         user.attr(:email) do |email|
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
    # As the example shows, the only change is that instread of the `#param` you
    # should use `#attr` method.
    #
    # ## Collective attributes
    #
    # `object_validation` plugin supports `collective_params` plugin. You can
    # use `#attrs` method to specify multiple attributes at once.
    #
    #     # collective_params plugin needs to be specified first
    #     plugin :collective_params
    #     plugin :object_validation
    #
    #     validate do |user|
    #       user.attrs(:username, :email) do |username, email|
    #         # ...
    #       end
    #     end
    #
    # ## Handling hash values
    #
    # If an attribute value is a hash, you can use the `#param`
    # (or `#params` with `collective_params` plugin) method.
    #     # user.address #=> { city: "My city", street: "My Street" }
    #
    #     user.attr(:address) do |address|
    #       address.param(:city) { |city| # ... }
    #       address.param(:street) { |street| # ... }
    #     end
    module ObjectValidation
      def self.configure(validation)
        return if validation::Param.ancestors.map(&:to_s).grep(/CollectiveParams/).empty?

        validation::Param.send(:include, CollectiveParamsPluginExtension)
      end

      module CollectiveParamsPluginExtension
        def attrs(*names, &block)
          return if flat? && invalid?

          attrs = names.each_with_object({}) do |name, result|
            attr = _build_param(fetch_attr_value(name))
            result[name] = attr
          end

          yield(*attrs.values)

          attrs.each { |name, attr| _nest_errors(name, attr.errors) if attr.invalid? }
        end
      end

      module ParamMethods
        def fetch_attr_value(name)
          @value.public_send(name)
        end

        def attr(name, &block)
          return if flat? && invalid?

          value = fetch_attr_value(name)
          attr = _build_param(value)

          yield(attr)

          _nest_errors(name, attr.errors) if attr.invalid?
        end
      end
    end

    register_plugin(:object_validation, ObjectValidation)
  end
end
