# frozen_string_literal: true

require "test_helper"

module Arca
  class VEConsumerTest < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def ws
      @ws ||= VEConsumer.new(cuit: "20111111112").tap { |w| w.wsaa.stubs auth: ta }
    end

    def test_consultar_comunicaciones
      savon.expects(:consultar_comunicaciones)
        .with(message: { auth_request: ta.merge(cuit_representada: 20_111_111_112), filter: {} })
        .returns(fixture("ve_consumer/consultar_comunicaciones/success"))
      r = ws.consultar_comunicaciones
      assert_equal "1", r[:pagina]
      assert_equal "1", r[:total_paginas]
      assert_equal 1, r[:items].size
      assert_hash_includes r[:items][0], id_comunicacion: "1", estado_desc: "Comunicacion Leida"
    end

    def test_consultar_comunicaciones_con_filtros
      savon.expects(:consultar_comunicaciones)
        .with(message: {
                auth_request: ta.merge(cuit_representada: 20_111_111_112),
                filter: { estado: 1, fecha_desde: "2012-01-01", pagina: 2 }
              })
        .returns(fixture("ve_consumer/consultar_comunicaciones/success"))
      ws.consultar_comunicaciones(estado: 1, fecha_desde: "2012-01-01", pagina: 2)
    end

    def test_consumir_comunicacion
      savon.expects(:consumir_comunicacion)
        .with(message: {
                auth_request: ta.merge(cuit_representada: 20_111_111_112),
                id_comunicacion: 12_061_068,
                incluir_adjuntos: false
              })
        .returns(fixture("ve_consumer/consumir_comunicacion/success"))
      r = ws.consumir_comunicacion(12_061_068)
      assert_hash_includes r, id_comunicacion: "12061068", estado: "1"
      assert_equal [], r[:adjuntos]
    end

    def test_consumir_comunicacion_con_adjuntos
      boundary = "testboundary"
      xml_part = fixture("ve_consumer/consumir_comunicacion/with_adjuntos")
      binary = "PKbinarydata"
      multipart_body = "--#{boundary}\r\nContent-Type: application/xop+xml; charset=UTF-8\r\n\r\n" \
                       "#{xml_part}\r\n" \
                       "--#{boundary}\r\nContent-Type: application/octet-stream\r\nContent-ID: <testcid@test>\r\n\r\n" \
                       "#{binary}\r\n" \
                       "--#{boundary}--\r\n"
      savon.expects(:consumir_comunicacion)
        .with(message: {
                auth_request: ta.merge(cuit_representada: 20_111_111_112),
                id_comunicacion: 12_061_068,
                incluir_adjuntos: true
              })
        .returns(code: 200,
                 headers: { "Content-Type" => "multipart/related; boundary=\"#{boundary}\"" },
                 body: multipart_body)
      r = ws.consumir_comunicacion(12_061_068, incluir_adjuntos: true)
      assert_equal 1, r[:adjuntos].size
      assert_equal "attach.zip", r[:adjuntos][0][:filename]
      assert_equal binary, r[:adjuntos][0][:content]
    end

    def test_soap_fault_levanta_response_error
      savon.expects(:consultar_comunicaciones)
        .with(message: :any)
        .returns(fixture("ve_consumer/consultar_comunicaciones/soap_fault"))
      error = assert_raises(ResponseError) { ws.consultar_comunicaciones }
      assert error.code?(104)
      assert_equal "104", error.errors[0][:code]
      assert_equal "La Comunicación [1] no existe", error.errors[0][:msg]
    end

    def test_consultar_sistemas_publicadores
      savon.expects(:consultar_sistemas_publicadores)
        .with(message: { auth_request: ta.merge(cuit_representada: 20_111_111_112) })
        .returns(fixture("ve_consumer/consultar_sistemas_publicadores/success"))
      r = ws.consultar_sistemas_publicadores
      assert_equal 1, r.size
      assert_hash_includes r[0], id: "88", descripcion: "MDQ"
    end

    def test_consultar_sistemas_publicadores_con_id
      savon.expects(:consultar_sistemas_publicadores)
        .with(message: {
                auth_request: ta.merge(cuit_representada: 20_111_111_112),
                id_sistema_publicador: 88
              })
        .returns(fixture("ve_consumer/consultar_sistemas_publicadores/success"))
      ws.consultar_sistemas_publicadores(id_sistema_publicador: 88)
    end

    def test_consultar_estados
      savon.expects(:consultar_estados)
        .with(message: { auth_request: ta.merge(cuit_representada: 20_111_111_112) })
        .returns(fixture("ve_consumer/consultar_estados/success"))
      r = ws.consultar_estados
      assert_equal 2, r.size
      assert_hash_includes r[0], id: "1", descripcion: "Comunicacion No Leida"
      assert_equal "2", r[1][:id]
    end

    def test_entorno_development
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:development] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == VEConsumer::WSDL[:development] && opts[:soap_version] == 2
      end.returns(stub(operations: []))
      VEConsumer.new(cuit: "1", env: :development)
    end

    def test_entorno_production
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:production] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == VEConsumer::WSDL[:production] && opts[:soap_version] == 2
      end.returns(stub(operations: []))
      VEConsumer.new(cuit: "1", env: :production)
    end
  end
end
