# frozen_string_literal: true

# WSCDC: Web Service de Constatación de Comprobantes (ARCA).
# Verificación de comprobantes electrónicos (CAE, CAEA, CAI).
# Documentación: Servicio de Constatación de Comprobantes.
module Arca
  class WSCDC
    WSDL = {
      development: "https://wswhomo.afip.gov.ar/WSCDC/service.asmx?WSDL",
      production: "https://servicios1.afip.gov.ar/WSCDC/service.asmx?WSDL",
      test: "#{Root}/test/fixtures/wscdc/wscdc.wsdl"
    }.freeze

    include TypeConversions

    attr_reader :wsaa, :cuit

    def initialize(options = {})
      @cuit = normalize_cuit(options[:cuit])
      @wsaa = WSAA.new options.merge(service: "wscdc")
      @client = Client.new Hash(options[:savon]).reverse_merge(
        wsdl: WSDL[@wsaa.env],
        soap_version: 1,
        convert_request_keys_to: :camelcase
      )
    end

    def dummy
      r = raw_request(:comprobante_dummy, nil)
      result = r[:comprobante_dummy_result]
      {
        app_server: result[:app_server],
        db_server: result[:db_server],
        auth_server: result[:auth_server]
      }
    end

    # Constata un comprobante. cmp_req: hash con cbte_modo, cuit_emisor, pto_vta,
    # cbte_tipo, cbte_nro, cbte_fch, imp_total, cod_autorizacion y opcionalmente
    # doc_tipo_receptor, doc_nro_receptor, opcionales.
    # Returns hash con :cmp_resp, :resultado ('A'|'R'), :observaciones, :fch_proceso, :errors.
    def comprobante_constatar(cmp_req)
      message = { auth: auth, cmp_req: cmp_req }
      r = raw_request(:comprobante_constatar, message)
      result = r[:comprobante_constatar_result]
      if result[:errors] && (errs = Array.wrap(result[:errors][:err])).any?
        raise ResponseError, errs.map { |e| { code: e[:code], msg: e[:msg] } }
      end

      {
        cmp_resp: result[:cmp_resp],
        resultado: result[:resultado],
        observaciones: parse_observaciones(result[:observaciones]),
        fch_proceso: result[:fch_proceso],
        errors: parse_errors(result[:errors]),
        events: parse_events(result[:events])
      }
    end

    # Modalidades de autorización (CAE, CAEA, CAI).
    def comprobantes_modalidad_consultar
      r = request(:comprobantes_modalidad_consultar)
      get_array(r, :fac_mod_tipo)
    end

    # Tipos de comprobante.
    def comprobantes_tipo_consultar
      r = request(:comprobantes_tipo_consultar)
      x2r get_array(r, :cbte_tipo), id: :integer, fch_desde: :date, fch_hasta: :date
    end

    # Tipos de documento.
    def documentos_tipo_consultar
      r = request(:documentos_tipo_consultar)
      x2r get_array(r, :doc_tipo), id: :integer, fch_desde: :date, fch_hasta: :date
    end

    # Tipos de datos opcionales.
    def opcionales_tipo_consultar
      r = request(:opcionales_tipo_consultar)
      get_array(r, :opcional_tipo)
    end

    private

    def request(action, body = nil)
      message = body || { auth: auth }
      r = raw_request(action, message)
      result_key = :"#{action}_result"
      result = r[result_key]
      if result && result[:errors] && (errs = Array.wrap(result[:errors][:err])).any?
        raise ResponseError, errs.map { |e| { code: e[:code], msg: e[:msg] } }
      end

      result
    end

    def auth
      @wsaa.auth.merge(cuit: cuit)
    end

    def raw_request(action, body = nil)
      resp = @client.request(action, body).to_hash[:"#{action}_response"]
      raise ServerError, "Unexpected response structure" unless resp

      resp
    end

    def get_array(response, array_element)
      if response && response[:result_get]
        Array.wrap(response[:result_get][array_element])
      else
        []
      end
    end

    def parse_observaciones(observaciones)
      if observaciones && observaciones[:obs]
        Array.wrap(observaciones[:obs])
      else
        []
      end
    end

    def parse_errors(errors)
      if errors && errors[:err]
        Array.wrap(errors[:err])
      else
        []
      end
    end

    def parse_events(events)
      if events && events[:evt]
        Array.wrap(events[:evt])
      else
        []
      end
    end

    def normalize_cuit(value)
      if value.nil? || value == ""
        0
      else
        value.to_s.gsub(/\D/, "").to_i
      end
    end
  end
end
