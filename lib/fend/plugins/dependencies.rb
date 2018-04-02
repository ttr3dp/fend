# frozen_string_literal: true

class Fend
  module Plugins
    module Dependencies
      def self.configure(validation, opts = {})
        validation.opts[:dependencies] = (validation.opts[:dependencies] || {}).merge(opts)
      end

      module ClassMethods
        attr_reader :specified_dependencies

        def validate(opts = {}, &block)
          if opts.key?(:inject)
            raise ArgumentError, ":inject option value must be an array" unless opts[:inject].is_a?(Array)

            @specified_dependencies = opts[:inject] unless opts[:inject].nil?
          end

          super(&block)
        end
      end

      module InstanceMethods
        def deps
          @_deps ||= self.class.opts[:dependencies].dup
        end

        def validate(&block)
          super if self.class.specified_dependencies.nil?

          dependencies = deps.values_at(*self.class.specified_dependencies)

          yield(@_input_param, *dependencies) if block_given?
        end
      end
    end

    register_plugin(:dependencies, Dependencies)
  end
end
