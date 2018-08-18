# frozen_string_literal: true

class Fend
  module Plugins
    # `base_errors` plugin allows you to add validation errors which are
    # not related to a specific param, but to validation input as a whole.
    #
    #     class AuthValidation < Fend
    #       plugin :base_errors
    #
    #       validate do |i|
    #         i.params(:email, :password) do |email, password|
    #           # ...
    #
    #           if email.invalid? || password.invalid?
    #             add_base_error("Invalid email or password")
    #           end
    #         end
    #       end
    #     end
    #
    # Messages are available under `:base` key by default.
    #
    #     AuthValidation.call(email: nil, password: nil).messages
    #     #=> { base: ["Invalid email or password"] }
    #
    # You can specify custom key when loading the plugin:
    #
    #     plugin :base_errors, key: :general
    module BaseErrors
      DEFAULT_KEY = :base

      def self.configure(validation, opts = {})
        validation.opts[:base_errors_key] = opts[:key] || validation.opts[:base_errors_key] || DEFAULT_KEY
      end

      module InstanceMethods
        def add_base_error(message)
          messages = @_input_param.errors
          key = self.class.opts[:base_errors_key]

          if messages.is_a?(Hash) && messages.key?(key)
            messages[key] << message
          else
            @_input_param.params(key) { |base| base.add_error(message) }
          end
        end
      end
    end

    register_plugin(:base_errors, BaseErrors)
  end
end
