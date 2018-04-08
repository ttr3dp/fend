# frozen_string_literal: true

class Fend
  module Plugins
    # Instead of calling ValidationHelpers::ParamMethods separately,
    # you can use `validation_options` plugin in order to specify all
    # validations as options and pass them to `Param#validate` method.
    #
    #     plugin :validation_options
    #
    #     validate do |i|
    #       i.param(:email) do |email|
    #         email.validate(presence: true, type: String, format: EMAIL_REGEX)
    #       end
    #     end
    #
    # ## Custom error messages
    #
    # Custom error messages can be defined with `:message` option:
    #
    #     email.validate(presence: { message: "cannot be blank"})
    #
    # ## Mandatory arguments
    #
    # For ValidationHelpers::ParamMethods that expect mandatory arguments, there
    # are predefined option keys that you can use. To see them all check
    # MANDATORY_ARG_KEYS constant.
    #
    #     email.validate type: { of: String, message: "is not a string" }, format: { with: EMAIL_REGEX }
    #     account_type.validate inclusion: { in: %w(admin, moderator) }
    #
    # You can also use the DEFAULT_ARG_KEY (`:value`) if you find it hard to
    # remember the specific ones.
    #
    #     email.validate type: { value: String }, format: { value: EMAIL_REGEX }
    #
    # `validation_options` supports ExternalValidation plugin:
    #
    #     plugin :external_validation
    #
    #     # ...
    #
    #     email.validate(with: CustomEmailValidator)
    module ValidationOptions
      NO_ARG_METHODS = [:absence, :presence, :acceptance].freeze
      ARRAY_ARG_METHODS = [:exclusion, :inclusion, :length_range].freeze

      DEFAULT_ARG_KEY = :value

      # List of keys to use when specifying mandatory validation arguments
      MANDATORY_ARG_KEYS = {
        equality:                 :value,
        exact_length:             :of,
        exclusion:                :from,
        format:                   :with,
        greater_than:             :value,
        greater_than_or_equal_to: :value,
        gteq:                     :value,
        inclusion:                :in,
        length_range:             :within,
        less_than:                :value,
        less_than_or_equal_to:    :value,
        lteq:                     :value,
        max_length:               :of,
        min_length:               :of,
        type:                     :of
      }.freeze

      # Depends on ValidationHelpers plugin
      def self.load_dependencies(validation, *args, &block)
        validation.plugin(:validation_helpers)
      end

      module ParamMethods
        def validate(opts = {})
          return if opts.empty?

          opts.each do |validator_name, args|
            method_name = "validate_#{validator_name}"

            raise Error, "undefined validation method '#{validator_name}'" unless respond_to?(method_name)

            if NO_ARG_METHODS.include?(validator_name)
              if !!args == args
                next unless args

                validation_method_args = []
              else
                validation_method_args = [args]
              end
            elsif args.is_a?(Hash)
              next if args[:allow_nil] == true && value.nil?
              next if args[:allow_blank] == true && blank?

              mandatory_arg_key = MANDATORY_ARG_KEYS[validator_name]

              unless args.key?(mandatory_arg_key) || args.key?(DEFAULT_ARG_KEY)
                raise Error, "missing mandatory argument for '#{validator_name}' validator"
              end

              mandatory_arg = args.delete(mandatory_arg_key) || args.delete(DEFAULT_ARG_KEY)

              validation_method_args = [mandatory_arg, args]
            else
              validation_method_args = ARRAY_ARG_METHODS.include?(validator_name) ? [args] : args
            end

            public_send(method_name, *validation_method_args)
          end
        end
      end
    end

    register_plugin(:validation_options, ValidationOptions)
  end
end
