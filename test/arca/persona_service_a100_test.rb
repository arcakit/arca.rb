# frozen_string_literal: true

require "test_helper"

module Arca
  class PersonaServiceA100Test < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def ws
      @ws ||= PersonaServiceA100.new(cuit: "12345678912").tap { |w| w.wsaa.stubs auth: ta }
    end

    def auth_message
      ta.merge(cuitRepresentada: "12345678912")
    end

    def test_dummy
      savon.expects(:dummy).returns(fixture("ws_sr_padron_a100/dummy/success"))
      assert_equal({ appserver: "OK", authserver: "OK", dbserver: "OK" }, ws.dummy)
    end

    def test_jurisdictions
      savon.expects(:get_parameter_collection_by_name)
        .with(message: auth_message.merge(collectionName: "SUPA.E_PROVINCIA"))
        .returns(fixture("ws_sr_padron_a100/jurisdictions/success"))
      assert_hash_includes ws.jurisdictions, name: "SUPA.E_PROVINCIA"
    end

    def test_company_types
      savon.expects(:get_parameter_collection_by_name)
        .with(message: auth_message.merge(collectionName: "SUPA.TIPO_EMPRESA_JURIDICA"))
        .returns(fixture("ws_sr_padron_a100/company_types/success"))
      assert_hash_includes ws.company_types, name: "SUPA.TIPO_EMPRESA_JURIDICA"
    end

    def test_public_organisms
      savon.expects(:get_parameter_collection_by_name)
        .with(message: auth_message.merge(collectionName: "SUPA.E_ORGANISMO_INFORMANTE"))
        .returns(fixture("ws_sr_padron_a100/public_organisms/success"))
      assert_hash_includes ws.public_organisms, name: "SUPA.E_ORGANISMO_INFORMANTE"
    end
  end
end
