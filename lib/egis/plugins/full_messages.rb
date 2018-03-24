# frozen_string_literal: true

class Egis
  module Plugins
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
                              param_name = egis_class.opts[:full_messages_array_member_names].fetch(array_param_name, param)
                              messages.map { |message| "#{param_name} #{message}"}
                            end
          end
        end
      end
    end

    register_plugin(:full_messages, FullMessages)
  end
end
