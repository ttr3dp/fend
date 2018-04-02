# frozen_string_literal: true

class Fend
  module Plugins
    module ValidateWith
      module ParamMethods
        def validate_with(validation)
          result = validation.call(value)

          @errors = result.messages if result.failure?
        end
      end
    end

    register_plugin(:validate_with, ValidateWith)
  end
end
