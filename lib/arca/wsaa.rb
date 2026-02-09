# frozen_string_literal: true

require "json"

module Arca
  class WSAA
    attr_reader :key, :cert, :service, :ta, :cuit, :client, :env

    WSDL = {
      development: "https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl",
      production: "https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl",
      test: "#{Root}/test/fixtures/wsaa/wsaa.wsdl"
    }

    def initialize(options = {})
      @env = (options[:env] || :test).to_sym
      @key = options[:key]
      @cert = options[:cert]
      @service = options[:service] || "wsfe"
      @ttl = options[:ttl] || 2400
      @cuit = options[:cuit]
      @client = Client.new Hash(options[:savon]).reverse_merge(wsdl: WSDL[@env])
      @ta_path = options[:ta_path] || default_ta_path
    end

    def generar_tra(service, ttl)
      xml = Builder::XmlMarkup.new indent: 2
      xml.instruct!
      xml.loginTicketRequest version: 1 do
        xml.header do
          xml.uniqueId Time.now.to_i
          xml.generationTime xsd_datetime Time.now - ttl
          xml.expirationTime xsd_datetime Time.now + ttl
        end
        xml.service service
      end
    end

    def firmar_tra(tra, key, crt)
      key = OpenSSL::PKey::RSA.new key
      crt = OpenSSL::X509::Certificate.new crt
      OpenSSL::PKCS7.sign crt, key, tra
    end

    def codificar_tra(pkcs7)
      pkcs7.to_pem.lines.to_a[1..-2].join
    end

    def tra(key, cert, service, ttl)
      codificar_tra firmar_tra(generar_tra(service, ttl), key, cert)
    end

    def login
      response = @client.request :login_cms, in0: tra(@key, @cert, @service, @ttl)
      ta = Nokogiri::XML(Nokogiri::XML(response.to_xml).text)
      {
        token: ta.css("token").text,
        sign: ta.css("sign").text,
        generation_time: from_xsd_datetime(ta.css("generationTime").text),
        expiration_time: from_xsd_datetime(ta.css("expirationTime").text)
      }
    end

    def auth
      ta = obtener_y_cachear_ta
      { token: ta[:token], sign: ta[:sign] }
    end

    private

    # Previene el error 'El CEE ya posee un TA valido para el acceso al WSN solicitado' que se genera cuando se pide el token varias veces en poco tiempo
    def obtener_y_cachear_ta
      @ta ||= restore_ta
      if ta_expirado? @ta
        @ta = login
        persist_ta @ta
      end
      @ta
    end

    def restore_ta
      return nil unless File.exist?(@ta_path) && !File.empty?(@ta_path)

      data = JSON.parse(File.read(@ta_path))
      {
        token: data["token"],
        sign: data["sign"],
        generation_time: data["generation_time"] && Time.parse(data["generation_time"]),
        expiration_time: data["expiration_time"] && Time.parse(data["expiration_time"])
      }
    rescue JSON::ParserError, ArgumentError
      nil
    end

    def ta_expirado?(ta)
      if ta.nil?
        true
      elsif ta[:expiration_time].nil?
        true
      else
        ta[:expiration_time] <= Time.now
      end
    end

    def persist_ta(ta)
      dir = File.dirname(@ta_path)
      FileUtils.mkdir_p(dir)

      payload = {
        "token" => ta[:token],
        "sign" => ta[:sign],
        "generation_time" => ta[:generation_time]&.iso8601,
        "expiration_time" => ta[:expiration_time]&.iso8601
      }

      temp_path = "#{@ta_path}.#{Process.pid}.tmp"
      File.write(temp_path, JSON.generate(payload))
      File.rename(temp_path, @ta_path)
    rescue StandardError => e
      File.delete(temp_path) if defined?(temp_path) && File.exist?(temp_path)
      raise ServerError, e
    end

    def xsd_datetime(time)
      time.strftime("%Y-%m-%dT%H:%M:%S%z").sub /(\d{2})(\d{2})$/, '\1:\2'
    end

    def from_xsd_datetime(str)
      Time.parse(str) rescue nil
    end

    def default_ta_path
      # Sanitize to prevent path traversal if cuit/service come from input
      cuit_safe = @cuit.to_s.gsub(/\D/, "")
      service_safe = @service.to_s.gsub(/[^a-z0-9_]/, "")
      basename = "#{cuit_safe}-#{@env}-#{service_safe}-ta.json"
      File.join(Dir.pwd, "tmp", basename)
    end
  end
end
