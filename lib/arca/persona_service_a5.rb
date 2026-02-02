# frozen_string_literal: true

module Arca
  class PersonaServiceA5
    WSDL = {
      development: "https://awshomo.afip.gov.ar/sr-padron/webservices/personaServiceA5?WSDL",
      production: "https://aws.afip.gov.ar/sr-padron/webservices/personaServiceA5?WSDL",
      test: "#{Root}/test/fixtures/ws_sr_padron_a5.wsdl"
    }.freeze

    attr_reader :wsaa

    def initialize(options = {})
      @cuit = options[:cuit]
      @wsaa = WSAA.new options.merge(service: "ws_sr_padron_a5")
      @client = Client.new Hash(options[:savon]).reverse_merge(wsdl: WSDL[@wsaa.env], soap_version: 1)
    end

    def dummy
      request(:dummy)[:return]
    end

    def get_persona(id)
      message = @wsaa.auth.merge(cuitRepresentada: @cuit, idPersona: id)
      request(:get_persona, message)[:persona_return]
    end

    # Request many personas in one SOAP call. ids: array of CUIT/id_persona.
    # Returns array of persona_return hashes (same shape as get_persona per element).
    def get_persona_list(ids)
      ids = Array(ids)
      return [] if ids.empty?

      message = @wsaa.auth.merge(cuitRepresentada: @cuit, idPersona: ids.map(&:to_s))
      raw = request(:get_persona_list, message)[:persona_list_return]
      personas = raw[:persona]
      Array.wrap(personas).compact
    end

    private

    def request(action, body = nil)
      @client.request(action, body).to_hash[:"#{action}_response"]
    end
  end
end
