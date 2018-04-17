# frozen_string_literal: true

class Fend
  module Plugins
    # `external_validation` plugin allows you to delegate param validations to
    # external classes/objects.
    #
    #     plugin :external_validation
    #
    # External validation must respond to `call` method that takes param value
    # as an argument and returns error messages either as an array or hash
    # (nested data).
    #
    #     class CustomEmailValidator
    #       def initialize
    #         @errors = []
    #       end
    #
    #       def call(email_value)
    #         @errors << "must be string" unless email_value.is_a?(String)
    #         @errors << "must be unique" unless unique?(email_value)
    #
    #         @errors
    #       end
    #
    #       def unique?(value)
    #         UniquenessCheck.call(value)
    #       end
    #     end
    #
    #     class AddressValidation < Fend
    #       plugin :validation_options
    #       plugin :collective_params
    #
    #       validate do |i|
    #         i.params(:city, :street) do |city, street|
    #           city.validate(type: String)
    #           street.validate(type: String)
    #         end
    #       end
    #     end
    #
    #     class UserValidation < Fend
    #       plugin :external_validation
    #       plugin :collective_params
    #
    #       validate do |i|
    #         i.params(:email, :address) do |email, address|
    #           email.validate_with(CustomEmailValidation.new)
    #
    #           address.validate_with(AddressValidation)
    #         end
    #       end
    #     end
    #
    # `validation_options` plugin supports `external_validation`:
    #
    #     email.validate(with: CustomEmailValidation.new)
    #
    # You are free to combine internal and external validations any way you
    # like. Using one doesn't mean you can't use the other.

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
