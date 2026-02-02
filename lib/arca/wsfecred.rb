# frozen_string_literal: true

# WSFeCred: Web Service Factura Electrónica de Crédito MiPyMEs (ARCA).
# Gestión de cuentas corrientes originadas por Facturas Electrónicas de Crédito (FECRED).
# Documentación: Manual para el Desarrollador FECredService v2.0.3.
#
# Security: Token/sign from WSAA are never logged; TLS is handled by Client (SSL ciphers).
# Errors: Business/format errors raise ResponseError with :code and :msg; transport raise ServerError/NetworkError.
module Arca
  class WSFeCred
    WSDL = {
      development: "https://fwshomo.afip.gov.ar/wsfecred/FECredService?wsdl",
      production: "https://serviciosjava.afip.gob.ar/wsfecred/FECredService?wsdl",
      test: "#{Root}/test/fixtures/wsfecred/wsfecred.wsdl"
    }.freeze

    attr_reader :wsaa, :cuit

    def initialize(options = {})
      @cuit = normalize_cuit(options[:cuit])
      @wsaa = WSAA.new options.merge(service: "wsfecred")
      @client = Client.new Hash(options[:savon]).reverse_merge(
        wsdl: WSDL[@wsaa.env],
        soap_version: 1,
        convert_request_keys_to: :camelcase
      )
    end

    def dummy
      r = raw_request(:dummy, nil)
      ret = r[:return] || r
      {
        app_server: ret[:appserver] || ret[:app_server],
        auth_server: ret[:authserver] || ret[:auth_server],
        db_server: ret[:dbserver] || ret[:db_server]
      }
    end

    # --- Operaciones de negocio ---

    # Aceptar o cancelar total/parcialmente la Factura Electrónica de Crédito.
    # id_cta_cte: { cod_cta_cte: long } o { id_factura: { cuit_emisor, cod_tipo_cmp, pto_vta, nro_cmp } }
    # Opciones: array_confirmar_notas_dc, array_formas_cancelacion, array_retenciones,
    #   array_ajustes_operacion, tipo_cancelacion, importe_cancelado, importe_total_ret_pesos,
    #   importe_embargo_pesos, saldo_aceptado, cod_moneda, cotizacion_moneda_ult,
    #   informa_cbu, cbu_comprador
    def aceptar_f_e_cred id_cta_cte, **opciones
      body = { auth_request: auth, id_cta_cte: build_id_cta_cte(id_cta_cte) }
      body.merge!(opciones_to_aceptar(opciones))
      parse_operacion_response raw_request(:aceptar_f_e_cred, body), :aceptar_f_e_cred
    end

    # Rechazar la Cta.Cte. de una FECRED. array_motivos_rechazo: [ { cod_motivo, desc_motivo, justificacion } ]
    def rechazar_f_e_cred(id_cta_cte, array_motivos_rechazo:)
      motivos = Array(array_motivos_rechazo)
      raise ArgumentError, "array_motivos_rechazo must have at least one motive" if motivos.empty?

      body = {
        auth_request: auth,
        id_cta_cte: build_id_cta_cte(id_cta_cte),
        array_motivos_rechazo: { motivo_rechazo: motivos }
      }
      parse_operacion_response raw_request(:rechazar_f_e_cred, body), :rechazar_f_e_cred
    end

    # Rechazar una Nota de Débito/Crédito individualmente.
    def rechazar_nota_dc(id_comprobante, array_motivos_rechazo:)
      motivos = Array(array_motivos_rechazo)
      raise ArgumentError, "array_motivos_rechazo must have at least one motive" if motivos.empty?

      body = {
        auth_request: auth,
        id_comprobante: build_id_comprobante(id_comprobante),
        array_motivos_rechazo: { motivo_rechazo: motivos }
      }
      r = raw_request(:rechazar_nota_dc, body)
      ret = get_return_value(r, :rechazar_nota_dc)
      parse_response_errores! ret
      ret
    end

    # Informar Factura al Agente de Depósito Colectivo. cta_agente: { cuit_agente, id_cuenta }
    def informar_factura_agt_dpto_cltv(id_cta_cte, cta_agente:)
      body = {
        auth_request: auth,
        id_cta_cte: build_id_cta_cte(id_cta_cte),
        cta_agente: cta_agente
      }
      parse_operacion_response raw_request(:informar_factura_agt_dpto_cltv, body), :informar_factura_agt_dpto_cltv
    end

    # Informar cancelación total de la FECRED. array_formas_cancelacion: [ { codigo } ], importe_cancelacion
    def informar_cancelacion_total_f_e_cred(id_cta_cte, array_formas_cancelacion:, importe_cancelacion:)
      formas = Array(array_formas_cancelacion)
      raise ArgumentError, "array_formas_cancelacion must have at least one item" if formas.empty?

      body = {
        auth_request: auth,
        id_cta_cte: build_id_cta_cte(id_cta_cte),
        array_formas_cancelacion: { codigo_descripcion: formas },
        importe_cancelacion: importe_cancelacion
      }
      parse_operacion_response raw_request(:informar_cancelacion_total_f_e_cred, body),
                               :informar_cancelacion_total_f_e_cred
    end

    # Modificar opción de transferencia (ADC o SCA). opcion_transferencia: 'ADC' | 'SCA'
    def modificar_opcion_transferencia(id_cta_cte, opcion_transferencia:)
      body = {
        auth_request: auth,
        id_cta_cte: build_id_cta_cte(id_cta_cte),
        opcion_transferencia: opcion_transferencia
      }
      parse_operacion_response raw_request(:modificar_opcion_transferencia, body), :modificar_opcion_transferencia
    end

    # Consultar comprobantes. rol_cuit_representada: 'Emisor'|'Receptor'. Filtros opcionales.
    def consultar_comprobantes(rol_cuit_representada:, cuit_contraparte: nil, cod_tipo_cmp: nil,
      estado_cmp: nil, fecha: nil, cod_cta_cte: nil, estado_cta_cte: nil, nro_pagina: nil)
      body = { auth_request: auth, rol_cuit_representada: rol_cuit_representada }
      body[:cuit_contraparte] = cuit_contraparte if cuit_contraparte
      body[:cod_tipo_cmp] = cod_tipo_cmp if cod_tipo_cmp
      body[:estado_cmp] = estado_cmp if estado_cmp
      body[:fecha] = fecha if fecha
      body[:cod_cta_cte] = cod_cta_cte if cod_cta_cte
      body[:estado_cta_cte] = estado_cta_cte if estado_cta_cte
      body[:nro_pagina] = nro_pagina if nro_pagina
      r = raw_request(:consultar_comprobantes, body)
      ret = get_return_value(r, :consultar_comprobantes)
      parse_response_errores! ret
      {
        array_comprobantes: wrap_array(ret[:array_comprobantes]&.[](:comprobante)),
        nro_pagina: ret[:nro_pagina],
        hay_mas: ret[:hay_mas],
        evento: ret[:evento],
        array_observaciones: wrap_codigo_descripcion(ret[:array_observaciones])
      }
    end

    # Consultar cuentas corrientes. rol_cuit_representada, filtros opcionales.
    def consultar_ctas_ctes(rol_cuit_representada:, cuit_contraparte: nil, fecha: nil,
      estado_cta_cte: nil, nro_pagina: nil, opcion_transferencia: nil)
      body = { auth_request: auth, rol_cuit_representada: rol_cuit_representada }
      body[:cuit_contraparte] = cuit_contraparte if cuit_contraparte
      body[:fecha] = fecha if fecha
      body[:estado_cta_cte] = estado_cta_cte if estado_cta_cte
      body[:nro_pagina] = nro_pagina if nro_pagina
      body[:opcion_transferencia] = opcion_transferencia if opcion_transferencia
      r = raw_request(:consultar_ctas_ctes, body)
      ret = get_return_value(r, :consultar_ctas_ctes)
      parse_response_errores! ret
      {
        array_infos_cta_cte: wrap_array(ret[:array_infos_cta_cte]&.[](:info_cta_cte)),
        nro_pagina: ret[:nro_pagina],
        hay_mas: ret[:hay_mas],
        evento: ret[:evento],
        array_observaciones: wrap_codigo_descripcion(ret[:array_observaciones])
      }
    end

    # Consultar detalle de una cuenta corriente.
    def consultar_cta_cte(id_cta_cte)
      body = { auth_request: auth, id_cta_cte: build_id_cta_cte(id_cta_cte) }
      r = raw_request(:consultar_cta_cte, body)
      ret = get_return_value(r, :consultar_cta_cte)
      parse_response_errores! ret
      ret.merge(cta_cte: ret[:cta_cte], array_observaciones: wrap_codigo_descripcion(ret[:array_observaciones]))
    end

    # Consultar cuentas del vendedor en Agentes de Depósito Colectivo.
    def consultar_cuentas_en_agt_dpto_cltv
      body = { auth_request: auth }
      r = raw_request(:consultar_cuentas_en_agt_dpto_cltv, body)
      ret = get_return_value(r, :consultar_cuentas_en_agt_dpto_cltv)
      parse_response_errores! ret
      {
        array_cuentas_en_agente: wrap_array(ret[:array_cuentas_en_agente]&.[](:cuenta_en_agente)),
        array_observaciones: wrap_codigo_descripcion(ret[:array_observaciones])
      }
    end

    # Consultar monto obligado recepción para una CUIT y fecha de emisión.
    def consultar_monto_obligado_recepcion(cuit_consultada:, fecha_emision:)
      body = {
        auth_request: auth,
        cuit_consultada: normalize_cuit(cuit_consultada),
        fecha_emision: format_date(fecha_emision)
      }
      r = raw_request(:consultar_monto_obligado_recepcion, body)
      ret = get_return_value(r, :consultar_monto_obligado_recepcion)
      parse_response_errores! ret
      {
        respuesta: ret[:respuesta],
        monto_desde: ret[:monto_desde],
        array_observaciones: wrap_codigo_descripcion(ret[:array_observaciones])
      }
    end

    # Tipos de retenciones habilitados.
    def consultar_tipos_retenciones
      body = { auth_request: auth }
      r = raw_request(:consultar_tipos_retenciones, body)
      ret = get_return_value(r, :consultar_tipos_retenciones)
      parse_response_errores! ret
      wrap_array(ret[:array_tipos_retenciones]&.[](:tipo_retencion))
    end

    # Tipos de motivos de rechazo.
    def consultar_tipos_motivos_rechazo
      body = { auth_request: auth }
      r = raw_request(:consultar_tipos_motivos_rechazo, body)
      ret = get_return_value(r, :consultar_tipos_motivos_rechazo)
      parse_response_errores! ret
      wrap_codigo_descripcion(ret[:array_codigo_descripcion])
    end

    # Facturas informadas al Agente de Depósito Colectivo.
    def consultar_facturas_agt_dpto_cltv(id_cta_cte: nil, filtro_fecha: nil)
      body = { auth_request: auth }
      body[:id_cta_cte] = build_id_cta_cte(id_cta_cte) if id_cta_cte
      body[:filtro_fecha] = filtro_fecha if filtro_fecha
      r = raw_request(:consultar_facturas_agt_dpto_cltv, body)
      ret = get_return_value(r, :consultar_facturas_agt_dpto_cltv)
      parse_response_errores! ret
      {
        array_facturas_agt_dpto_cltv: wrap_array(ret[:array_facturas_agt_dpto_cltv]&.[](:factura_informada)),
        evento: ret[:evento],
        array_observaciones: wrap_codigo_descripcion(ret[:array_observaciones])
      }
    end

    # Tipos de formas de cancelación.
    def consultar_tipos_formas_cancelacion
      body = { auth_request: auth }
      r = raw_request(:consultar_tipos_formas_cancelacion, body)
      ret = get_return_value(r, :consultar_tipos_formas_cancelacion)
      parse_response_errores! ret
      wrap_codigo_descripcion(ret[:array_codigo_descripcion])
    end

    # Remitos asociados a un comprobante.
    def obtener_remitos(id_comprobante)
      body = { auth_request: auth, id_comprobante: build_id_comprobante(id_comprobante) }
      r = raw_request(:obtener_remitos, body)
      ret = get_return_value(r, :obtener_remitos)
      parse_response_errores! ret
      wrap_array(ret[:array_ids_remitos]&.[](:id_comprobante))
    end

    # Historial de estados de un comprobante.
    def consultar_historial_estados_comprobante(id_comprobante)
      body = { auth_request: auth, id_comprobante: build_id_comprobante(id_comprobante) }
      r = raw_request(:consultar_historial_estados_comprobante, body)
      ret = get_return_value(r, :consultar_historial_estados_comprobante)
      parse_response_errores! ret
      {
        id_comprobante: ret[:id_comprobante],
        array_historial_estados: wrap_array(ret[:array_historial_estados]&.[](:estado_historico))
      }
    end

    # Historial de estados de una cuenta corriente.
    def consultar_historial_estados_cta_cte(id_cta_cte)
      body = { auth_request: auth, id_cta_cte: build_id_cta_cte(id_cta_cte) }
      r = raw_request(:consultar_historial_estados_cta_cte, body)
      ret = get_return_value(r, :consultar_historial_estados_cta_cte)
      parse_response_errores! ret
      {
        id_cta_cte: ret[:id_cta_cte],
        array_historial_estados: wrap_array(ret[:array_historial_estados]&.[](:estado_historico))
      }
    end

    # Tipos de ajustes de operación.
    def consultar_tipos_ajustes_operacion
      body = { auth_request: auth }
      r = raw_request(:consultar_tipos_ajustes_operacion, body)
      ret = get_return_value(r, :consultar_tipos_ajustes_operacion)
      parse_response_errores! ret
      wrap_codigo_descripcion(ret[:array_codigo_descripcion])
    end

    private

    def raw_request(action, body)
      # Savon normalizes WSDL operation names to snake_case (e.g. consultarTiposRetenciones -> :consultar_tipos_retenciones).
      # "aceptarFECred" becomes :aceptar_fe_cred (not :aceptar_f_e_cred).
      savon_action = action == :aceptar_f_e_cred ? :aceptar_fe_cred : action
      message = if body.nil?
                  nil
      else
                  body.key?(:auth_request) ? body : { auth_request: auth }.merge(body)
      end
      resp = @client.request(savon_action, message)
      body_hash = response_body(resp)
      raise ServerError, "Unexpected response structure" if body_hash.nil? || !body_hash.is_a?(Hash)

      body_hash
    end

    def auth
      @wsaa.auth.merge(cuit_representada: cuit)
    end

    # Response envelope key may be "dummyResponse" or :dummy_response depending on Savon.
    def response_body(resp)
      h = resp.respond_to?(:to_hash) ? resp.to_hash : resp
      key = h.keys.find { |k| k.to_s =~ /Response$/i }
      key ? h[key] : h
    end

    # Return value may be under operacionFECredReturn, consultarCtasCtesReturn, etc.
    def get_return_value(response_hash, _action)
      if response_hash.nil?
        response_hash
      else
        key = response_hash.keys.find { |k| k.to_s =~ /return$/i }
        key ? (response_hash[key] || response_hash) : response_hash
      end
    end

    def build_id_cta_cte(id_cta_cte)
      if id_cta_cte.is_a?(Hash) && (id_cta_cte.key?(:cod_cta_cte) || id_cta_cte.key?(:id_factura))
        id_cta_cte
      else
        raise ArgumentError,
              "id_cta_cte must be { cod_cta_cte: long } or { id_factura: { cuit_emisor, cod_tipo_cmp, pto_vta, nro_cmp } }"
      end
    end

    def build_id_comprobante(id_comprobante)
      raise ArgumentError, "id_comprobante must be a Hash" unless id_comprobante.is_a?(Hash)

      required = %i[cuit_emisor cod_tipo_cmp pto_vta nro_cmp]
      missing = required.reject { |k| id_comprobante.key?(k) }
      raise ArgumentError, "id_comprobante must include #{required.join(', ')}" if missing.any?

      id_comprobante.slice(*required)
    end

    def opciones_to_aceptar(opciones)
      out = {}
      out[:array_confirmar_notas_d_c] =
        { confirmar_nota: opciones[:array_confirmar_notas_dc] } if opciones[:array_confirmar_notas_dc]
      out[:array_formas_cancelacion] =
        { codigo_descripcion: opciones[:array_formas_cancelacion] } if opciones[:array_formas_cancelacion]
      out[:array_retenciones] = { retencion: opciones[:array_retenciones] } if opciones[:array_retenciones]
      out[:array_ajustes_operacion] =
        { ajuste: opciones[:array_ajustes_operacion] } if opciones[:array_ajustes_operacion]
      out[:tipo_cancelacion] = opciones[:tipo_cancelacion] if opciones[:tipo_cancelacion]
      out[:importe_cancelado] = opciones[:importe_cancelado] if opciones[:importe_cancelado]
      out[:importe_total_ret_pesos] = opciones[:importe_total_ret_pesos] if opciones[:importe_total_ret_pesos]
      out[:importe_embargo_pesos] = opciones[:importe_embargo_pesos] if opciones[:importe_embargo_pesos]
      out[:saldo_aceptado] = opciones[:saldo_aceptado] if opciones.key?(:saldo_aceptado)
      out[:cod_moneda] = opciones[:cod_moneda] if opciones[:cod_moneda]
      out[:cotizacion_moneda_ult] = opciones[:cotizacion_moneda_ult] if opciones.key?(:cotizacion_moneda_ult)
      out[:informa_cbu] = opciones[:informa_cbu] if opciones.key?(:informa_cbu)
      out[:cbu_comprador] = opciones[:cbu_comprador] if opciones[:cbu_comprador]
      out
    end

    def normalize_cuit(value)
      if value.nil? || value == ""
        0
      else
        value.to_s.gsub(/\D/, "").to_i
      end
    end

    def format_date(value)
      if value.nil?
        value
      else
        value.is_a?(String) ? value : value.to_date.strftime("%Y-%m-%d")
      end
    end

    def parse_operacion_response(r, action)
      return_key = :"#{action}_return"
      key = r.key?(return_key) ? return_key : r.keys.find { |k| k.to_s.include?("return") }
      ret = key ? r[key] : r
      parse_response_errores! ret.is_a?(Hash) ? ret : { key => ret }
      ret = r[key] || r
      {
        resultado: ret[:resultado],
        id_cta_cte: ret[:id_cta_cte],
        evento: ret[:evento],
        array_observaciones: wrap_codigo_descripcion(ret[:array_observaciones]),
        array_errores: wrap_codigo_descripcion(ret[:array_errores])
      }
    end

    def parse_response_errores!(h)
      return if h.nil? || !h.is_a?(Hash)

      errs = wrap_codigo_descripcion(h[:array_errores])
      raise ResponseError, errs.map { |e| error_to_code_msg(e, :codigo, :descripcion) } if errs && errs.any?

      format_errs = wrap_codigo_descripcion_string(h[:array_errores_formato])
      if format_errs && format_errs.any?
        raise ResponseError, format_errs.map { |e| error_to_code_msg(e, :codigo, :descripcion) }
      end
    end

    def error_to_code_msg(e, code_key, msg_key)
      code = e[code_key] || e[:codigo_descripcion]
      msg = e[msg_key] || e[:descripcion] || ""
      { code: code.to_s, msg: msg.to_s }
    end

    def wrap_array(val)
      if val.nil?
        []
      else
        val = val.values.first if val.is_a?(Hash) && val.size == 1
        Array.wrap(val)
      end
    end

    def wrap_codigo_descripcion(val)
      if val.nil?
        []
      else
        arr = val.is_a?(Hash) ? (val[:codigo_descripcion] || val[:codigoDescripcion]) : val
        Array.wrap(arr)
      end
    end

    def wrap_codigo_descripcion_string(val)
      if val.nil?
        []
      else
        arr = val.is_a?(Hash) ? (val[:codigo_descripcion_string] || val[:codigoDescripcionString]) : val
        Array.wrap(arr)
      end
    end
  end
end
