# frozen_string_literal: true

require "test_helper"

module Arca
  class PersonaServiceA4Test < TestCase
    def ta
      @ta ||= { token: "t", sign: "s" }
    end

    def ws
      @ws ||= PersonaServiceA4.new(cuit: "12345678912").tap { |w| w.wsaa.stubs auth: ta }
    end

    def auth_message
      ta.merge(cuitRepresentada: "12345678912")
    end

    def test_dummy
      savon.expects(:dummy).returns(fixture("ws_sr_padron_a4/dummy/success"))
      assert_equal({ appserver: "OK", authserver: "OK", dbserver: "OK" }, ws.dummy)
    end

    def test_get_persona
      savon.expects(:get_persona)
        .with(message: auth_message.merge(idPersona: "98765432198"))
        .returns(fixture("ws_sr_padron_a4/get_persona/success"))
      assert_hash_includes ws.get_persona("98765432198"), apellido: "ERNESTO DANIEL"
    end
  end
end
