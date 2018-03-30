# frozen_string_literal: true

class Fend
  module Plugins
    DEFAULT_MESSAGES = {
      absence:                  -> { "must be absent" },
      acceptance:               -> { "must be accepted" },
      confirmation:             -> { "must be confirmed" },
      equality:                 ->(value) { "must be equal to '#{value}'" },
      exact_length:             ->(length) { "length must be equal to #{length}" },
      exclusion:                ->(list) { "cannot be one of: #{list.join(', ')}" },
      format:                   -> { "is in invalid format" },
      greater_than:             ->(value) { "must be greater than #{value}" },
      greater_than_or_equal_to: ->(value) { "must be greater than or equal to #{value}" },
      inclusion:                ->(list) { "must be one of: #{list.join(', ')}" },
      length_range:             ->(range) { "length must be between #{range.min} and #{range.max}" },
      less_than:                ->(value) { "must be less than #{value}" },
      less_than_or_equal_to:    ->(value) { "must be less than or equal to #{value}" },
      max_length:               ->(value) { "length cannot be greater than #{value}" },
      min_length:               ->(value) { "length cannot be less than #{value}" },
      presence:                 -> { "must be present" },
      type:                     ->(type) { "must be #{type.to_s.downcase}" }
    }.freeze

    ACCEPTABLE       = [1, "1", true, "true", "TRUE", :yes, "YES", "yes"].freeze
    UNSUPPORTED_TYPE = "__unsupported_type__".freeze

    module ValidationHelpers
      def self.load_dependencies(validation, *args, &block)
        validation.plugin(:value_helpers)
      end

      def self.configure(validation, opts = {})
        validation.opts[:validation_default_messages] = (validation.opts[:validation_default_messages] || {}).merge(opts[:default_messages] || {})
      end

      module ParamClassMethods
        def default_messages
          @default_messages ||= DEFAULT_MESSAGES.merge(fend_class.opts[:validation_default_messages])
        end
      end

      module ParamMethods
        def validate_absence(opts = {})
          add_error(:absence, opts[:message]) if present?
        end

        def validate_acceptance(opts = {})
          as = Array(opts.fetch(:as, ACCEPTABLE))

          add_error(:acceptance, opts[:message]) unless as.include?(value)
        end

        def validate_equality(rhs, opts = {})
          add_error(:equality, opts[:message], rhs) unless value.eql?(rhs)
        end

        def validate_exact_length(exact_length, opts = {})
          value_length = value.respond_to?(:length) ? value.length : UNSUPPORTED_TYPE

          return if !value_length.eql?(UNSUPPORTED_TYPE) && value_length.eql?(exact_length)

          add_error(:exact_length, opts[:message], exact_length)
        end

        def validate_exclusion(exclude_from, opts = {})
          add_error(:exclusion, opts[:message], exclude_from) if exclude_from.include?(value)
        end

        def validate_format(format, opts = {})
          add_error(:format, opts[:message]) unless format.match?(value.to_s)
        end

        def validate_greater_than(rhs, opts = {})
          add_error(:greater_than, opts[:message], rhs) unless value.is_a?(Numeric) && value > rhs
        end

        def validate_greater_than_or_equal_to(rhs, opts = {})
          add_error(:greater_than_or_equal_to, opts[:message], rhs) unless value.is_a?(Numeric) && value >= rhs
        end
        alias_method :validate_gteq, :validate_greater_than_or_equal_to

        def validate_inclusion(include_in, opts = {})
          add_error(:inclusion, opts[:message], include_in) unless include_in.include?(value)
        end

        def validate_length_range(range, opts = {})
          value_length = value.respond_to?(:length) ? value.length : UNSUPPORTED_TYPE

          return if !value_length.eql?(UNSUPPORTED_TYPE) && range.include?(value_length)

          add_error(:length_range, opts[:message], range)
        end

        def validate_less_than(rhs, opts = {})
          add_error(:less_than, opts[:message], rhs) unless value.is_a?(Numeric) && value < rhs
        end

        def validate_less_than_or_equal_to(rhs, opts = {})
          add_error(:less_than_or_equal_to, opts[:message], rhs) unless value.is_a?(Numeric) && value <= rhs
        end
        alias_method :validate_lteq, :validate_less_than_or_equal_to

        def validate_max_length(length, opts = {})
          value_length = value.respond_to?(:length) ? value.length : UNSUPPORTED_TYPE

          return if !value_length.eql?(UNSUPPORTED_TYPE) && value_length <= length

          add_error(:max_length, opts[:message], length)
        end

        def validate_min_length(length, opts = {})
          value_length = value.respond_to?(:length) ? value.length : UNSUPPORTED_TYPE

          return if !value_length.eql?(UNSUPPORTED_TYPE) && value_length >= length

          add_error(:min_length, opts[:message], length)
        end

        def validate_presence(opts = {})
          add_error(:presence, opts[:message]) if blank?
        end

        def validate_type(type, opts = {})
          add_error(:type, opts[:message], type) unless type_of?(type)
        end

        def add_error(*args)
          if args.size == 1 && args.first.is_a?(String)
            super(*args)
          else
            @errors << error_message(*args)
          end
        end

        def error_message(type, message, *args)
          message ||= self.class.default_messages.fetch(type)
          message.is_a?(String) ? message : message.call(*args)
        end
      end
    end

    register_plugin(:validation_helpers, ValidationHelpers)
  end
end
