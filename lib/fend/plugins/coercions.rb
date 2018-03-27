# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

require "date"
require "time"

class Fend
  module Plugins
    module Coercions
      class CoercionError < Error; end

      def self.configure(validation, opts = {}, &block)
        validation.const_set(:Coerce, Class.new(Fend::Plugins::Coercions::Coerce)) unless validation.const_defined?(:Coerce)
        validation::Coerce.class_eval(&block) if block_given?
        validation.opts[:coercions_strict_error_message] = opts.fetch(:strict_error_message, validation.opts[:coercions_strict_error_message])
        validation::Coerce.fend_class = validation

        validation.const_set(:Coercer, Coercer) unless validation.const_defined?(:Coercer)
      end


      module ClassMethods
        attr_accessor :type_schema

        def inherited(subclass)
          super
          coerce_class = Class.new(self::Coerce)
          coerce_class.fend_class = subclass
          subclass.const_set(:Coerce, coerce_class)
        end

        def coerce(type_schema_hash)
          @type_schema = type_schema_hash
        end
      end


      module InstanceMethods
        def type_schema
          schema = self.class.type_schema

          return {} if schema.nil?

          raise Error, "type schema must be hash" unless schema.is_a?(Hash)

          schema
        end

        def process_input(data)
          data = super || data
          coerce(data)
        end

        private

        def coerce(data)
          coercer.call(data, type_schema)
        end

        def coercer
          @_coercer ||= Coercer.new(self.class::Coerce.new)
        end
      end

      class Coercer
        attr_reader :coerce

        def initialize(coerce)
          @coerce = coerce
        end

        def call(data, schema)
          data.each_with_object({}) do |(name, value), result|
            type = schema[name]

            result[name] = coerce_value(type, value)
          end
        end

        private

        def coerce_value(type, value)
          case type
          when NilClass then value
          when Hash     then process_hash(value, type)
          when Array    then process_array(value, type.first)
          else
            coerce.to(type, value)
          end
        end

        def process_hash(input, schema)
          coerced_value = coerce_value(:hash, input)

          return coerced_value unless coerced_value.is_a?(Hash)

          call(coerced_value, schema)
        end

        def process_array(input, member_schema)
          coerced_value = coerce_value(:array, input)

          return coerced_value unless coerced_value.is_a?(Array)

          coerced_value.each_with_object([]) do |member, result|
            value = member
            type  = member_schema.is_a?(Array) ? member_schema.first : member_schema

            coerced_member_value = coerce_value(type, value)

            next if coerced_member_value.nil?

            result << coerced_member_value
          end
        end
      end

      class Coerce
        STRICT_PREFIX = "strict_".freeze

        @fend_class = Fend

        class << self
          attr_accessor :fend_class
        end

        def self.coerce_to(type, &block)
          method_name = "to_#{type}"

          define_method(method_name, &block)

          private method_name
        end

        def self.to(type, value)
          new.to(type, value)
        end

        def to(type, value, opts = {})
          type = type.to_s.sub(STRICT_PREFIX, "") if is_strict = type.to_s.start_with?(STRICT_PREFIX)

          begin
            method("to_#{type}").call(value)
          rescue ArgumentError, TypeError
           is_strict ? raise_error(value, type) : value
          end
        end

        private

        def to_any(input)
          return if empty_string?(input)

          input
        end

        def to_string(input)
          return if empty_string?(input) || input.nil?

          case input
          when String then input
          when Numeric, Symbol then input.to_s
          else
            raise ArgumentError
          end
        end

        def to_symbol(input)
          return if empty_string?(input) || input.nil?

          return input.to_sym if input.respond_to?(:to_sym)

          raise ArgumentError
        end

        def to_integer(input)
          return if empty_string?(input)

          ::Kernel.Integer(input)
        end

        def to_float(input)
          return if empty_string?(input)

          ::Kernel.Float(input)
        end

        def to_decimal(input)
          return if empty_string?(input)

          to_float(input).to_d
        end

        def to_date(input)
          return if empty_string?(input)

          ::Date.parse(input)
        end

        def to_date_time(input)
          return if empty_string?(input)

          ::DateTime.parse(input)
        end

        def to_time(input)
          return if empty_string?(input)

          ::Time.parse(input)
        end

        def to_boolean(input)
          return if empty_string?(input)

          case input
          when true, 1, /\A(?:1|t(?:rue)?|y(?:es)?|on)\z/i then true
          when false, 0, /\A(?:0|f(?:alse)?|no?|off)\z/i then false
          else
            raise ArgumentError
          end
        end

        def to_array(input)
          return []    if empty_string?(input)
          return input if input.is_a?(Array)

          raise ArgumentError
        end

        def to_hash(input)
          return {}    if empty_string?(input)
          return input if input.is_a?(Hash)

          raise ArgumentError
        end

        private

        def raise_error(input, type)
          message = fend_class.opts[:coercions_strict_error_message] || "cannot coerce #{input.inspect} to #{type}"
          message = message.is_a?(String) ? message : message.call(input, type)

          raise CoercionError, message
        end

        def empty_string?(input)
          return false unless input.is_a?(String) || input.is_a?(Symbol)

          /\A[[:space:]]*\z/.match?(input)
        end

        def fend_class
          self.class.fend_class
        end
      end
    end

    register_plugin(:coercions, Coercions)
  end
end
