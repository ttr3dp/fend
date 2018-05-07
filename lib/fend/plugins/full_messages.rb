# frozen_string_literal: true

class Fend
  module Plugins
    # `full_messages` plugin adds `#full_messages` method to `Result` which
    # returns error messages with prependend param name.
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
    # pass `:array_member_names` option when loading the plugin:
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
    # ## Base errors
    #
    # Full messages are **not** generated for errors added with `base_errors`
    # plugin, since those messages are not connected to specific param(s).
    module FullMessages
      def self.configure(validation, opts = {})
        validation.opts[:full_messages_array_member_names] = (validation.opts[:full_messages_array_member_names] || {}).merge(opts[:array_member_names] || {})
        validation.const_set(:FullMessagesGenerator, Generator) unless validation.const_defined?(:FullMessagesGenerator)
      end

      module ResultMethods
        def full_messages
          @_full_messages ||= full_messages_generator.call(@errors)
        end

        private

        def full_messages_generator
          self.fend_class::FullMessagesGenerator.new(
            array_member_names: fend_class.opts[:full_messages_array_member_names],
            skip: [fend_class.opts[:base_errors_key]]
          )
        end
      end

      class Generator
        def initialize(opts = {})
          @array_params = opts.fetch(:array_member_names, {})
          @skip_list = opts[:skip]
        end

        def call(errors)
          errors.each_with_object({}) do |(param_name, messages), result|
            result[param_name] = if @skip_list.include?(param_name)
                                   messages
                                 else
                                   messages_for(param_name, messages)
                                 end
          end
        end

        private

        def messages_for(param, messages)
          if messages.is_a?(Hash)
            process_hash_messages(param, messages)
          else
            full_messages_for(param, messages)
          end
        end

        def process_hash_messages(param, messages)
          param_is_array = messages.first[0].is_a?(Integer)

          messages.each_with_object({}) do |(_param, msgs), result|
            param_name = if param_is_array
                           @array_params.fetch(param, _param)
                         else
                           _param
                         end

            result[_param] = messages_for(param_name, msgs)
          end
        end

        def full_messages_for(param_name, messages)
          messages.map { |message| build_full_message(param_name, message) }
        end

        def build_full_message(param_name, message)
          "#{param_name} #{message}"
        end
      end
    end

    register_plugin(:full_messages, FullMessages)
  end
end
