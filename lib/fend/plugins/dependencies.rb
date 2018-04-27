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
    # There are two types of dependencies:
    #
    # 1. **Inheritable dependencies** - available in current validation class
    #                                   and in subclasses
    # 2. *[DEPRECATED] **Local dependencies** - available only in current validation class
    #
    # ### Inheritable dependencies
    #
    # Inheritable dependencies can be registered when plugin is loaded:
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
    # ### Local dependencies *[DEPRECATED]
    #
    # ~~Local dependencies can be registered in `deps` registry, on instance level.
    # Recommended place to do this is the initializer.~~
    #
    #     class UserValidation < Fend
    #       plugin :dependencies
    #
    #       def initialize(model)
    #         # you can pass a dependency on initialization
    #         deps[:model] = model
    #
    #         # or
    #
    #         # hardcode it yourself
    #         deps[:address_checker] = AddressChecker.new
    #       end
    #     end
    #
    #     user_validation = UserValidation.new(User)
    #
    # You can store local dependencies by defining attributes and instance
    # methods. Since v0.2.0, instance methods are available in validation block
    #
    #     class UserValidation < Fend
    #
    #       def initialize(model)
    #         @model = model
    #       end
    #
    #       def model
    #         @model
    #       end
    #
    #       def address_checker
    #         AddressChecker.new
    #       end
    #     end
    #
    #     user_validation = UserValidation.new(User)
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
    # ## Overriding inheritable dependencies
    #
    # To override inheritable dependency, just load the plugin again in a
    # subclass, or define local dependency with the same name.
    #
    #     plugin :dependencies, user_model: SpecialUser
    #
    #     # or
    #
    #     def initialize
    #       deps[:user_model] = SpecialUser
    #     end
    #
    # ## Example usage
    #
    # Here's an example of email uniqueness validation:
    #
    #     validate(inject: [:user_model]) do |i, user_model|
    #       i.param(:email) do |email|
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
        def deps
          Fend.deprecation("Local dependencies are deprecated and will not be supported in Fend 0.3.0. Instead, you can set attributes or define custom methods which will be available in validation block.")

          @_deps ||= self.class.opts[:dependencies].dup
        end

        def validate(&block)
          super if self.class.specified_dependencies.nil?

          dependencies = deps.values_at(*self.class.specified_dependencies)

          yield(@_input_param, *dependencies) if block_given?
        end
      end
    end

    register_plugin(:dependencies, Dependencies)
  end
end
