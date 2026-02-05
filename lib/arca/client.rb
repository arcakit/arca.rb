# frozen_string_literal: true

module Arca
  class Client
    def initialize(savon_options)
      savon_opts = savon_options.reverse_merge(
        soap_version: 2,
        ssl_version: :TLSv1_2,
        ssl_ciphers: "DEFAULT:!DH:!DHE",
        ssl_ca_cert_file: OpenSSL::X509::DEFAULT_CERT_FILE
      )

      @savon = Savon.client savon_opts
    end

    def request(action, body = nil)
      @savon.call action, message: body
    rescue Savon::SOAPFault, Savon::HTTPError => e
      raise ServerError, e
    rescue HTTPClient::ConnectTimeoutError => e
      raise NetworkError.new(e, retriable: true)
    rescue HTTPClient::TimeoutError => e
      raise NetworkError, e
    end

    delegate :operations, to: :@savon
  end
end