# frozen_string_literal: true

require "test_helper"

module Arca
  class WSCDCTest < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def ws
      @ws ||= WSCDC.new(cuit: "30000000007").tap { |w| w.wsaa.stubs auth: ta }
    end

    def test_dummy
      savon.expects(:comprobante_dummy).returns(fixture("wscdc/comprobante_dummy/success"))
      assert_equal({ app_server: "OK", db_server: "OK", auth_server: "OK" }, ws.dummy)
    end

    def test_comprobante_constatar_devuelve_hash_con_resultado_a
      savon.expects(:comprobante_constatar)
        .with(message: {
                auth: ta.merge(cuit: 30_000_000_007),
                cmp_req: {
                  cbte_modo: "CAE", cuit_emisor: 20_000_000_001, pto_vta: 1, cbte_tipo: 1, cbte_nro: 2,
                  cbte_fch: "20101014", imp_total: 300.8, cod_autorizacion: "60428000005029"
                }
              })
        .returns(fixture("wscdc/comprobante_constatar/success"))
      r = ws.comprobante_constatar(
        cbte_modo: "CAE", cuit_emisor: 20_000_000_001, pto_vta: 1, cbte_tipo: 1, cbte_nro: 2,
        cbte_fch: "20101014", imp_total: 300.8, cod_autorizacion: "60428000005029"
      )
      assert_equal "A", r[:resultado]
      assert r[:cmp_resp].present?
      assert_equal "20130729204436", r[:fch_proceso]
    end

    def test_comprobante_constatar_con_errores_levanta_response_error
      savon.expects(:comprobante_constatar).with(message: :any).returns(fixture("wscdc/comprobante_constatar/with_errors"))
      error = assert_raises(ResponseError) do
        ws.comprobante_constatar(cbte_modo: "CAE", cuit_emisor: 2_222_222_222_222, pto_vta: 1, cbte_tipo: 1,
                                 cbte_nro: 2, cbte_fch: "20101014", imp_total: 300.8, cod_autorizacion: "60428000005029")
      end
      assert_equal [ { code: "2", msg: "El campo CuitEmisor es invalido." } ], error.errors
    end

    def test_comprobantes_modalidad_consultar
      savon.expects(:comprobantes_modalidad_consultar)
        .with(message: { auth: ta.merge(cuit: 30_000_000_007) })
        .returns(fixture("wscdc/comprobantes_modalidad_consultar/success"))
      r = ws.comprobantes_modalidad_consultar
      assert_equal 3, r.size
      assert_hash_includes r[0], cod: "CAE", desc: "Codigo de Autorizacion Electronico"
      assert_equal "CAEA", r[1][:cod]
      assert_equal "CAI", r[2][:cod]
    end

    def test_comprobantes_tipo_consultar
      savon.expects(:comprobantes_tipo_consultar)
        .with(message: { auth: ta.merge(cuit: 30_000_000_007) })
        .returns(fixture("wscdc/comprobantes_tipo_consultar/success"))
      r = ws.comprobantes_tipo_consultar
      assert_equal 2, r.size
      assert_hash_includes r[0], id: 1, desc: "Factura A", fch_desde: Date.new(2010, 9, 17)
      assert_equal 6, r[1][:id]
    end

    def test_documentos_tipo_consultar
      savon.expects(:documentos_tipo_consultar)
        .with(message: { auth: ta.merge(cuit: 30_000_000_007) })
        .returns(fixture("wscdc/documentos_tipo_consultar/success"))
      r = ws.documentos_tipo_consultar
      assert_equal 1, r.size
      assert_hash_includes r[0], id: 80, desc: "CUIT", fch_desde: Date.new(2008, 7, 25)
    end

    def test_opcionales_tipo_consultar
      savon.expects(:opcionales_tipo_consultar)
        .with(message: { auth: ta.merge(cuit: 30_000_000_007) })
        .returns(fixture("wscdc/opcionales_tipo_consultar/success"))
      r = ws.opcionales_tipo_consultar
      assert_equal 1, r.size
      assert_hash_includes r[0], id: "OP1", desc: "Opcional tipo 1"
    end

    def test_entorno_development
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:development] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSCDC::WSDL[:development] && opts[:soap_version] == 1
      end.returns(stub(operations: []))
      WSCDC.new(cuit: "1", env: :development)
    end

    def test_entorno_production
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:production] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSCDC::WSDL[:production] && opts[:soap_version] == 1
      end.returns(stub(operations: []))
      WSCDC.new(cuit: "1", env: :production)
    end
  end
end
