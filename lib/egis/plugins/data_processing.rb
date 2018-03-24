# frozen_string_literal: true

class Egis
  module Plugins
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
