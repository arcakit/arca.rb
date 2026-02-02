# frozen_string_literal: true

# WSRGIVA: Web Service del Régimen de Percepción de I.V.A. (ARCA).
# Consulta de situación fiscal por lote (hasta 100 contribuyentes).
# Documentación: Régimen de Percepción de I.V.A. v1.0 (03-04-2023).
module Arca
  class WSRGIVA
    WSDL = {
      development: "https://fwshomo.afip.gov.ar/wsrgiva/services/RegimenPercepcionIVAService?wsdl",
      production: "https://serviciosjava.afip.gov.ar/wsrgiva/services/RegimenPercepcionIVAService?wdsl",
      test: "#{Root}/test/fixtures/wsrgiva/wsrgiva.wsdl"
    }.freeze

    attr_reader :wsaa, :cuit

    def initialize(options = {})
      @cuit = normalize_cuit(options[:cuit])
      @wsaa = WSAA.new options.merge(service: "wsrgiva")
      @client = Client.new Hash(options[:savon]).reverse_merge(
        wsdl: WSDL[@wsaa.env],
        soap_version: 1
      )
    end

    def dummy
      r = request(:dummy)[:return]
      {
        app_server: r[:appserver] || r[:app_server],
        auth_server: r[:authserver] || r[:auth_server],
        db_server: r[:dbserver] || r[:db_server]
      }
    end

    # Consulta la situación fiscal de hasta 100 contribuyentes.
    # cuits: array of 11-digit CUIT strings/integers (max 100).
    # tipo_bienes_involucrados: 1 (único valor admitido; nuevo/usado).
    # Returns array of constancia hashes (one per CUIT): success with
    # fecha_consulta, id_contribuyente, descripcion_contribuyente, vigencia,
    # codigo_leyenda, descripcion_leyenda, codigo_seguridad; or error with
    # codigo_error, descripcion_error.
    def consultar_constancia_por_lote(cuits, tipo_bienes_involucrados: 1)
      cuits = Array(cuits).map { |c| c.to_s.gsub(/\D/, "") }
      raise ArgumentError, "Maximum 100 CUITs per request" if cuits.size > 100
      raise ArgumentError, "tipo_bienes_involucrados must be 1" if tipo_bienes_involucrados != 1

      datos_transaccion = cuits.map do |cuit|
        { cuit_contribuyente: cuit.to_i, tipo_bienes_involucrados: 1 }
      end
      message = {
        auth_request: @wsaa.auth.merge(cuit_representada: cuit),
        datos_transaccion_array: { datos_transaccion: datos_transaccion }
      }
      result = request(:consultar_constancia_por_lote_v2, message)[:return]
      constancias = result[:constancia]
      Array.wrap(constancias)
    end

    private

    def request(action, body = nil)
      @client.request(action, body).to_hash[:"#{action}_response"]
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
