# frozen_string_literal: true

class Fend
  module Plugins
    module Dependencies
      def self.configure(validation, opts = {})
        validation.opts[:dependencies] = (validation.opts[:dependencies] || {}).merge(opts)
      end

      module ClassMethods
        attr_reader :requested_dependencies

        def validate(opts = {}, &block)
          if opts.key?(:inject)
            raise ArgumentError, ":inject option value must be an array" unless opts[:inject].is_a?(Array)

            @requested_dependencies = opts[:inject] unless opts[:inject].nil?
          end

          super(&block)
        end
      end

      module InstanceMethods
        def deps
          @_deps ||= self.class.opts[:dependencies]
        end

        def validate
          super if self.class.requested_dependencies.nil?

          args = [@_root_param, *deps.values_at(*self.class.requested_dependencies)]

          @_root_param.instance_exec(*args, &validation_block)
        end
      end
    end

    register_plugin(:dependencies, Dependencies)
  end
end
