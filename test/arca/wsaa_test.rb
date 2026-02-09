# frozen_string_literal: true

require "test_helper"

module Arca
  class WSAATest < TestCase
    def subject
      @subject ||= WSAA.new(wsdl: Arca::WSFE::WSDL[:test])
    end

    def test_generar_tra_genera_xml
      Time.stubs(:now).returns Time.new(2001, 12, 31, 12, 0, 0, "-03:00")
      xml = subject.generar_tra "wsfe", 2400
      assert_xpath xml, "/loginTicketRequest/header/uniqueId", Time.now.to_i.to_s
      assert_xpath xml, "/loginTicketRequest/header/generationTime", "2001-12-31T11:20:00-03:00"
      assert_xpath xml, "/loginTicketRequest/header/expirationTime", "2001-12-31T12:40:00-03:00"
      assert_xpath xml, "/loginTicketRequest/service", "wsfe"
    end

    def test_firmar_tra_firma_con_certificado_y_clave
      key = File.read(File.join(__dir__, "test.key"))
      crt = File.read(File.join(__dir__, "test.crt"))
      tra = subject.generar_tra "wsfe", 2400
      assert_match(/BEGIN PKCS7/, subject.firmar_tra(tra, key, crt).to_s)
    end

    def test_login_manda_tra_al_ws_y_obtiene_ta
      ws = WSAA.new key: "key", cert: "cert", wsdl: Arca::WSFE::WSDL[:test]
      ws.expects(:tra).with("key", "cert", "wsfe", 2400).returns("tra")
      savon.expects(:login_cms).with(message: { in0: "tra" }).returns(fixture("wsaa/login_cms/success"))
      ta = ws.login
      assert_equal "PD94=", ta[:token]
      assert_equal "i9xDN=", ta[:sign]
      assert_equal Time.new(2011, 1, 12, 18, 57, 4, "-03:00"), ta[:generation_time]
      assert_equal Time.new(2011, 1, 13, 6, 57, 4, "-03:00"), ta[:expiration_time]
    end

    def test_auth_devuelve_hash_con_token_y_sign
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.dump")
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.json")
      Time.stubs(:now).returns(Time.local(2010, 1, 1))

      ws = WSAA.new(wsdl: Arca::WSFE::WSDL[:test])
      ws.expects(:login).once.returns(token: "token", sign: "sign", expiration_time: Time.now + 60)
      assert_equal({ token: "token", sign: "sign" }, ws.auth)
    end

    def test_auth_cachea_ta_en_instancia_y_disco
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.dump")
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.json")
      Time.stubs(:now).returns(Time.local(2010, 1, 1))

      ws = WSAA.new(wsdl: Arca::WSFE::WSDL[:test])
      ta = { token: "token", sign: "sign", generation_time: Time.now, expiration_time: Time.now + 60 }
      ws.expects(:login).once.returns(ta)
      ws.auth
      ws.auth
      assert_same ta, ws.ta

      ws2 = WSAA.new(wsdl: Arca::WSFE::WSDL[:test])
      ws2.auth
      assert_equal ta[:token], ws2.ta[:token]
      assert_equal ta[:sign], ws2.ta[:sign]
    end

    def test_si_ta_expiro_ejecuta_solicitar_nuevo
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.dump")
      FileUtils.rm_rf Dir.glob("tmp/*-test-*-ta.json")
      Time.stubs(:now).returns(Time.local(2010, 1, 1))

      subject.expects(:login).twice
        .returns(token: "t1", expiration_time: Time.now - 2)
        .then.returns(token: "t2")
      subject.auth
      assert_equal "t1", subject.ta[:token]
      subject.auth
      assert_equal "t2", subject.ta[:token]
    end

    def test_persist_ta_encapsula_errores_en_server_error
      File.stubs(:write).raises(Errno::EACCES.new("Permission denied"))
      ta = { token: "t", sign: "s", generation_time: Time.now, expiration_time: Time.now + 60 }
      ws = WSAA.new(wsdl: Arca::WSFE::WSDL[:test])

      error = assert_raises(ServerError) { ws.send(:persist_ta, ta) }
      assert_equal Errno::EACCES, error.cause.class
      assert_match(/Permission denied/, error.cause.message)
    end
  end
end
