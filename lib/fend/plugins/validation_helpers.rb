# frozen_string_literal: true

class Fend
  module Plugins
    # `validation_helpers` plugin provides additional `Param` methods for common
    # validation cases.
    #
    #     plugin :validation_helpers
    #
    #     validate do |i|
    #       i.param(:username) do |username|
    #         username.validate_presence
    #         username.validate_max_length(20)
    #         username.validate_type(String)
    #       end
    #     end
    #
    # You can find list of all available helpers in ParamMethods.
    #
    # ## Overriding default messages
    #
    # You can override default messages by specifying `:default_messages`
    # options when loading the plugin
    #
    #     plugin :validation_helpers, default_messages: {
    #       exact_length: ->(length) { I18n.t("errors.exact_length", length: length) },
    #       presence: "cannot be blank",
    #       type: ->(type) { "is not of valid type. Must be #{type.to_s.downcase}" }
    #     }
    #
    # Custom messages can be defined by passing `:message` option to validation
    # helper method:
    #
    #     username.validate_max_length(20, message: "must be shorter than 20 chars")

    module ValidationHelpers
      # depends on ValueHelpers plugin, which provides methods that are used in
      # certain validation helpers
      def self.load_dependencies(validation, *args, &block)
        validation.plugin(:value_helpers)
      end

      def self.configure(validation, opts = {})
        validation.opts[:validation_default_messages] = (validation.opts[:validation_default_messages] || {}).merge(opts[:default_messages] || {})
      end

      DEFAULT_MESSAGES = {
        absence:                  -> { "must be absent" },
        acceptance:               -> { "must be accepted" },
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

      module ParamClassMethods
        def default_messages
          @default_messages ||= DEFAULT_MESSAGES.merge(fend_class.opts[:validation_default_messages])
        end
      end

      module ParamMethods
        # Validates that param value is blank. To see what values are considered
        # as blank, check ValueHelpers::ParamMethods#blank?.
        #
        #     id.validate_absence
        def validate_absence(opts = {})
          add_error(:absence, opts[:message]) if present?
        end

        # Validates acceptance. Potential use case would be checking if Terms of
        # Service has been accepted.
        #
        # By default, validation will pass if value is one of:
        # `[1, "1", :true, true, "true", "TRUE", :yes, "YES", "yes"]`
        #
        # You can pass the `:as` option with custom list of acceptable values:
        #
        #     tos.validate_acceptance(as: ["Agreed", "OK"])
        def validate_acceptance(opts = {})
          as = Array(opts.fetch(:as, ACCEPTABLE))

          add_error(:acceptance, opts[:message]) unless as.include?(value)
        end

        # Validates that param value is equal to the specified value.
        #
        #     color.validate_equality("black")
        def validate_equality(rhs, opts = {})
          add_error(:equality, opts[:message], rhs) unless value.eql?(rhs)
        end

        # Validates that param value length is equal to the specified value.
        # Works with any object that responds to `#length` method.
        #
        #     code.validate_exact_length(10)
        def validate_exact_length(exact_length, opts = {})
          value_length = value.respond_to?(:length) ? value.length : UNSUPPORTED_TYPE

          return if !value_length.eql?(UNSUPPORTED_TYPE) && value_length.eql?(exact_length)

          add_error(:exact_length, opts[:message], exact_length)
        end

        # Validates that param value is not one of the specified values.
        #
        #     account_type.validate_exclusion(["admin", "editor"])
        def validate_exclusion(exclude_from, opts = {})
          add_error(:exclusion, opts[:message], exclude_from) if exclude_from.include?(value)
        end

        # Validates that param value is a match for specified regex.
        #
        #     name.validate_format(/\A[a-z]\z/i)
        def validate_format(format, opts = {})
          add_error(:format, opts[:message]) unless format.match?(value.to_s)
        end

        # Validates that param value is greater than specified value
        #
        #     age.validate_greater_than(18)
        def validate_greater_than(rhs, opts = {})
          add_error(:greater_than, opts[:message], rhs) unless value.is_a?(Numeric) && value > rhs
        end

        # Validates that param value is greater than or equal to specified value
        #
        #     age.validate_greater_than_or_equal_to(18)
        #
        # Aliased as `validate_gteq`
        #
        #     age.validate_gteq(10)
        def validate_greater_than_or_equal_to(rhs, opts = {})
          add_error(:greater_than_or_equal_to, opts[:message], rhs) unless value.is_a?(Numeric) && value >= rhs
        end
        alias_method :validate_gteq, :validate_greater_than_or_equal_to

        # Validates that param value is one of the specified values.
        #
        #     account_type.validate_inclusion(["admin", "editor"])
        def validate_inclusion(include_in, opts = {})
          add_error(:inclusion, opts[:message], include_in) unless include_in.include?(value)
        end

        # Validates that param value length is within specified range
        #
        #     code.validate_length_range(10..15)
        def validate_length_range(range, opts = {})
          value_length = value.respond_to?(:length) ? value.length : UNSUPPORTED_TYPE

          return if !value_length.eql?(UNSUPPORTED_TYPE) && range.include?(value_length)

          add_error(:length_range, opts[:message], range)
        end

        # Validates that param value is less than specified value
        #
        #     funds.validate_less_than(100)
        def validate_less_than(rhs, opts = {})
          add_error(:less_than, opts[:message], rhs) unless value.is_a?(Numeric) && value < rhs
        end

        # Validates that param value is less than or equal to specified value
        #
        #     funds.validate_less_than_or_equal_to(100)
        #
        # Aliased as `validate_lteq`
        #
        #     funds.validate_lteq(100)
        def validate_less_than_or_equal_to(rhs, opts = {})
          add_error(:less_than_or_equal_to, opts[:message], rhs) unless value.is_a?(Numeric) && value <= rhs
        end
        alias_method :validate_lteq, :validate_less_than_or_equal_to

        # Validates that param value length is not greater than specified value
        #
        #     password.validate_max_length(15)
        def validate_max_length(length, opts = {})
          value_length = value.respond_to?(:length) ? value.length : UNSUPPORTED_TYPE

          return if !value_length.eql?(UNSUPPORTED_TYPE) && value_length <= length

          add_error(:max_length, opts[:message], length)
        end

        # Validates that param value length is not less than specified value
        #
        #     password.validate_min_length(5)
        def validate_min_length(length, opts = {})
          value_length = value.respond_to?(:length) ? value.length : UNSUPPORTED_TYPE

          return if !value_length.eql?(UNSUPPORTED_TYPE) && value_length >= length

          add_error(:min_length, opts[:message], length)
        end

        # Validates that param value is present. To see what values are
        # considered as present, check ValueHelpers::ParamMethods#present?
        #
        #     name.validate_presence
        def validate_presence(opts = {})
          add_error(:presence, opts[:message]) if blank?
        end

        # Uses ValueHelpers::ParamMethods#type_of? method to validate that
        # param value is of specified type.
        #
        #     tags.validate_type(Array)
        def validate_type(type, opts = {})
          add_error(:type, opts[:message], type) unless type_of?(type)
        end

        # :nodoc:
        def add_error(*args)
          if args.size == 1 && args.first.is_a?(String)
            super(*args)
          else
            @errors << error_message(*args)
          end
        end

        private

        def error_message(type, message, *args)
          message ||= self.class.default_messages.fetch(type)
          message.is_a?(String) ? message : message.call(*args)
        end
      end
    end

    register_plugin(:validation_helpers, ValidationHelpers)
  end
end
