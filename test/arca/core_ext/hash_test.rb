# frozen_string_literal: true

require "test_helper"

class HashCoreExtTest < Minitest::Test
  using Arca::CoreExt::Hash

  def test_select_keys_toma_los_values_de_las_keys_indicadas
    hash = { 1 => 2, 3 => 4 }
    assert_equal({ 1 => 2 }, hash.select_keys(1))
    assert_equal({ 1 => 2, 3 => 4 }, hash.select_keys(1, 3))
    assert_equal({}, hash.select_keys(5))
    assert_equal({ 3 => 4 }, hash.select_keys(5, 3))
  end
end
