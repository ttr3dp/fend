# frozen_string_literal: true

require "bigdecimal"

class Fend
  module Plugins
    module ValueHelpers
      module ParamMethods
        def dig(*path)
          result = value

          path.each do |point|
            break if result.is_a?(Array) && !point.is_a?(Integer)

            result = result.is_a?(Enumerable) ? result[point] : nil

            break if result.nil?
          end

          result
        end

        def present?
          !blank?
        end

        def blank?
          case value
          when Array, Hash
            value.empty?
          when NilClass, FalseClass
            true
          when Integer, Float, Numeric, Time, TrueClass, Symbol
            false
          when String
            empty_string?
          else
            value.respond_to?(:empty?) ? !!value.empty? : !value
          end
        end

        def empty_string?
          return false unless value.is_a?(String) || value.is_a?(Symbol)

          /\A[[:space:]]*\z/.match?(value)
        end

        def type_of?(type_ref)
          return value.is_a?(type_ref) unless type_ref.is_a?(String) || type_ref.is_a?(Symbol)

          case type_ref.to_s
          when "boolean" then !!value == value
          when "decimal" then value.is_a?(Float) || value.is_a?(BigDecimal)
          when "nil" then value.is_a?(NilClass)
          else
            camelized_type_ref = type_ref.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:\A|_)(.)/) { $1.upcase }
            type_class = Object.const_get(camelized_type_ref)

            value.is_a?(type_class)
          end
        end
      end
    end

    register_plugin(:value_helpers, ValueHelpers)
  end
end
