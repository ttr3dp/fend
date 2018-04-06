# frozen_string_literal: true

class Fend
  module Plugins
    # `collective_params` plugin allows you to specify multiple params at once,
    # instead of defining each one separately.
    #
    # Example:
    #
    #     plugin :collective_params
    #     plugin :validation_helpers # just to make the example more concise
    #
    #     validate do |i|
    #       i.params(:name, :email, :address) do |name, email, address|
    #         name.validate_presence
    #
    #         email.validate_format(EMAIL_REGEX)
    #
    #         address.params(:city, :street, :zip) do |city, street, zip|
    #           # ...
    #         end
    #       end
    #     end
    #
    # Since all params are then available in the same scope, you can add custom
    # validations more easily:
    #
    #     validate do |i|
    #       i.params(:started_at, :ended_at) do |started_at, ended_at|
    #         started_at.validate_presence
    #         started_at.validate_type(Time)
    #
    #         ended_at.validate_presence
    #         ended_at.validate_type(Time)
    #
    #         if started_at.valid? && ended_at.valid? && started_at > ended_at
    #           started_at.add_error("must happen before ended_at")
    #         end
    #       end
    #     end
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
