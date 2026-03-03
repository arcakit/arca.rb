# frozen_string_literal: true

module Arca
  Root = File.expand_path("..", __dir__)
end

require "forwardable"
require "builder"
require "base64"
require "httpclient"
require "savon"
require "nokogiri"
require "active_support"
require "active_support/core_ext"
require "arca/core_ext/hash"
require "arca/errors/error"
require "arca/errors/response_error"
require "arca/errors/server_error"
require "arca/errors/network_error"
require "arca/type_conversions"
require "arca/client"
require "arca/wsaa"
require "arca/wsfe"
require "arca/ws_constancia_inscripcion"
require "arca/persona_service_a4"
require "arca/persona_service_a5"
require "arca/persona_service_a100"
require "arca/w_cons_declaracion"
require "arca/wsrgiva"
require "arca/wscdc"
require "arca/ve_consumer"
require "arca/wsfecred"
