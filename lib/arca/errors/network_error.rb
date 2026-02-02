# frozen_string_literal: true

module Arca
  class NetworkError < Error
    def initialize(e, retriable: false)
      super(e)

      @retriable = retriable
    end

    def retriable?
      @retriable
    end
  end
end
