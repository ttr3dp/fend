# frozen_string_literal: true

class Fend
  module Plugins
    # `dependencies` plugin enables you to register validation dependencies and
    # later resolve them so they would be available in validation block
    #
    #     plugin :dependencies
    #
    # ## Registering dependencies
    #
    # Dependencies can be registered when plugin is loaded:
    #
    #     plugin :dependencies, user_class: User
    #
    # **Global dependencies** can be registered by loading the plugin directly in
    # `Fend` class:
    #
    #     require "address_checker"
    #
    #     Fend.plugin :dependencies, address_checker: AddressChecker.new
    #
    # Now, all `Fend` subclasses will be able to resolve `address_checker`
    #
    # ## Resolving dependencies
    #
    # To resolve dependencies, `:inject` option needs to be provided to the
    # `validate` method, with a list of keys representing dependency names:
    #
    #     class UserValidation < Fend
    #       plugin :dependencies, user_model: User
    #
    #       validate(inject: [:user_model]) do |i, user_model|
    #         user_model #=> User
    #         address_checker #=> #<AddressChecker ...>
    #       end
    #
    #       def initialize(address_checker)
    #         @address_checker = address_checker
    #       end
    #
    #       def address_checker
    #         @address_checker
    #       end
    #     end
    #
    # ## Overriding dependencies
    #
    # To override global dependency, just load the plugin again in a subclass
    # and specify new dependecy value.
    #
    #     plugin :dependencies, user_model: SpecialUser
    #
    # ## Example usage
    #
    # Here's an example of email uniqueness validation:
    #
    #     validate(inject: [:user_model]) do |i, user_model|
    #       i.params(:email) do |email|
    #         email.add_error("must be unique") if user_model.exists?(email: email.value)
    #       end
    #     end
    module Dependencies
      def self.configure(validation, opts = {})
        validation.opts[:dependencies] = (validation.opts[:dependencies] || {}).merge(opts)
      end

      module ClassMethods
        attr_reader :specified_dependencies

        def validate(opts = {}, &block)
          if opts.key?(:inject)
            raise ArgumentError, ":inject option value must be an array" unless opts[:inject].is_a?(Array)

            @specified_dependencies = opts[:inject] unless opts[:inject].nil?
          end

          super(&block)
        end
      end

      module InstanceMethods
        def validate(&block)
          super if self.class.specified_dependencies.nil?

          dependencies = self.class.opts[:dependencies].values_at(*self.class.specified_dependencies)

          yield(@_input_param, *dependencies) if block_given?
        end
      end
    end

    register_plugin(:dependencies, Dependencies)
  end
end
