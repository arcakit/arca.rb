# frozen_string_literal: true

# Savon 2 only verifies message params as a hash. This allows passing xpaths for verification.

module Savon
  module MessageMatcher
    def actual(operation_name, builder, globals, locals)
      super.update request: builder.to_s
    end

    def verify_message!
      if @expected[:message].respond_to? :verify!
        @expected[:message].verify! @actual[:request]
      else
        super
      end
    end
  end

  MockExpectation.prepend MessageMatcher
end

def has_path(paths)
  HasXPath.new(paths)
end

class HasXPath
  def initialize(paths)
    @paths = paths
  end

  def verify!(xml)
    doc = Nokogiri::XML(xml)
    doc.remove_namespaces!
    @paths.each do |path, expected_value|
      actual = doc.xpath(path).text
      unless actual == expected_value.to_s
        raise Minitest::Assertion,
              "expected xpath '#{path}' with value '#{expected_value}', got: #{actual.inspect}\n#{doc}"
      end
    end
  end
end
