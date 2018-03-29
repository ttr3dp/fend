#frozen_string_literal: true

class Fend
  module Plugins
    module Dig
      module ParamMethods
        def dig(*path)
          result = value

          path.each do |point|
            break if result.is_a?(Array) && !point.is_a?(Integer)

            result = result.is_a?(Enumerable) ? result[point] : nil

            break if result.nil?
          end

          result
        end
      end
    end

    register_plugin(:dig, Dig)
  end
end
