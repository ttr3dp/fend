#frozen_string_literal: true

class Fend
  module Plugins
    module CollectiveParams
      module ParamMethods
        def params(*names, &block)
          return if flat? && invalid?

          params = names.each_with_object({}) do |name, result|
            param = _build_param(self[name])
            result[name] = param
          end

          yield(*params.values)

          params.each { |name, param| _nest_errors(name, param.errors) if param.invalid? }
        end
      end
    end

    register_plugin(:collective_params, CollectiveParams)
  end
end
