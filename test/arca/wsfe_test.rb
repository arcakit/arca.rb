# frozen_string_literal: true

require "test_helper"

module Arca
  class WSFETest < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def ws
      @ws ||= WSFE.new(cuit: "1").tap { |w| w.wsaa.stubs auth: ta }
    end

    def auth
      { auth: ta.merge(cuit: "1") }
    end

    def test_dummy
      savon.expects(:fe_dummy).returns(fixture("wsfe/fe_dummy/success"))
      assert_equal({ app_server: "OK", db_server: "OK", auth_server: "OK" }, ws.dummy)
    end

    def test_tipos_comprobantes
      savon.expects(:fe_param_get_tipos_cbte).with(message: auth).returns(fixture("wsfe/fe_param_get_tipos_cbte/success"))
      assert_equal [
        { id: 1, desc: "Factura A", fch_desde: Date.new(2010, 9, 17), fch_hasta: nil },
        { id: 2, desc: "Nota de Débito A", fch_desde: Date.new(2010, 9, 18), fch_hasta: Date.new(2011, 9, 18) }
      ], ws.tipos_comprobantes
    end

    def test_tipos_documentos
      savon.expects(:fe_param_get_tipos_doc).with(message: auth).returns(fixture("wsfe/fe_param_get_tipos_doc/success"))
      assert_equal [ { id: 80, desc: "CUIT", fch_desde: Date.new(2008, 7, 25), fch_hasta: nil } ], ws.tipos_documentos
    end

    def test_tipos_concepto
      savon.expects(:fe_param_get_tipos_concepto).with(message: auth).returns(fixture("wsfe/fe_param_get_tipos_concepto/success"))
      assert_equal [ { id: 1, desc: "Producto", fch_desde: Date.new(2008, 7, 25), fch_hasta: nil } ], ws.tipos_concepto
    end

    def test_tipos_monedas
      savon.expects(:fe_param_get_tipos_monedas).with(message: auth).returns(fixture("wsfe/fe_param_get_tipos_monedas/success"))
      assert_equal [
        { id: "PES", desc: "Pesos Argentinos", fch_desde: Date.new(2009, 4, 3), fch_hasta: nil },
        { id: "002", desc: "Dólar Libre EEUU", fch_desde: Date.new(2009, 4, 16), fch_hasta: nil }
      ], ws.tipos_monedas
    end

    def test_tipos_opcional
      savon.expects(:fe_param_get_tipos_opcional).with(message: auth).returns(fixture("wsfe/fe_param_get_tipos_opcional/success"))
      assert_equal [], ws.tipos_opcional
    end

    def test_tipos_iva
      savon.expects(:fe_param_get_tipos_iva).with(message: auth).returns(fixture("wsfe/fe_param_get_tipos_iva/success"))
      assert_equal [ { id: 5, desc: "21%", fch_desde: Date.new(2009, 2, 20), fch_hasta: nil } ], ws.tipos_iva
    end

    def test_tipos_tributos
      savon.expects(:fe_param_get_tipos_tributos).with(message: auth).returns(fixture("wsfe/fe_param_get_tipos_tributos/success"))
      assert_equal [ { id: 2, desc: "Impuestos provinciales", fch_desde: Date.new(2010, 9, 17), fch_hasta: nil } ],
                   ws.tipos_tributos
    end

    def test_actividades
      savon.expects(:fe_param_get_actividades).with(message: auth).returns(fixture("wsfe/fe_param_get_actividades/success"))
      assert_equal [
        { id: 620000, orden: 1, desc: "Telecomunicaciones alámbricas" },
        { id: 620100, orden: 2, desc: "Telecomunicaciones inalámbricas" }
      ], ws.actividades
    end

    def test_puntos_venta
      savon.expects(:fe_param_get_ptos_venta).with(message: auth).returns(fixture("wsfe/fe_param_get_ptos_venta/success"))
      assert_equal [
        { nro: 1, emision_tipo: "CAE", bloqueado: false, fch_baja: nil },
        { nro: 2, emision_tipo: "CAEA", bloqueado: true, fch_baja: Date.new(2011, 1, 31) }
      ], ws.puntos_venta
    end

    def test_cotizacion_cuando_la_moneda_existe
      savon.expects(:fe_param_get_cotizacion).with(message: auth.merge(mon_id: "DOL")).returns(fixture("wsfe/fe_param_get_cotizacion/dolar"))
      assert_equal 3.976, ws.cotizacion("DOL")
    end

    def test_cotizacion_cuando_la_moneda_no_existe
      savon.expects(:fe_param_get_cotizacion).with(message: auth.merge(mon_id: "PES")).returns(fixture("wsfe/fe_param_get_cotizacion/inexistente"))
      e = assert_raises(ResponseError) { ws.cotizacion("PES") }
      assert_match(/602: Sin Resultados/, e.message)
      assert e.code?(602)
      refute e.code?(603)
    end

    def test_cant_max_registros_x_lote
      savon.expects(:fe_comp_tot_x_request).with(message: auth).returns(fixture("wsfe/fe_comp_tot_x_request/success"))
      assert_equal 250, ws.cant_max_registros_x_lote
    end

    def test_autorizar_comprobantes_devuelve_hash_con_cae
      savon.expects(:fecae_solicitar).with(message: has_path(
        "//Auth/Token" => "t", "//FeCAEReq/FeCabReq/CantReg" => 1, "//FeCAEReq/FeCabReq/PtoVta" => 2,
        "//FeCAEReq/FeCabReq/CbteTipo" => 1,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/DocTipo" => 80,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/DocNro" => 30_521_189_203,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/CbteFch" => 20_110_113,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/ImpTotal" => 1270.48,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/ImpIVA" => 220.5,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Iva/AlicIva[1]/Id" => 5,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Iva/AlicIva[1]/Importe" => 220.5,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Tributos/Tributo[1]/Id" => 0,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Tributos/Tributo[1]/BaseImp" => 150,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Tributos/Tributo[1]/Alic" => 5.2,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Tributos/Tributo[1]/Importe" => 7.8
      )).returns(fixture("wsfe/fecae_solicitar/autorizacion_1_cbte"))
      rta = ws.autorizar_comprobantes(cbte_tipo: 1, pto_vta: 2, comprobantes: [ {
                                        cbte_nro: 1, concepto: 1, doc_nro: 30_521_189_203, doc_tipo: 80, cbte_fch: Date.new(2011, 0o1, 13),
                                        imp_total: 1270.48, imp_neto: 1049.98, imp_iva: 220.50, mon_id: "PES", mon_cotiz: 1,
                                        iva: { alic_iva: [ { id: 5, base_imp: 1049.98, importe: 220.50 } ] },
                                        tributos: { tributo: [ { id: 0, base_imp: 150, alic: 5.2, importe: 7.8 } ] }
                                      } ])
      assert_hash_includes rta[0], cae: "61023008595705", cae_fch_vto: Date.new(2011, 0o1, 23), cbte_nro: 1,
                                   resultado: "A", observaciones: []
      assert_equal 1, rta.size
    end

    def test_autorizar_comprobantes_con_varias_alicuotas_iva
      savon.expects(:fecae_solicitar).with(message: has_path(
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Iva/AlicIva[1]/Id" => 5,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Iva/AlicIva[1]/Importe" => 21,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Iva/AlicIva[2]/Id" => 4,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/Iva/AlicIva[2]/Importe" => 5.25
      )).returns(fixture("wsfe/fecae_solicitar/autorizacion_1_cbte"))
      ws.autorizar_comprobantes(cbte_tipo: 1, pto_vta: 2, comprobantes: [ { iva: { alic_iva: [
        { id: 5, base_imp: 100, importe: 21 },
        { id: 4, base_imp: 50, importe: 5.25 }
      ] } } ])
    end

    def test_autorizar_comprobantes_con_varios_comprobantes
      savon.expects(:fecae_solicitar).with(message: has_path(
        "//FeCAEReq/FeCabReq/CantReg" => 2,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/CbteDesde" => 5, "//FeCAEReq/FeDetReq/FECAEDetRequest[1]/CbteHasta" => 5,
        "//FeCAEReq/FeDetReq/FECAEDetRequest[2]/CbteDesde" => 6, "//FeCAEReq/FeDetReq/FECAEDetRequest[2]/CbteHasta" => 6
      )).returns(fixture("wsfe/fecae_solicitar/autorizacion_2_cbtes"))
      rta = ws.autorizar_comprobantes(cbte_tipo: 1, pto_vta: 2, comprobantes: [ { cbte_nro: 5 }, { cbte_nro: 6 } ])
      assert_hash_includes rta[0], cbte_nro: 5, cae: "61033008894096"
      assert_hash_includes rta[1], cbte_nro: 6, cae: "61033008894101"
    end

    def test_autorizar_comprobantes_con_2_observaciones
      savon.expects(:fecae_solicitar).with(message: :any).returns(fixture("wsfe/fecae_solicitar/dos_observaciones"))
      rta = ws.autorizar_comprobantes comprobantes: []
      assert_hash_includes rta[0], cbte_nro: 3, cae: nil, resultado: "R",
                                   observaciones: [ { code: 10_048, msg: "Msg 1" }, { code: 10_018, msg: "Msg 2" } ]
    end

    def test_autorizar_comprobantes_con_1_observacion
      savon.expects(:fecae_solicitar).with(message: :any).returns(fixture("wsfe/fecae_solicitar/una_observacion"))
      rta = ws.autorizar_comprobantes comprobantes: []
      assert_hash_includes rta[0], observaciones: [ { code: 10_048, msg: "Msg 1" } ]
    end

    def test_solicitar_caea_manda_periodo_y_orden
      Date.stubs today: Date.new(2011, 1, 27)
      savon.expects(:fecaea_solicitar).with(message: has_path("//Periodo" => "201102",
                                                              "//Orden" => 1)).returns(fixture("wsfe/fecaea_solicitar/success"))
      assert_hash_includes ws.solicitar_caea,
                           caea: "21043476341977", fch_tope_inf: Date.new(2011, 0o3, 17),
                           fch_vig_desde: Date.new(2011, 0o2, 0o1), fch_vig_hasta: Date.new(2011, 0o2, 15)
    end

    def test_periodo_para_solicitud_caea_primer_quincena
      Date.stubs today: Date.new(2011, 1, 12)
      assert_equal({ periodo: "201101", orden: 2 }, ws.periodo_para_solicitud_caea)
      Date.stubs today: Date.new(2011, 1, 15)
      assert_equal({ periodo: "201101", orden: 2 }, ws.periodo_para_solicitud_caea)
    end

    def test_periodo_para_solicitud_caea_segunda_quincena
      Date.stubs today: Date.new(2011, 1, 16)
      assert_equal({ periodo: "201102", orden: 1 }, ws.periodo_para_solicitud_caea)
      Date.stubs today: Date.new(2011, 1, 31)
      assert_equal({ periodo: "201102", orden: 1 }, ws.periodo_para_solicitud_caea)
    end

    def test_solicitar_caea_cuando_ya_otorgado_consulta_y_devuelve
      Date.stubs today: Date.new(2011, 1, 27)
      savon.expects(:fecaea_solicitar).with(message: has_path("//Periodo" => "201102",
                                                              "//Orden" => 1)).returns(fixture("wsfe/fecaea_solicitar/caea_ya_otorgado"))
      savon.expects(:fecaea_consultar).with(message: has_path("//Periodo" => "201102",
                                                              "//Orden" => 1)).returns(fixture("wsfe/fecaea_consultar/success"))
      assert_hash_includes ws.solicitar_caea, caea: "21043476341977", fch_vig_desde: Date.new(2011, 0o2, 0o1)
    end

    def test_solicitar_caea_encapsula_errores
      savon.expects(:fecaea_solicitar).with(message: :any).returns(fixture("wsfe/fecaea_solicitar/error_distinto"))
      assert_raises(ResponseError) { ws.solicitar_caea }
    end

    def test_informar_comprobantes_caea
      savon.expects(:fecaea_reg_informativo).with(message: has_path(
        "//Auth/Token" => "t", "//FeCAEARegInfReq/FeCabReq/CantReg" => 2,
        "//FeCAEARegInfReq/FeCabReq/PtoVta" => 3, "//FeCAEARegInfReq/FeCabReq/CbteTipo" => 1,
        "//FeCAEARegInfReq/FeDetReq/FECAEADetRequest[1]/CbteDesde" => 1, "//FeCAEARegInfReq/FeDetReq/FECAEADetRequest[1]/CbteHasta" => 1,
        "//FeCAEARegInfReq/FeDetReq/FECAEADetRequest[1]/CAEA" => "21043476341977",
        "//FeCAEARegInfReq/FeDetReq/FECAEADetRequest[2]/CbteDesde" => 2, "//FeCAEARegInfReq/FeDetReq/FECAEADetRequest[2]/CbteHasta" => 2,
        "//FeCAEARegInfReq/FeDetReq/FECAEADetRequest[2]/CAEA" => "21043476341977"
      )).returns(fixture("wsfe/fecaea_reg_informativo/informe_rtdo_parcial"))
      rta = ws.informar_comprobantes_caea(cbte_tipo: 1, pto_vta: 3, comprobantes: [
        { cbte_nro: 1, caea: "21043476341977" }, { cbte_nro: 2, caea: "21043476341977" }
      ])
      assert_hash_includes rta[0], cbte_nro: 1, caea: "21043476341977", resultado: "A", observaciones: []
      assert_hash_includes rta[1], cbte_nro: 2, caea: "21043476341977", resultado: "R",
                                   observaciones: [ { code: 724, msg: "Msg" } ]
    end

    def test_informar_caea_sin_movimientos
      savon.expects(:fecaea_sin_movimiento_informar).with(message: has_path(
        "//Auth/Token" => "t", "//PtoVta" => 4, "//CAEA" => "21043476341977"
      )).returns(fixture("wsfe/fecaea_sin_movimiento_informar/success"))
      rta = ws.informar_caea_sin_movimientos("21043476341977", 4)
      assert_hash_includes rta, caea: "21043476341977", resultado: "A"
    end

    def test_consultar_caea_sin_movimientos
      savon.expects(:fecaea_sin_movimiento_consultar).with(message: has_path(
        "//Auth/Token" => "t", "//CAEA" => "21043476341977", "//PtoVta" => 3
      )).returns(fixture("wsfe/fecaea_sin_movimiento_consultar/success"))
      assert_equal [{ caea: "21043476341977", fch_proceso: "20110202", pto_vta: 3 }],
                   ws.consultar_caea_sin_movimientos("21043476341977", 3)
    end

    def test_consultar_caea
      savon.expects(:fecaea_consultar).with(message: has_path("//Periodo" => "201101",
                                                              "//Orden" => 1)).returns(fixture("wsfe/fecaea_consultar/success"))
      assert_hash_includes ws.consultar_caea(Date.new(2011, 1, 1)), caea: "21043476341977",
                                                                    fch_tope_inf: Date.new(2011, 0o3, 17)
    end

    def test_ultimo_comprobante_autorizado
      savon.expects(:fe_comp_ultimo_autorizado).with(message: has_path("//PtoVta" => 1,
                                                                       "//CbteTipo" => 1)).returns(fixture("wsfe/fe_comp_ultimo_autorizado/success"))
      assert_equal 20, ws.ultimo_comprobante_autorizado(pto_vta: 1, cbte_tipo: 1)
    end

    def test_consultar_comprobante
      savon.expects(:fe_comp_consultar).with(message: has_path(
        "//Auth/Token" => "t", "//FeCompConsReq/PtoVta" => 1, "//FeCompConsReq/CbteTipo" => 2, "//FeCompConsReq/CbteNro" => 3
      )).returns(fixture("wsfe/fe_comp_consultar/success"))
      rta = ws.consultar_comprobante(pto_vta: 1, cbte_tipo: 2, cbte_nro: 3)
      assert_equal "61023008595705", rta[:cod_autorizacion]
      assert_equal "CAE", rta[:emision_tipo]
    end

    def test_autenticacion_deberia_autenticarse_usando_el_wsaa
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.dump")
      wsfe = WSFE.new cuit: "1", cert: "cert", key: "key"
      assert_equal "cert", wsfe.wsaa.cert
      assert_equal "key", wsfe.wsaa.key
      assert_equal "wsfe", wsfe.wsaa.service
      wsfe.wsaa.expects(:login).returns(token: "t", sign: "s")
      savon.expects(:fe_param_get_tipos_cbte).with(message: has_path(
        "//Auth/Token" => "t", "//Auth/Sign" => "s", "//Auth/Cuit" => "1"
      )).returns(fixture("wsfe/fe_param_get_tipos_cbte/success"))
      wsfe.tipos_comprobantes
    end

    def test_entorno_development
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:development] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSFE::WSDL[:development] && opts[:convert_request_keys_to] == :camelcase
      end.returns(stub(operations: []))
      WSFE.new env: :development
    end

    def test_entorno_production
      Client.expects(:new).with { |opts| opts[:wsdl] == WSAA::WSDL[:production] }.returns(stub(operations: []))
      Client.expects(:new).with do |opts|
        opts[:wsdl] == WSFE::WSDL[:production] && opts[:convert_request_keys_to] == :camelcase
      end.returns(stub(operations: []))
      WSFE.new env: "production"
    end

    def test_manejo_de_errores_cuando_hay_un_error
      savon.expects(:fe_param_get_tipos_cbte).with(message: :any).returns(fixture("wsfe/fe_param_get_tipos_cbte/failure_1_error"))
      e = assert_raises(ResponseError) { ws.tipos_comprobantes }
      assert_equal [ { code: "600", msg: "No se corresponden token con firma" } ], e.errors
      assert_equal "600: No se corresponden token con firma", e.message
    end

    def test_manejo_de_errores_cuando_hay_varios_errores
      savon.expects(:fe_param_get_tipos_cbte).with(message: :any).returns(fixture("wsfe/fe_param_get_tipos_cbte/failure_2_errors"))
      e = assert_raises(ResponseError) { ws.tipos_comprobantes }
      assert_equal [
        { code: "600", msg: "No se corresponden token con firma" },
        { code: "601", msg: "CUIT representada no incluida en token" }
      ], e.errors
      assert_equal "600: No se corresponden token con firma; 601: CUIT representada no incluida en token", e.message
    end

    def test_periodo_para_consulta_caea
      assert_equal({ periodo: "201101", orden: 1 }, ws.periodo_para_consulta_caea(Date.new(2011, 1, 1)))
      assert_equal({ periodo: "201101", orden: 1 }, ws.periodo_para_consulta_caea(Date.new(2011, 1, 15)))
      assert_equal({ periodo: "201101", orden: 2 }, ws.periodo_para_consulta_caea(Date.new(2011, 1, 16)))
      assert_equal({ periodo: "201101", orden: 2 }, ws.periodo_para_consulta_caea(Date.new(2011, 1, 31)))
      assert_equal({ periodo: "201102", orden: 1 }, ws.periodo_para_consulta_caea(Date.new(2011, 2, 2)))
    end

    def test_fecha_inicio_quincena_siguiente
      assert_equal Date.new(2010, 1, 16), fecha_inicio_quincena_siguiente(Date.new(2010, 1, 1))
      assert_equal Date.new(2010, 1, 16), fecha_inicio_quincena_siguiente(Date.new(2010, 1, 10))
      assert_equal Date.new(2010, 1, 16), fecha_inicio_quincena_siguiente(Date.new(2010, 1, 15))
      assert_equal Date.new(2010, 2, 1), fecha_inicio_quincena_siguiente(Date.new(2010, 1, 16))
      assert_equal Date.new(2010, 2, 1), fecha_inicio_quincena_siguiente(Date.new(2010, 1, 20))
      assert_equal Date.new(2010, 2, 1), fecha_inicio_quincena_siguiente(Date.new(2010, 1, 31))
      assert_equal Date.new(2011, 1, 1), fecha_inicio_quincena_siguiente(Date.new(2010, 12, 31))
    end

    def test_comprobante_to_request_no_envia_tributos_si_imp_trib_es_0
      refute c2r({ imp_trib: 0.0, tributos: { tributo: [] } }, {}).key?(:tributos)
    end

    private

    def fecha_inicio_quincena_siguiente(fecha)
      Date.stubs(today: fecha)
      ws.fecha_inicio_quincena_siguiente
    end

    def c2r(comprobante, opciones)
      ws.comprobante_to_request comprobante, opciones
    end
  end
end
