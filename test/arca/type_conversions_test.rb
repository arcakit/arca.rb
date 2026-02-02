# frozen_string_literal: true

require "test_helper"

module Arca
  class TypeConversionsTest < TestCase
    include Arca::TypeConversions

    def test_r2x_convierte_values_de_hashes_a_xml_types
      assert_equal(
        { fecha: "20110102", id: 1 },
        r2x({ fecha: Date.new(2011, 1, 2), id: 1 }, fecha: :date)
      )
      assert_equal(
        { container: { fecha: "20110102" } },
        r2x({ container: { fecha: Date.new(2011, 1, 2) } }, fecha: :date)
      )
    end

    def test_r2x_convierte_values_aunque_esten_en_arrays
      assert_equal [ { fecha: "20110102" } ], r2x([ { fecha: Date.new(2011, 1, 2) } ], fecha: :date)
      assert_equal(
        { container: [ { fecha: "20110102" }, { fecha: "20110103" } ] },
        r2x({ container: [ { fecha: Date.new(2011, 1, 2) }, { fecha: Date.new(2011, 1, 3) } ] }, fecha: :date)
      )
    end

    def test_x2r_convierte_xml_types_a_ruby
      assert_equal(
        { fecha: Date.new(2011, 1, 2), id: 1, total: 1.23, obs: "algo" },
        x2r({ fecha: "20110102", id: "1", total: "1.23", obs: "algo" }, fecha: :date, id: :integer, total: :float)
      )
      assert_equal({ container: { id: 1 } }, x2r({ container: { id: "1" } }, id: :integer))
    end

    def test_x2r_hace_la_conversion_en_arrays
      assert_equal(
        { container: [ { id: 1 }, { id: 2 } ] },
        x2r({ container: [ { id: "1" }, { id: "2" } ] }, id: :integer)
      )
    end
  end
end
