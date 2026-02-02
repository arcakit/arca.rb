# frozen_string_literal: true

require "test_helper"

module Arca
  class WSFeCredTest < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def cuit
      "20123456789"
    end

    def cuit_normalized
      20_123_456_789
    end

    def ws
      @ws ||= WSFeCred.new(cuit: cuit).tap { |w| w.wsaa.stubs auth: ta }
    end

    def auth_request
      { auth_request: ta.merge(cuit_representada: cuit_normalized) }
    end

    def test_dummy
      savon.expects(:dummy).returns(fixture("wsfecred/dummy/success"))
      assert_equal({ app_server: "OK", auth_server: "OK", db_server: "OK" }, ws.dummy)
    end

    def test_consultar_tipos_retenciones
      savon.expects(:consultar_tipos_retenciones).with(message: auth_request).returns(fixture("wsfecred/consultar_tipos_retenciones/success"))
      rta = ws.consultar_tipos_retenciones
      assert_instance_of Array, rta
      assert_operator rta.size, :>=, 1
      assert_hash_includes rta.first, codigo: "1", descripcion: "Retención 1"
    end

    def test_consultar_tipos_motivos_rechazo
      savon.expects(:consultar_tipos_motivos_rechazo).with(message: auth_request).returns(fixture("wsfecred/consultar_tipos_motivos_rechazo/success"))
      rta = ws.consultar_tipos_motivos_rechazo
      assert_instance_of Array, rta
      assert_operator rta.size, :>=, 1
      assert_hash_includes rta.first, codigo: "1", descripcion: "Motivo rechazo 1"
    end

    def test_consultar_tipos_formas_cancelacion
      savon.expects(:consultar_tipos_formas_cancelacion).with(message: auth_request).returns(fixture("wsfecred/consultar_tipos_formas_cancelacion/success"))
      rta = ws.consultar_tipos_formas_cancelacion
      assert_instance_of Array, rta
      assert_operator rta.size, :>=, 1
      assert_hash_includes rta.first, codigo: "1", descripcion: "Forma cancelación 1"
    end

    def test_consultar_cta_cte_con_cod_cta_cte
      savon.expects(:consultar_cta_cte).with(message: auth_request.merge(id_cta_cte: { cod_cta_cte: 12_345 })).returns(fixture("wsfecred/consultar_cta_cte/success"))
      rta = ws.consultar_cta_cte(cod_cta_cte: 12_345)
      assert_instance_of Hash, rta
      assert rta.key?(:cta_cte)
      assert rta.key?(:array_observaciones)
    end

    def test_consultar_comprobantes_con_rol
      savon.expects(:consultar_comprobantes).with(message: auth_request.merge(rol_cuit_representada: "Emisor")).returns(fixture("wsfecred/consultar_comprobantes/success"))
      rta = ws.consultar_comprobantes(rol_cuit_representada: "Emisor")
      assert rta.key?(:array_comprobantes)
      assert rta.key?(:nro_pagina)
      assert rta.key?(:hay_mas)
      assert_instance_of Array, rta[:array_comprobantes]
    end

    def test_consultar_ctas_ctes_con_rol
      savon.expects(:consultar_ctas_ctes).with(message: auth_request.merge(rol_cuit_representada: "Receptor")).returns(fixture("wsfecred/consultar_ctas_ctes/success"))
      rta = ws.consultar_ctas_ctes(rol_cuit_representada: "Receptor")
      assert rta.key?(:array_infos_cta_cte)
      assert rta.key?(:nro_pagina)
      assert rta.key?(:hay_mas)
      assert_instance_of Array, rta[:array_infos_cta_cte]
    end

    def test_aceptar_f_e_cred
      savon.expects(:aceptar_fe_cred).with(message: has_path(
        "//AuthRequest/Token" => "t",
        "//IdCtaCte/CodCtaCte" => 12_345
      )).returns(fixture("wsfecred/aceptar_f_e_cred/success"))
      rta = ws.aceptar_f_e_cred(
        { cod_cta_cte: 12_345 },
        saldo_aceptado: 100, cod_moneda: "PES", cotizacion_moneda_ult: 1.0
      )
      assert rta.key?(:resultado)
      assert rta.key?(:id_cta_cte)
      assert_equal "A", rta[:resultado]
    end

    def test_rechaza_id_cta_cte_invalido
      assert_raises(ArgumentError) { ws.send(:build_id_cta_cte, {}) }
      assert_raises(ArgumentError) { ws.send(:build_id_cta_cte, 123) }
    end

    def test_rechaza_id_comprobante_sin_claves
      assert_raises(ArgumentError) { ws.send(:build_id_comprobante, {}) }
      assert_raises(ArgumentError) { ws.send(:build_id_comprobante, { cuit_emisor: 1 }) }
    end

    def test_rechaza_array_motivos_rechazo_vacio_en_rechazar_f_e_cred
      error = assert_raises(ArgumentError) { ws.rechazar_f_e_cred({ cod_cta_cte: 1 }, array_motivos_rechazo: []) }
      assert_match(/array_motivos_rechazo must have at least one motive/, error.message)
    end

    def test_rechaza_array_motivos_rechazo_vacio_en_rechazar_nota_dc
      error = assert_raises(ArgumentError) do
        ws.rechazar_nota_dc({ cuit_emisor: 1, cod_tipo_cmp: 1, pto_vta: 1, nro_cmp: 1 }, array_motivos_rechazo: [])
      end
      assert_match(/array_motivos_rechazo must have at least one motive/, error.message)
    end

    def test_rechaza_array_formas_cancelacion_vacio
      error = assert_raises(ArgumentError) do
        ws.informar_cancelacion_total_f_e_cred({ cod_cta_cte: 1 }, array_formas_cancelacion: [],
                                                                   importe_cancelacion: 100)
      end
      assert_match(/array_formas_cancelacion must have at least one item/, error.message)
    end

    def test_autenticacion_deberia_autenticarse_usando_el_wsaa
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.dump")
      wsfecred = WSFeCred.new(cuit: "1", cert: "cert", key: "key")
      assert_equal "cert", wsfecred.wsaa.cert
      assert_equal "key", wsfecred.wsaa.key
      assert_equal "wsfecred", wsfecred.wsaa.service
      wsfecred.wsaa.expects(:login).returns(token: "t", sign: "s")
      savon.expects(:consultar_tipos_retenciones).with(message: has_path(
        "//AuthRequest/Token" => "t", "//AuthRequest/Sign" => "s", "//AuthRequest/CuitRepresentada" => 1
      )).returns(fixture("wsfecred/consultar_tipos_retenciones/success"))
      wsfecred.consultar_tipos_retenciones
    end

    def test_cuando_hay_un_error_en_la_respuesta
      savon.expects(:consultar_tipos_retenciones).with(message: :any).returns(fixture("wsfecred/consultar_tipos_retenciones/failure"))
      e = assert_raises(ResponseError) { ws.consultar_tipos_retenciones }
      assert_match(/600/, e.message)
      assert e.code?("600")
    end

    def test_entorno_development
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:development] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSFeCred::WSDL[:development] && opts[:soap_version] == 1 && opts[:convert_request_keys_to] == :camelcase
      end.returns(stub(operations: []))
      WSFeCred.new(cuit: "1", env: :development)
    end

    def test_entorno_production
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:production] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSFeCred::WSDL[:production] && opts[:soap_version] == 1 && opts[:convert_request_keys_to] == :camelcase
      end.returns(stub(operations: []))
      WSFeCred.new(cuit: "1", env: "production")
    end
  end
end
