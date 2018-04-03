# frozen_string_literal: true

class Fend
  module Plugins
    module ExternalValidation
      module ParamMethods
        def validate_with(validation)
          result   = validation.call(value)
          messages = result.class.ancestors.include?(Fend::Result) ? result.messages : result

          return if messages.is_a?(Hash) && flat? && invalid?

          @errors = if @errors.is_a?(Hash) && messages.is_a?(Hash)
                      _deep_merge_messages(@errors, messages)
                    elsif @errors.is_a?(Array) && messages.is_a?(Array)
                      @errors + messages
                    else
                      messages
                    end
        end

        private

        def _deep_merge_messages(hash, other_hash)
          hash.merge(other_hash) do |_, old_val, new_val|
            if old_val.is_a?(Hash) && new_val.is_a?(Hash)
              deep_merge(old_val, new_val)
            elsif old_val.is_a?(Array) && new_val.is_a?(Array)
              old_val + new_val
            else
              new_val
            end
          end
        end
      end
    end

    register_plugin(:external_validation, ExternalValidation)
  end
end
