# frozen_string_literal: true

class Fend
  # Generic error class
  class Error < StandardError; end

  # Core class that represents validation param. Class methods are added
  # by Fend::Plugins::Core::ParamClassMethods module.
  # Instance methods are added by Fend::Plugins::Core::ParamMethods module.
  class Param
    @fend_class = ::Fend
  end

  # Core class that represents validation result.
  # Class methods are added by Fend::Plugins::Core::ResultClassMethods.
  # Instance methods are added by Fend::Plugins::Core::ResultMethods.
  class Result
    @fend_class = ::Fend
  end

  @opts = {}
  @validation_block = nil

  # Module in which all Fend plugins should be defined.
  module Plugins
    @plugins = {}

    # Use plugin if already loaded. If not, load and return it.
    def self.load_plugin(name)
      unless plugin = @plugins[name]
        require "fend/plugins/#{name}"

        raise Error, "plugin #{name} did not register itself correctly in Fend::Plugins" unless plugin = @plugins[name]
      end
      plugin
    end

    # Register plugin so that it can loaded.
    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end

    # Core plugin. Provides core functionality.
    module Core
      module ClassMethods
        attr_reader :opts

        attr_reader :validation_block

        def inherited(subclass)
          subclass.instance_variable_set(:@opts, opts.dup)
          subclass.opts.each do |key, value|
            if (value.is_a?(Array) || value.is_a?(Hash)) && !value.frozen?
              subclass.opts[key] = value.dup
            end
          end

          param_class = Class.new(self::Param)
          param_class.fend_class = subclass
          subclass.const_set(:Param, param_class)

          result_class = Class.new(self::Result)
          result_class.fend_class = subclass
          subclass.const_set(:Result, result_class)
        end

        def plugin(plugin, *args, &block)
          plugin = Plugins.load_plugin(plugin) if plugin.is_a?(Symbol)
          plugin.load_dependencies(self, *args, &block) if plugin.respond_to?(:load_dependencies)

          include(plugin::InstanceMethods) if defined?(plugin::InstanceMethods)
          extend(plugin::ClassMethods) if defined?(plugin::ClassMethods)

          self::Param.send(:include, plugin::ParamMethods) if defined?(plugin::ParamMethods)
          self::Param.extend(plugin::ParamClassMethods) if defined?(plugin::ParamClassMethods)

          self::Result.send(:include, plugin::ResultMethods) if defined?(plugin::ResultMethods)
          self::Result.extend(plugin::ResultClassMethods) if defined?(plugin::ResultClassMethods)

          plugin.configure(self, *args, &block) if plugin.respond_to?(:configure)

          plugin
        end

        # Store validation block for later execution:
        #
        #   validate do |i|
        #     i.params(:foo) do |foo|
        #       # foo validation logic
        #     end
        #   end
        def validate(&block)
          @validation_block = block
        end

        def call(input)
          new.call(input)
        end

        # Prints a deprecation warning to standard error.
        def deprecation(message)
          warn "FEND DEPRECATION WARNING: #{message}"
        end
      end

      module InstanceMethods
        # Trigger data validation and return Result
        def call(raw_data)
          set_data(raw_data)
          validate(&validation_block)

          result(input: @_input_data, output: @_output_data, errors: @_input_param.errors)
        end

        # Set:
        #   * raw input data
        #   * validation input data
        #   * result output data
        #   * input param
        def set_data(raw_data)
          @_raw_data    = raw_data
          @_input_data  = process_input(raw_data) || raw_data
          @_output_data = process_output(@_input_data) || @_input_data
          @_input_param = param_class.new(:input, @_input_data)
        end

        # Returns validation block set on class level
        def validation_block
          self.class.validation_block
        end

        # Get validation param class
        def param_class
          self.class::Param
        end

        # Get validation result class
        def result_class
          self.class::Result
        end

        # Process input data
        def process_input(input); end

        # Process output data
        def process_output(output); end

        # Execute validation block
        def validate(&block)
          instance_exec(@_input_param, &block) if block_given?
        end

        # Instantiate and return result
        def result(args)
          result_class.new(args)
        end
      end

      module ParamClassMethods
        # References Fend class under which the param class is namespaced
        attr_accessor :fend_class
      end

      module ParamMethods
        # Get param value
        attr_reader :value

        # Get param name
        attr_reader :name

        # Get param validation errors
        attr_reader :errors

        def initialize(name, value)
          @name = name
          @value = value
          @errors = []
        end

        # Fetch nested value
        def [](name)
          fetch(name)
        end

        def fetch(name)
          @value.fetch(name, nil) if @value.respond_to?(:fetch)
        end

        # Define child param and execute validation block
        def param(name, &block)
          Fend.deprecation("Calling Param#param to specify params is deprecated and will not be supported in Fend 0.3.0. Use Param#params method instead.")

          return if flat? && invalid?

          value = self[name]
          param = _build_param(name, value)

          yield(param)

          _nest_errors(name, param.errors) if param.invalid?
        end

        # Define child params and execute validation block
        def params(*names, &block)
          return if flat? && invalid?

          params = names.each_with_object({}) do |name, result|
            param = _build_param(name, self[name])
            result[name] = param
          end

          yield(*params.values)

          params.each { |name, param| _nest_errors(name, param.errors) if param.invalid? }
        end

        # Define enumerable param member and execute validation block
        def each(opts = {}, &block)
          return if (flat? && invalid?) || !@value.is_a?(Enumerable)

          is_hash = opts[:hash].eql?(true)

          return if is_hash && !@value.is_a?(Hash)

          @value.each_with_index do |value, index|
            param_name, param_value = is_hash ? value : [index, value]
            param = _build_param(param_name, param_value)

            yield(param, index)

            _nest_errors(param.name, param.errors) if param.invalid?
          end
        end

        # Returns true if param is valid (no errors)
        def valid?
          errors.empty?
        end

        # Returns true if param is invalid/errors are present
        def invalid?
          !valid?
        end

        # Append param error message
        def add_error(message)
          @errors << message
        end

        def inspect
          "#{fend_class.inspect}::Param #{super}"
        end

        def to_s
          "#{fend_class.inspect}::Param #{super}"
        end

        # Return Fend class under which Param class is namespaced
        def fend_class
          self.class::fend_class
        end

        private

        def flat?
          errors.is_a?(Array)
        end

        def _nest_errors(name, messages)
          @errors = {} unless @errors.is_a?(Hash)
          @errors[name] = messages
        end

        def _build_param(*args)
          self.class.new(*args)
        end
      end

      module ResultClassMethods
        attr_accessor :fend_class
      end

      module ResultMethods
        # Get raw input data
        attr_reader :input

        # Get output data
        attr_reader :output

        def initialize(args = {})
          @input = args.fetch(:input)
          @output = args.fetch(:output)
          @errors = args.fetch(:errors)
        end

        # Get error messages
        def messages
          return {} if success?

          @errors
        end

        # Check if if validation failed
        def failure?
          !success?
        end

        # Check if if validation succeeded
        def success?
          @errors.empty?
        end

        def fend_class
          self.class.fend_class
        end

        def inspect
          "#{fend_class.inspect}::Result"
        end

        def to_s
          "#{fend_class.inspect}::Result"
        end
      end
    end
  end

  extend Fend::Plugins::Core::ClassMethods
  plugin Fend::Plugins::Core
end
