# frozen_string_literal: true

class Fend
  module Plugins
    module ValidationOptions
      NO_ARG_METHODS = [:absence, :presence, :acceptance].freeze
      ARRAY_ARG_METHODS = [:exclusion, :inclusion, :length_range].freeze

      DEFAULT_ARG_KEY = :value
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
