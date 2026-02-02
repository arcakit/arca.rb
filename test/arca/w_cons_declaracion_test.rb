# frozen_string_literal: true

require "test_helper"

module Arca
  class WConsDeclaracionTest < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def ws
      @ws ||= WConsDeclaracion.new(env: :test, cuit: "23076925089").tap { |w| w.wsaa.stubs auth: ta }
    end

    def test_utiliza_los_parametros_correctos_en_el_wsaa
      assert_equal "wconsdeclaracion", ws.wsaa.service
      assert_equal "23076925089", ws.wsaa.cuit
      assert_equal :test, ws.wsaa.env
    end

    def test_dummy
      savon.expects(:dummy).returns(fixture("wconsdeclaracion/dummy/success"))
      assert_equal({ app_server: "OK", db_server: "OK", auth_server: "OK" }, ws.dummy)
    end

    def test_detallada_lista_declaraciones_por_id
      message = with_auth_section(
        "argDetalladasListaParams" => {
          "CuitImportadorExportador" => "23076925089",
          "IdentificadorDeclaracion" => "19093SIMI000434X"
        }
      )
      savon.expects(:detallada_lista_declaraciones).with(message: message)
        .returns(fixture("wconsdeclaracion/detallada_lista_declaraciones/por_id_success"))
      declaracion = ws.detallada_lista_declaraciones identificador_declaracion: "19093SIMI000434X"
      assert_hash_includes declaracion, identificador_declaracion: "19093SIMI000434X",
                                        cuit_importador_exportador: "23076925089"
    end

    def test_detallada_lista_declaraciones_por_fecha
      message = with_auth_section(
        "argDetalladasListaParams" => {
          "CuitImportadorExportador" => "23076925089",
          "FechaOficializacionDesde" => "2019-04-01T00:00:00-03:00",
          "FechaOficializacionHasta" => "2019-04-30T00:00:00-03:00"
        }
      )
      savon.expects(:detallada_lista_declaraciones).with(message: message)
        .returns(fixture("wconsdeclaracion/detallada_lista_declaraciones/por_fecha_success"))
      declaraciones = ws.detallada_lista_declaraciones(
        fecha_oficializacion_desde: Time.parse("2019-04-01T00:00:00-03:00"),
        fecha_oficializacion_hasta: Time.parse("2019-04-30T00:00:00-03:00")
      )
      assert_equal 2, declaraciones.size
      assert declaraciones.any? { |d| d[:identificador_declaracion] == "19092SIMI000313M" }
      assert declaraciones.any? { |d| d[:identificador_declaracion] == "19092SIMI000314N" }
    end

    def test_detallada_lista_declaraciones_id_inexistente
      savon.expects(:detallada_lista_declaraciones).with(message: :any)
        .returns(fixture("wconsdeclaracion/detallada_lista_declaraciones/por_id_inexistente"))
      error = assert_raises(ResponseError) { ws.detallada_lista_declaraciones identificador_declaracion: "..." }
      assert_equal "21248: Declaracion 19093SIMI000434. inexistente o invalida", error.message
    end

    def test_detallada_estado
      message = with_auth_section("argIdentificadorDestinacion" => "19093SIMI000434X")
      savon.expects(:detallada_estado).with(message: message)
        .returns(fixture("wconsdeclaracion/detallada_estado/success"))
      r = ws.detallada_estado("19093SIMI000434X")
      assert_hash_includes r, fecha_salida: DateTime.parse("2019-04-25T18:48:12"),
                              fecha_cancelacion: DateTime.parse("2019-07-04T02:29:34")
    end

    private

    def with_auth_section(msg)
      {
        "argWSAutenticacionEmpresa" => {
          "Token" => "t", "Sign" => "s", "CuitEmpresaConectada" => "23076925089",
          "TipoAgente" => "IMEX", "Rol" => "IMEX"
        }
      }.merge(msg)
    end
  end
end
