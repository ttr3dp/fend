# frozen_string_literal: true

class Fend
  class Error < StandardError; end

  class Param
    @fend_class = ::Fend
  end

  class Result
    @fend_class = ::Fend
  end

  @opts = {}
  @validation_block = nil

  module Plugins
    @plugins = {}

    def self.load_plugin(name)
      unless plugin = @plugins[name]
        require "fend/plugins/#{name}"

        raise Error, "plugin #{name} did not register itself correctly in Fend::Plugins" unless plugin = @plugins[name]
      end
      plugin
    end

    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end

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

          input_class = Class.new(self::Param)
          input_class.fend_class = subclass
          subclass.const_set(:Param, input_class)

          result_class = Class.new(self::Result)
          result_class.fend_class = subclass
          subclass.const_set(:Result, result_class)
        end

        def plugin(plugin, *args, &block)
          plugin = Plugins.load_plugin(plugin)            if plugin.is_a?(Symbol)
          plugin.load_dependencies(self, *args, &block)   if plugin.respond_to?(:load_dependencies)

          self.include(plugin::InstanceMethods)           if defined?(plugin::InstanceMethods)
          self.extend(plugin::ClassMethods)               if defined?(plugin::ClassMethods)

          self::Param.include(plugin::ParamMethods)       if defined?(plugin::ParamMethods)
          self::Param.extend(plugin::ParamClassMethods)   if defined?(plugin::ParamClassMethods)

          self::Result.include(plugin::ResultMethods)     if defined?(plugin::ResultMethods)
          self::Result.extend(plugin::ResultClassMethods) if defined?(plugin::ResultClassMethods)

          plugin.configure(self, *args, &block)           if plugin.respond_to?(:configure)

          plugin
        end

        def validate(&block)
          @validation_block = block
        end

        def call(input)
          new.call(input)
        end
      end

      module InstanceMethods
        def call(raw_data)
          set_data(raw_data)
          validate

          result(input: @_input_data, output: @_output_data, errors: @_input.errors)
        end

        def set_data(raw_data)
          @_raw_data    = raw_data
          @_input_data  = process_input(raw_data) || raw_data
          @_output_data = process_output(@_input_data) || @_input_data
          @_input       = input_class.new(@_input_data)
        end

        def validation_block
          self.class.validation_block
        end

        def input_class
          self.class::Param
        end

        def result_class
          self.class::Result
        end

        def process_input(input); end

        def process_output(output); end

        def validate
          @_input.instance_exec(@_input, &validation_block) if validation_block
        end

        def result(args)
          result_class.new(args)
        end
      end

      module ParamClassMethods
        attr_accessor :fend_class
      end

      module ParamMethods
        attr_reader :value, :errors

        def initialize(value)
          @value = value
          @errors = []
        end

        def param(name, &block)
          return if flat? && invalid?

          value = self[name]
          param = _build_param(value)

          yield(param)

          _nest_errors(name, param.errors) if param.invalid?
        end

        def params(*names, &block)
          return if flat? && invalid?

          params = names.each_with_object({}) do |name, result|
            param = _build_param(self[name])
            result[name] = param
          end

          yield(*params.values)

          params.each { |name, param| _nest_errors(name, param.errors) if param.invalid? }
        end

        def each(&block)
          return if (flat? && invalid?) || !@value.is_a?(Array)

          @value.each_with_index do |value, index|
            if block.arity.eql?(2)
              param = _build_param(value)

              yield(param, index)

              _nest_errors(index, param.errors) if param.invalid?
            else
              param(index, &block)
            end
          end
        end

        def valid?
          errors.empty?
        end

        def invalid?
          !valid?
        end

        def flat?
          errors.is_a?(Array)
        end

        def [](name)
          @value.fetch(name, nil) if @value.respond_to?(:fetch)
        end

        def add_error(message)
          @errors << message
        end

        def _nest_errors(name, messages)
          @errors = {} unless @errors.is_a?(Hash)
          @errors[name] = messages
        end

        def _build_param(*args)
          self.class.new(*args)
        end

        def inspect
          "#{fend_class.inspect}::Param"
        end

        def to_s
          "#{fend_class.inspect}::Param"
        end
      end

      module ResultClassMethods
        attr_accessor :fend_class
      end

      module ResultMethods
        attr_reader :input
        attr_reader :output

        def initialize(args = {})
          @input = args.fetch(:input)
          @output = args.fetch(:output)
          @errors = args.fetch(:errors)
        end

        def messages
          return {} if success?

          @errors
        end

        def failure?
          !success?
        end

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
