# frozen_string_literal: true

module Arca
  class Error < StandardError
    def code?(_code)
      false
    end

    def retriable?
      false
    end
  end
end
