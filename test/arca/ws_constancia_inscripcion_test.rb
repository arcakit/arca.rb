# frozen_string_literal: true

require "test_helper"

module Arca
  class WSConstanciaInscripcionTest < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def ws
      @ws ||= WSConstanciaInscripcion.new(cuit: "1").tap { |w| w.wsaa.stubs auth: ta }
    end

    def auth_message
      ta.merge(cuit_representada: "1")
    end

    def test_dummy
      savon.expects(:dummy).returns(fixture("ws_sr_constancia_inscripcion/dummy/success"))
      assert_equal({ appserver: "OK", dbserver: "OK", authserver: "OK" }, ws.dummy)
    end

    def test_deberia_devolver_hash_con_datos_generales_y_regimenes_impositivos
      savon.expects(:get_persona)
        .with(message: auth_message.merge(id_persona: "20294834487"))
        .returns(fixture("ws_sr_constancia_inscripcion/get_persona/success"))
      r = ws.get_persona "20294834487"
      assert_hash_includes r[:datos_generales], estado_clave: "ACTIVO", mes_cierre: "6",
                                                razon_social: "LA REGALERIA S A", tipo_clave: "CUIT", tipo_persona: "JURIDICA"
      assert_hash_includes r[:datos_generales][:domicilio_fiscal], cod_postal: "2300",
                                                                   descripcion_provincia: "SANTA FE", direccion: "AV SIEMPRE VIVA 123", localidad: "NUEVA YORK", tipo_domicilio: "FISCAL"
      assert_hash_includes r[:datos_regimen_general][:actividad], id_actividad: "477330", nomenclador: "883",
                                                                  orden: "2", periodo: "201311"
      assert_hash_includes r[:datos_regimen_general][:impuesto][1], descripcion_impuesto: "IVA", id_impuesto: "30",
                                                                    periodo: "198903"
      assert_hash_includes r[:datos_regimen_general][:regimen], id_impuesto: "208", id_regimen: "159", periodo: "199403"
    end

    def test_cuando_hay_errores_en_la_constancia_sigue_la_misma_logica
      savon.expects(:get_persona)
        .with(message: auth_message.merge(id_persona: "20294834489"))
        .returns(fixture("ws_sr_constancia_inscripcion/get_persona/failure"))
      r = ws.get_persona "20294834489"
      assert_hash_includes r[:error_regimen_general],
                           error: "El contribuyente cuenta con impuestos con baja de oficio por Decreto 1299/98",
                           mensaje: "No cumple con las condiciones para enviar datos del regimen general"
    end

    def test_cuando_no_existe_la_persona
      savon.expects(:get_persona)
        .with(message: auth_message.merge(id_persona: "123"))
        .returns(fixture("ws_sr_constancia_inscripcion/get_persona/fault"))
      error = assert_raises(ServerError) { ws.get_persona "123" }
      assert_match(/No existe persona con ese Id/, error.message)
    end

    def test_autenticacion_deberia_autenticarse_usando_el_wsaa
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.dump")
      wss = WSConstanciaInscripcion.new(cuit: "1", cert: "cert", key: "key")
      assert_equal "cert", wss.wsaa.cert
      assert_equal "key", wss.wsaa.key
      assert_equal "ws_sr_constancia_inscripcion", wss.wsaa.service
      wss.wsaa.expects(:login).returns(token: "t", sign: "s")
      savon.expects(:get_persona).with(message: has_path(
        "//token" => "t", "//sign" => "s", "//cuitRepresentada" => "1"
      )).returns(fixture("ws_sr_constancia_inscripcion/get_persona/success"))
      wss.get_persona "20294834487"
    end

    def test_entorno_development
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:development] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSConstanciaInscripcion::WSDL[:development] && opts[:soap_version] == 1
      end.returns(stub(operations: []))
      WSConstanciaInscripcion.new(cuit: "1", env: :development)
    end

    def test_entorno_production
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:production] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSConstanciaInscripcion::WSDL[:production] && opts[:soap_version] == 1
      end.returns(stub(operations: []))
      WSConstanciaInscripcion.new(cuit: "1", env: :production)
    end
  end
end
