# frozen_string_literal: true

class Fend
  module Plugins
    # `contexts` plugin adds support for contextual validation, which basically
    # means you can branch validation logic depending on provided context.
    #
    #     class UserValidation < Fend
    #       plugin :contexts
    #
    #       validate do |i|
    #         i.param(:account_type) do |acc_type|
    #           context(:admin) do
    #             acc_type.validate_equality("admin")
    #           end
    #
    #           context(:editor) do
    #             acc_type.validate_equality("editor")
    #           end
    #
    #           # you can check context against multiple values
    #           context(:visitor, :demo) do
    #             acc_type.validate_equality(nil)
    #           end
    #         end
    #       end
    #     end
    #
    # You can pass the context on initialization
    #
    #     user_validation = UserValidation.new(context: :editor)
    #     user_validation.call(account_type: "invalid").messages
    #     #=> { account_type: ["must be equal to 'editor'"] }
    #
    # `#context` can be called anywhere in the validation block. You can also
    # specify contextual params
    #
    #     validate do |i|
    #       context(:admin) do
    #         i.param(:admin_specific_param) do |asp|
    #           # ...
    #         end
    #       end
    #
    #       context(:editor) do
    #         i.param(:editor_specific_param) do |esp|
    #           # ...
    #         end
    #       end
    #     end
    #
    # ## Default context
    #
    # If no context is provided, context will be set to `:default`
    #
    #     context(:default) do
    #       # default validation logic
    #     end
    #
    # ## Overriding constructor
    #
    # Since context value is set in the constructor, you should always call
    # `super` when/if overriding it.
    module Contexts
      module InstanceMethods
        def initialize(*args)
          opts = if (_opts = args.last) && _opts.is_a?(Hash)
                   _opts
                 else
                   {}
                 end

          @_context = opts.fetch(:context, :default)
        end

        def context(*values, &block)
          values = Array(values)

          yield if values.include?(@_context)
        end
      end
    end

    register_plugin(:contexts, Contexts)
  end
end
