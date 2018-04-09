# frozen_string_literal: true

class Fend
  module Plugins
    # By default, Fend provides methods for input and output processing.
    #
    #     class UserValidation < Fend
    #       #...
    #
    #       def process_input(input)
    #         # symbolize input data keys
    #         symbolized_input = input.each_with_object({}) do |(key, value), result|
    #           new_key = key.is_a?(String) ? key.to_sym : key
    #           result[new_key] = value
    #         end
    #
    #         # do some additional processing
    #       end
    #
    #       def process_output(output)
    #         # filter output data
    #         whitelist = [:username, :email, :address]
    #         filtered_output = output.each_with_object({}) do |(key, value), result|
    #           result[key] = value if whitelist.include?(key)
    #         end
    #
    #         # do some additional processing
    #       end
    #     end
    #
    # `data_processing` plugin allows you to define processing steps in more
    #  declarative manner:
    #
    #     plugin :data_processing
    #
    #     process(:input) do |input|
    #       # symbolize keys
    #     end
    #
    #     process(:output) do |output|
    #       # filter
    #     end
    #
    # You can define as much processing steps as you want and they will be
    # executed in order in which they are defined.
    #
    # ## Built-in processings
    #
    # `data_processing` plugin comes with some built-in processings that you can
    # specify when loading the plugin:
    #
    #     # this will:
    #     #   symbolize and freeze input data
    #     #   stringify output data
    #     plugin :data_processing, input: [:symbolize, :freeze],
    #                              output: [:stringify]
    #
    # :symbolize
    # : Symbolizes keys.
    #
    # :stringify
    # : Stringifies keys
    #
    # :dup
    # : Duplicates data
    #
    # :freeze
    # : Freezes data
    #
    # All of the specified processings support deeply nested data.
    #
    # Built-in processings are executed **before** any
    # user-defined ones.
    #
    # ## Data mutation
    #
    # Fend will never mutate the raw input data you provide:
    #
    #     raw_input = { username: "john", email: "john@example.com" }
    #     UserValidation.call(raw_input)
    #
    # However, nothing can stop you from performing destructive operations
    # (`merge!`, `delete`, etc...) in custom processing steps.
    #
    # If you intend to mutate the input data, please specify `:dup` built-in
    # processing on `:input`. This is not needed if you already use some of the
    # built-in processings, since they all return **new** data.
    #
    # The reason for this is that input is later used as the validation
    # result output. This may lead to a situation when you mutate the output
    # which can cause for result input to be changed also. Although a lot of
    # things would need to align for this to happen, it's better to protect the
    # data right away.
    #
    # If you want to ensure that no one will mutate the data, use
    # `:freeze` processing.
    module DataProcessing
      BUILT_IN_PROCESSINGS = {
        symbolize:   ->(data) { Process.symbolize_keys(data) },
        stringify:   ->(data) { Process.stringify_keys(data) },
        dup:         ->(data) { Process.duplicate(data) },
        freeze:      ->(data) { Process.frost(data) }
      }.freeze

      def self.configure(validation, options = {})
        validation.opts[:data_processing] = {}
        validation.opts[:data_processing][:input] ||= []
        validation.opts[:data_processing][:output] ||= []

        return if options.empty?

        options.each do |data_ref, processings|
          processings.each_with_object(validation.opts[:data_processing][data_ref]) do |name, result|
            raise Error, "Built-in processing not found: ':#{name}'" unless BUILT_IN_PROCESSINGS.key?(name)

            result << BUILT_IN_PROCESSINGS[name]
          end
        end
      end

      module ClassMethods
        def process(data_key, &block)
          opts[:data_processing][data_key] ||= []
          opts[:data_processing][data_key] << block
        end
      end

      module InstanceMethods
        def process_input(data)
          super
          process_data(:input, data)
        end

        def process_output(data)
          super
          process_data(:output, data)
        end

        private

        def process_data(key, data)
          result = data

          self.class.opts[:data_processing][key].each do |process_block|
            result = instance_exec(result, &process_block)
          end

          result
        end
      end

      class Process
        HASH_OR_ARRAY = ->(a) { a.is_a?(Hash) || a.is_a?(Array) }.freeze
        NESTED_ARRAY  = ->(a) { a.is_a?(Array) && a.any? { |member| HASH_OR_ARRAY[member] } }.freeze
        NESTED_HASH   = ->(a) { a.is_a?(Hash)  && a.any? { |_, value| HASH_OR_ARRAY[value] } }.freeze

        def self.symbolize_keys(data)
          return data unless HASH_OR_ARRAY[data]

          transformation = ->(key) { key.is_a?(String) ? key.to_sym : key }

          deep_transform_keys(data, transformation)
        end

        def self.stringify_keys(data)
          return data unless HASH_OR_ARRAY[data]

          transformation = ->(key) { key.is_a?(Symbol) ? key.to_s : key }

          deep_transform_keys(data, transformation)
        end

        def self.duplicate(data, opts = {})
          return data unless HASH_OR_ARRAY[data]

          case data
          when NESTED_HASH
            data.each_with_object({}) { |(key, value), result| result[key] = duplicate(value) }
          when NESTED_ARRAY
            data.map(&method(:duplicate))
          when HASH_OR_ARRAY
            data.dup
          else
            data
          end
        end

        def self.frost(data)
          return data unless HASH_OR_ARRAY[data]

          case data
          when NESTED_HASH
            data.each_with_object({}) { |(key, value), result| result[key] = frost(value) }.freeze
          when NESTED_ARRAY
            data.map(&method(:frost)).freeze
          when HASH_OR_ARRAY
            data.dup.freeze
          else
            data
          end
        end

        private

        def self.deep_transform_keys(data, key_proc)
          case data
          when Hash
            data.each_with_object({}) do |(key, value), result|
              _key = key_proc[key]

              result[_key] = deep_transform_keys(value, key_proc)
            end
          when NESTED_ARRAY
            data.map { |member| deep_transform_keys(member, key_proc) }
          else
            data
          end
        end
      end
    end

    register_plugin(:data_processing, DataProcessing)
  end
end
