# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'arca/version'

Gem::Specification.new do |s|
  s.name        = 'arca.rb'
  s.version     = Arca::VERSION
  s.platform    = Gem::Platform::RUBY
  s.required_ruby_version = '>= 3.3.4'
  s.authors     = [ 'Arca Kit' ]
  s.email       = [ 'hola@arcakit.dev' ]
  s.homepage    = 'https://arcakit.dev'
  s.summary     = 'Cliente Ruby para webservices de AFIP/ARCA: facturación electrónica, comprobantes y servicios tributarios de Argentina'
  s.description = 'Cliente Ruby para integrar webservices SOAP de ARCA/AFIP en Argentina.'
  s.license     = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = [ 'lib' ]

  s.metadata = {
    'source_code_uri' => 'https://github.com/arcakit/arca.rb',
    'bug_tracker_uri' => 'https://github.com/arcakit/arca.rb/issues',
    'changelog_uri' => 'https://github.com/arcakit/arca.rb/blob/main/CHANGELOG.md',
    'rubygems_mfa_required' => 'true'
  }

  s.add_development_dependency 'minitest'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rubocop-rails-omakase'
  
  s.add_dependency 'activesupport'
  s.add_dependency 'builder'
  s.add_dependency 'httpclient'
  s.add_dependency 'nokogiri'
  s.add_dependency 'savon', '~> 2.15.0'
end