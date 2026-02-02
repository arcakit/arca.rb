# frozen_string_literal: true

require "test_helper"

module Arca
  class ClientTest < TestCase
    def subject
      @subject ||= Client.new(wsdl: Arca::WSFE::WSDL[:test])
    end

    def test_savon_soap_fault_se_encapsulan_en_server_error
      savon.expects(:fe_dummy).returns(fixture("wsaa/login_cms/fault"))
      error = assert_raises(ServerError) { subject.request :fe_dummy }
      assert_match(/CMS no es valido/, error.message)
    end

    def test_savon_http_error_se_encapsulan_en_server_error
      expect_savon_to_raise Savon::HTTPError, stub(code: 503, body: "Service Unavailable")
      error = assert_raises(ServerError) { subject.request :fe_dummy }
      assert_match(/Service Unavailable/, error.message)
    end

    def test_httpclient_timeout_error_se_encapsulan_en_network_error_y_no_es_retriable
      expect_savon_to_raise HTTPClient::ReceiveTimeoutError, "execution expired"
      error = assert_raises(NetworkError) { subject.request :fe_dummy }
      assert_match(/execution expired/, error.message)
      assert_equal false, error.retriable?
    end

    def test_httpclient_connect_timeout_error_se_encapsulan_en_network_error_y_es_retriable
      expect_savon_to_raise HTTPClient::ConnectTimeoutError, "execution expired"
      error = assert_raises(NetworkError) { subject.request :fe_dummy }
      assert_match(/execution expired/, error.message)
      assert_equal true, error.retriable?
    end

    private

    def expect_savon_to_raise(error_class, message)
      subject.instance_eval("@savon", __FILE__, __LINE__).expects(:call).raises(error_class, message)
    end
  end
end
