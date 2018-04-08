# frozen_string_literal: true

require "bigdecimal"

class Fend
  module Plugins
    # `value_helpers` plugin provides helper methods that you can use to
    # check/fetch param values.
    #
    #     plugin :value_helpers
    #
    #     validate do |i|
    #       i.param(:username) do |username|
    #         username.present? #=> true
    #         username.blank? #=> false
    #         username.empty_string? #=> false
    #       end
    #     end
    #
    # For a complete list of available methods, see ParamMethods.
    module ValueHelpers
      module ParamMethods
        # Returns `true` when:
        #
        # * `value.empty?`
        # * `value.nil?`
        # * `value == false`
        # * `value.empty_string?`
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

        # Enables easier fetching of nested data values.
        # Works with hashes and arrays.
        #
        #     validate do |i|
        #       # { user: { address: { city: "Amsterdam" } } }
        #       i.dig(:user, :address, :city) #=> "Amsterdam"
        #       i.dig(:user, :profile, :username) #=> nil
        #
        #       # { tags: [ { id: 2, name: "JS" }, { id: 3, name: "Ruby" }] }
        #       i.dig(:tags, 1, :name) #=> "Ruby"
        #       i.dig(:tags, 5, :id) #=> nil
        #
        #       i.param(:accounts) do |accounts|
        #         accounts.dig(0, :transactions, 3) #=> "$100.00"
        #       end
        #     end
        def dig(*path)
          result = value

          path.each do |point|
            break if result.is_a?(Array) && !point.is_a?(Integer)

            result = result.is_a?(Enumerable) ? result[point] : nil

            break if result.nil?
          end

          result
        end

        # Returns `true` when value is an empty string (_space_, _tab_, _newline_,
        # _carriage_return_, etc...)
        #
        #     # email.value #=> ""
        #     # email.value #=> "   "
        #     # email.value #=> "\n"
        #     # email.value #=> "\r"
        #     # email.value #=> "\t"
        #     # email.value #=> "\n\r\t"
        #
        #     email.empty_string? #=> true
        def empty_string?
          return false unless value.is_a?(String) || value.is_a?(Symbol)

          /\A[[:space:]]*\z/.match?(value)
        end

        # Returns `true` if value is present/not blank
        def present?
          !blank?
        end

        # Returns `true` if value is of specified type. Accepts constants, their
        # string representations and symbols:
        #
        #     email.type_of?(String)
        #
        #     # or
        #
        #     email.type_of?("string")
        #
        #     # or
        #
        #     email.type_of?(:string)
        #
        # Additional examples:
        #
        #     # these are all checking the same thing
        #     user.type_of?(AdminUser)
        #     user.type_of?(:admin_user)
        #     user.type_of?("admin_user")
        #
        # Provides a convenient way for checking if value is boolean, decimal or
        # nil:
        #
        #     # true if value is TrueClass or FalseClass
        #     confirmed.type_of?(:boolean)
        #
        #     # true if value is Float or BigDecimal
        #     amount.type_of?(:decimal)
        #
        #     # true if value is nil/NilClass
        #     email.type_of?(:nil)
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
