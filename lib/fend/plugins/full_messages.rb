# frozen_string_literal: true

class Fend
  module Plugins
    # `full_messages` plugin adds `#full_messages` method to `Result` which
    # returns error messages with prependend param name
    #
    #      class UserValidation < Fend
    #        plugin :full_messages
    #
    #        # ...
    #      end
    #      result = UserValidation.call(email: "invalid", profile: "invalid", address: { })
    #
    #      result.full_messages
    #      #=> { email: ["email is in invalid format"], profile: ["profile must be hash"], address: { city: ["city must be string"] } }
    #
    # ## Array members
    #
    # When validating array elements, messages are returned with prependend
    # index, since array members don't have a name.
    #
    #      { tags: { 0 => ["0 must be string"] } }
    #
    # In order to make full messages nicer for array elements,
    # pass `:array_memeber_names` option when loading the plugin:
    #
    #      plugin :full_messages, array_member_names: { tags: :tag }
    #
    #      # which will produce
    #      { tags: { 0 => ["tag must be string"] } }
    #
    # `:array_member_names` options is inheritable, so it's possible to define
    # it globaly by loading the plugin directly through `Fend` class.
    #
    #     Fend.plugin :full_messages, array_member_names: { octopi: :octopus }
    #
    module FullMessages
      def self.configure(validation, opts = {})
        validation.opts[:full_messages_array_member_names] = (validation.opts[:full_messages_array_member_names] || {}).merge(opts[:array_member_names] || {})
      end

      module ResultMethods
        def full_messages
          @_full_messages ||= generate_full_messages(@errors)
        end

        private

        def generate_full_messages(errors, array_param_name = nil)
          errors.each_with_object({}) do |(param, messages), result|
            result[param] = if messages.is_a?(Hash)
                              param_is_array = messages.first[0].is_a?(Integer)

                              generate_full_messages(messages, param_is_array ? param : nil)
                            else
                              param_name = fend_class.opts[:full_messages_array_member_names].fetch(array_param_name, param)
                              messages.map { |message| "#{param_name} #{message}"}
                            end
          end
        end
      end
    end

    register_plugin(:full_messages, FullMessages)
  end
end
