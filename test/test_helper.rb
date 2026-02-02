# frozen_string_literal: true

require "minitest/autorun"
require "arca"
require "savon/mock/spec_helper"
require "mocha/minitest"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

module Arca
  class TestCase < Minitest::Test
    include Savon::SpecHelper

    def setup
      savon.mock!
    end

    def teardown
      savon.unmock!
    end
  end
end

def fixture(file)
  File.read("#{Arca::Root}/test/fixtures/#{file}.xml")
end

def assert_hash_includes(actual, expected)
  expected.each do |k, v|
    if v.nil?
      assert_nil actual[k], "expected key :#{k} to be nil"
    else
      assert_equal v, actual[k], "expected key :#{k}"
    end
  end
end

def assert_xpath(xml, xpath, expected_value)
  doc = Nokogiri::XML(xml)
  doc.remove_namespaces!
  actual = doc.xpath(xpath).text
  assert_equal expected_value.to_s, actual,
               "expected xpath '#{xpath}' to have value '#{expected_value}', got: #{actual.inspect}\n#{doc}"
end
