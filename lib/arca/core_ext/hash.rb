# frozen_string_literal: true

module Arca
  module CoreExt
    module Hash
      refine ::Hash do
        def select_keys(*keys)
          slice(*keys)
        end
      end
    end
  end
end
