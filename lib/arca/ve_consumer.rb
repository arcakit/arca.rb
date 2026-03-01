# frozen_string_literal: true

# VEConsumer: Web Service de Ventanilla Electrónica - Consumir Comunicaciones (AFIP).
# Permite consultar y leer comunicaciones enviadas a un contribuyente.
# Documentación: VE-CU-WS-Consumir-Comunicaciones v1.3.0.
# Id del servicio WSAA: "veconsumerws".
module Arca
  class VEConsumer
    WSDL = {
      development: "https://stable-middleware-tecno-ext.afip.gob.ar/ve-ws/services/veconsumer?wsdl",
      production:  "https://infraestructura.afip.gob.ar/ve-ws/services/veconsumer?wsdl",
      test:        "#{Root}/test/fixtures/ve_consumer/ve_consumer.wsdl"
    }.freeze

    attr_reader :wsaa, :cuit

    def initialize(options = {})
      @cuit = normalize_cuit(options[:cuit])
      @wsaa = WSAA.new options.merge(service: "veconsumerws")
      @client = Client.new Hash(options[:savon]).reverse_merge(
        wsdl: WSDL[@wsaa.env],
        soap_version: 2,
        convert_request_keys_to: :camelcase
      )
    end

    # Consulta comunicaciones del contribuyente con filtros opcionales.
    # Claves opcionales del filter: estado, fecha_desde, fecha_hasta,
    #   comunicacion_id_desde, comunicacion_id_hasta, tiene_adjunto,
    #   sistema_publicador_id, pagina, resultados_por_pagina,
    #   referencia1, referencia2.
    # Retorna un hash con :pagina, :total_paginas, :items_por_pagina,
    #   :total_items e :items (Array de ComunicacionSimplificada).
    def consultar_comunicaciones(filter = {})
      r = raw_request(:consultar_comunicaciones, auth_request.merge(filter: filter))
      paginada = r[:respuesta_paginada]
      paginada.merge(items: get_array(paginada[:items], :comunicacion_simplificada))
    end

    # Recupera una comunicación por id y la marca como leída.
    # Con incluir_adjuntos: true se incluyen los adjuntos vía MTOM en la respuesta;
    # el contenido binario de cada adjunto queda en :content como String.
    # Retorna la Comunicacion con :adjuntos como Array.
    def consumir_comunicacion(id_comunicacion, incluir_adjuntos: false)
      response = client_request(:consumir_comunicacion, auth_request.merge(
        id_comunicacion: id_comunicacion,
        incluir_adjuntos: incluir_adjuntos
      ))
      resp = response.to_hash[:consumir_comunicacion_response]
      raise ServerError, "Unexpected response structure" unless resp

      comunicacion = resp[:comunicacion]
      comunicacion.merge(adjuntos: build_adjuntos(comunicacion[:adjuntos], response.attachments))
    end

    # Lista los sistemas publicadores habilitados en Ventanilla Electrónica.
    # Con id_sistema_publicador filtra por sistema específico.
    def consultar_sistemas_publicadores(id_sistema_publicador: nil)
      params = auth_request
      params = params.merge(id_sistema_publicador: id_sistema_publicador) if id_sistema_publicador
      r = raw_request(:consultar_sistemas_publicadores, params)
      Array.wrap(r.dig(:sistemas, :sistema))
    end

    # Lista los posibles estados de una comunicación. 1=No leída, 2=Leída.
    def consultar_estados
      r = raw_request(:consultar_estados, auth_request)
      Array.wrap(r.dig(:estados, :estado))
    end

    private

    def auth_request
      { auth_request: @wsaa.auth.merge(cuit_representada: cuit) }
    end

    def client_request(action, body)
      @client.request(action, body)
    rescue ServerError => e
      raise parse_fault(e)
    end

    def raw_request(action, body)
      resp = client_request(action, body).to_hash[:"#{action}_response"]
      raise ServerError, "Unexpected response structure" unless resp

      resp
    end

    def parse_fault(error)
      match = error.message.match(/Error (\d+): (.+)/)
      return error unless match

      ResponseError.new([ { code: match[1], msg: match[2].strip } ])
    end

    def build_adjuntos(adjuntos_element, mtom_parts)
      return [] unless adjuntos_element && adjuntos_element[:adjunto]

      items = Array.wrap(adjuntos_element[:adjunto])
      return items if mtom_parts.empty?

      by_cid = mtom_parts.each_with_object({}) do |part, h|
        cid = part.header[:content_id].to_s.tr("<>", "")
        h[cid] = part.body.decoded
      end

      items.map do |adj|
        href = adj.dig(:content, :include, :"@href").to_s
        next adj unless href.start_with?("cid:")

        cid = href.delete_prefix("cid:")
        adj.merge(content: by_cid.fetch(cid, adj[:content]))
      end
    end

    def get_array(container, element)
      return [] unless container && container[element]

      Array.wrap(container[element])
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
