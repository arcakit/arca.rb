# frozen_string_literal: true

require "test_helper"

module Arca
  class WSRGIVATest < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def ws
      @ws ||= WSRGIVA.new(cuit: "20123456789").tap { |w| w.wsaa.stubs auth: ta }
    end

    def test_dummy
      savon.expects(:dummy).returns(fixture("wsrgiva/dummy/success"))
      assert_equal({ app_server: "OK", auth_server: "OK", db_server: "OK" }, ws.dummy)
    end

    def test_consultar_constancia_por_lote_devuelve_array_de_constancias
      savon.expects(:consultar_constancia_por_lote_v2)
        .with(message: {
                auth_request: ta.merge(cuit_representada: 20_123_456_789),
                datos_transaccion_array: { datos_transaccion: [ { cuit_contribuyente: 20_123_456_789,
                                                                 tipo_bienes_involucrados: 1 } ] }
              })
        .returns(fixture("wsrgiva/consultar_constancia_por_lote/success"))
      r = ws.consultar_constancia_por_lote("20123456789")
      assert_equal 2, r.size
      assert_hash_includes r[0],
                           fecha_consulta: "23-03-2023", id_contribuyente: "20123456789",
                           descripcion_contribuyente: "RAZON SOCIAL EJEMPLO S.A.", vigencia: "23-09-2023",
                           codigo_leyenda: "18", descripcion_leyenda: "Alícuota 1% - Responsables inscriptos, sin incumplimientos.",
                           codigo_seguridad: "ABC123"
      assert_equal "20234567890", r[1][:id_contribuyente]
      assert_equal "2", r[1][:codigo_leyenda]
    end

    def test_consultar_constancia_por_lote_con_varios_cuits
      savon.expects(:consultar_constancia_por_lote_v2)
        .with(message: {
                auth_request: ta.merge(cuit_representada: 20_123_456_789),
                datos_transaccion_array: {
                  datos_transaccion: [
                    { cuit_contribuyente: 20_123_456_789, tipo_bienes_involucrados: 1 },
                    { cuit_contribuyente: 20_234_567_890, tipo_bienes_involucrados: 1 }
                  ]
                }
              })
        .returns(fixture("wsrgiva/consultar_constancia_por_lote/success"))
      ws.consultar_constancia_por_lote(%w[20123456789 20234567890])
    end

    def test_consultar_constancia_por_lote_con_constancia_de_error
      savon.expects(:consultar_constancia_por_lote_v2).with(message: :any).returns(fixture("wsrgiva/consultar_constancia_por_lote/one_error"))
      r = ws.consultar_constancia_por_lote("30636414936")
      assert_equal 1, r.size
      assert_hash_includes r[0], id_contribuyente: "30636414936", codigo_error: "4003",
                                 descripcion_error: "CUIT Inexistente"
    end

    def test_rechaza_mas_de_100_cuits
      cuits = (1..101).map { |i| "20#{i.to_s.rjust(9, '0')}" }
      error = assert_raises(ArgumentError) { ws.consultar_constancia_por_lote(cuits) }
      assert_match(/Maximum 100 CUITs/, error.message)
    end

    def test_rechaza_tipo_bienes_involucrados_distinto_de_1
      error = assert_raises(ArgumentError) do
        ws.consultar_constancia_por_lote("20123456789", tipo_bienes_involucrados: 2)
      end
      assert_match(/tipo_bienes_involucrados must be 1/, error.message)
    end

    def test_entorno_development
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:development] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSRGIVA::WSDL[:development] && opts[:soap_version] == 1
      end.returns(stub(operations: []))
      WSRGIVA.new(cuit: "1", env: :development)
    end

    def test_entorno_production
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:production] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSRGIVA::WSDL[:production] && opts[:soap_version] == 1
      end.returns(stub(operations: []))
      WSRGIVA.new(cuit: "1", env: :production)
    end
  end
end
