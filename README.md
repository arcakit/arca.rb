# Arca.rb

Cliente Ruby para integrar webservices SOAP de AFIP y ARCA en Argentina. Soporta facturación electrónica (WSFE), factura electrónica de crédito MiPyMEs (WSFeCred), autenticación WSAA, consulta de padrón de contribuyentes, constatación de comprobantes fiscales y todos los servicios tributarios de la API de AFIP. Ideal para aplicaciones Rails que necesitan generar facturas electrónicas y comprobantes en Argentina.

[![CI](https://github.com/arcakit/arca.rb/actions/workflows/ci.yml/badge.svg)](https://github.com/arcakit/arca.rb/actions/workflows/ci.yml)

## Características

- **Facturación Electrónica (WSFE)** - Generá facturas, notas de crédito y débito
- **Factura Electrónica de Crédito MiPyMEs (WSFeCred)** - FEC para PyMEs
- **Comprobantes AFIP** - Acceso completo a todos los webservices ARCA
- **SOAP simplificado** - API Ruby idiomática sobre los servicios SOAP de AFIP
- **Autenticación WSAA** - Manejo automático de tokens y certificados
- **Producción y homologación** - Ambientes configurables
- **Padrón AFIP** - Consulta de contribuyentes (A4, A5, A100)
- **Ventanilla Electrónica (VEConsumer)** - Consulta y lectura de comunicaciones de AFIP

## Requisitos

- Ruby >= 3.3.4
- Clave privada y certificado de ARCA/AFIP: seguí los [pasos para solicitar certificado](http://www.afip.gov.ar/ws/WSAA/cert-req-howto.txt)

## Instalación

Agregá a tu Gemfile:
```ruby
gem 'arca.rb'
```

Ejecutá `bundle install`. O instalá directamente: `gem install arca.rb`.

## Inicio rápido

1. **Obtené certificado y clave** de ARCA/AFIP (ver link arriba). Vas a tener un `.crt` (certificado) y una clave privada (`.key` o `.pem`).

2. **Instalá la ** y requerila:
```ruby
   require 'arca'
```

3. **Elegí el ambiente**: usá `:development` (homologación) para testing, `:production` para operaciones reales.

4. **Creá un cliente** con tu CUIT, clave y certificado, después llamá al servicio:
```ruby
   ws = Arca::WSFE.new(
     env: :development,
     cuit: '20123456789',
     key: File.read('ruta/a/clave-privada.key'),
     cert: File.read('ruta/a/certificado.crt')
   )
   puts ws.cotizacion('DOL')  # cotización dólar
```

## Ambientes

| `env` | Uso |
|-------|-----|
| `:test` | Solo WSDL/fixtures locales (para tests). Sin llamadas de red. |
| `:development` | Homologación — servidores de prueba de AFIP. Usá para testing de integración. |
| `:production` | Producción — endpoints reales de AFIP. |

Opción del constructor: `env: :development` o `env: :production` (symbol o string). Por defecto es `:test`.

## Servicios disponibles

| Servicio (WSDL) | Clase | Descripción |
|----------------|-------|-------------|
| WSAA | `Arca::WSAA` | Autenticación y autorización |
| WSFE | `Arca::WSFE` | Facturación electrónica |
| WSFeCred | `Arca::WSFeCred` | Factura electrónica de crédito MiPyMEs |
| WSCDC | `Arca::WSCDC` | Constatación de comprobantes |
| WSRGIVA | `Arca::WSRGIVA` | Régimen percepción IVA |
| WS Constancia Inscripción | `Arca::WSConstanciaInscripcion` | Constancia de inscripción |
| Padrón A4 / A5 / A100 | `Arca::PersonaServiceA4`, `PersonaServiceA5`, `PersonaServiceA100` | Consulta padrón de contribuyentes |
| WConsDeclaracion | `Arca::WConsDeclaracion` | Declaraciones aduaneras |
| VEConsumer | `Arca::VEConsumer` | Ventanilla Electrónica — comunicaciones del contribuyente |

## Uso

Opciones comunes del constructor: `env`, `cuit`, `key`, `cert`. Opcionales: `savon` (hash pasado a Savon), `ta_path` (WSAA, path del archivo TA), `store` (WSAA, objeto con `read`/`write` para guardar TA en backend propio), etc.

### Cliente de bajo nivel (`Arca::Client`)

`Arca::Client` es el cliente SOAP base que envuelve [Savon](https://github.com/savonrb/savon). Las clases de servicio de alto nivel (WSFE, WSAA, etc.) se construyen sobre este. Podés usarlo directamente para WSDLs custom o llamadas SOAP raw.

**Constructor:** `Arca::Client.new(savon_options)` — acepta cualquier [opción de cliente Savon](https://www.savonrb.com/version2/globals.html). Las opciones se combinan con estos defaults (necesarios para AFIP/ARCA):

| Opción        | Default              | Propósito |
|---------------|----------------------|-----------|
| `soap_version`| `2`                  | SOAP 1.2 |
| `ssl_version` | `:TLSv1_2`           | TLS 1.2 para AFIP |
| `ssl_ciphers` | `'DEFAULT:!DH:!DHE'` | Excluye ciphers DH/DHE para evitar "dh key too small" con ARCA (OpenSSL 1.1.1+ SECLEVEL=2 rechaza claves DH pequeñas). |

**Métodos:**

- **`request(action, body = nil)`** — Envía un request SOAP para la `action` dada con `body` opcional. Levanta `Arca::ServerError` en errores SOAP/HTTP, `Arca::NetworkError` en timeouts (connect timeouts se marcan `retriable: true`).
- **`operations`** — Delegado al cliente Savon; devuelve la lista de operaciones SOAP disponibles del WSDL.

Ejemplo (WSDL custom):
```ruby
client = Arca::Client.new(
  wsdl: 'https://example.afip.gov.ar/ws/MiServicio?wsdl',
  wsse_auth: ['ruta/a/cert.crt', 'ruta/a/key.pem']
)
client.operations  # => lista de operaciones
response = client.request(:mi_operacion, { key: 'valor' })
```

### WSAA (autenticación)

Token y sign son usados internamente por otros servicios; podés llamar WSAA directamente si lo necesitás:
```ruby
wsaa = Arca::WSAA.new(env: :development, cuit: '20123456789', key: key, cert: cert)
auth = wsaa.auth  # => { token: '...', sign: '...' }
```

Opcionalmente podés pasar un **store** para guardar el TA en tu propio backend (por ejemplo DB por tenant con cifrado). Sin `store`, se usa un archivo JSON en `tmp/`. El store debe implementar:

- **`read(cuit:, env:, service:)`** — devuelve `nil` o un Hash con claves simbólicas: `:token`, `:sign`, `:generation_time`, `:expiration_time` (Time o string ISO8601).
- **`write(cuit:, env:, service:, ta:, expires_at:)`** — se invoca después de un `#login` exitoso; `ta` es el hash del TA y `expires_at` el Time de vencimiento.

### WSFE (Factura Electrónica)
```ruby
ws = Arca::WSFE.new(env: :development, cuit: '20123456789', key: key, cert: cert)
ws.dummy                    # verificación de conectividad
ws.cotizacion('DOL')        # cotización moneda
ws.tipos_comprobantes       # tipos de comprobante
ws.ptos_venta               # puntos de venta
# ... fe_comp_ultimo_autorizado, fecae_solicitar, etc.
```

### WSFeCred (Factura Electrónica de Crédito MiPyMEs)
```ruby
ws = Arca::WSFeCred.new(env: :development, cuit: '20123456789', key: key, cert: cert)
ws.dummy
ws.consultar_tipos_retenciones
ws.consultar_cta_cte(id_cta_cte)
# ... aceptar_f_e_cred, rechazar_f_e_cred, etc.
```

### WSCDC (Constatación de Comprobantes)
```ruby
ws = Arca::WSCDC.new(env: :development, cuit: '20123456789', key: key, cert: cert)
ws.dummy
ws.comprobante_constatar(
  cbte_modo: 1, 
  cuit_emisor: '...', 
  pto_vta: 1, 
  cbte_tipo: 1, 
  cbte_nro: 1, 
  cbte_fch: '20250101', 
  imp_total: 100.0, 
  cod_autorizacion: '...'
)
```

### WSRGIVA (Régimen Percepción IVA)
```ruby
ws = Arca::WSRGIVA.new(env: :development, cuit: '20123456789', key: key, cert: cert)
ws.dummy
ws.consultar_constancia_por_lote(['20123456789', '20999888777'])
```

### Padrón (PersonaService A4 / A5 / A100)
```ruby
# Padrón A5
padron = Arca::PersonaServiceA5.new(env: :development, cuit: '20123456789', key: key, cert: cert)
padron.get_persona('20123456789')
# A4: PersonaServiceA4, A100: PersonaServiceA100 (tipos de sociedad, jurisdicciones, etc.)
```

### WS Constancia Inscripción
```ruby
ws = Arca::WSConstanciaInscripcion.new(env: :development, cuit: '20123456789', key: key, cert: cert)
ws.get_persona('20123456789')
```

### VEConsumer (Ventanilla Electrónica)
```ruby
ws = Arca::VEConsumer.new(env: :development, cuit: '20123456789', key: key, cert: cert)

# Consultar comunicaciones (paginado, con filtros opcionales)
r = ws.consultar_comunicaciones(estado: 1, pagina: 1)
r[:items]          # Array de ComunicacionSimplificada
r[:total_paginas]  # total de páginas

# Leer una comunicación (la marca como leída)
com = ws.consumir_comunicacion(12_061_068)
com[:estado]       # "2" (leída)
com[:adjuntos]     # [] si no tiene adjuntos

# Leer con adjuntos binarios vía MTOM
com = ws.consumir_comunicacion(12_061_068, incluir_adjuntos: true)
com[:adjuntos][0][:filename]  # "informe.pdf"
com[:adjuntos][0][:content]   # contenido binario (String)

# Sistemas publicadores habilitados
ws.consultar_sistemas_publicadores
ws.consultar_sistemas_publicadores(id_sistema_publicador: 88)

# Estados posibles (1=No leída, 2=Leída)
ws.consultar_estados
```

### WConsDeclaracion (Declaraciones aduaneras)
```ruby
ws = Arca::WConsDeclaracion.new(cuit: '20123456789', key: key, cert: cert, env: :development)
ws.dummy
ws.detallada_lista_declaraciones(fecha_oficializacion_desde: Date.new(2025, 1, 1))
ws.detallada_estado('identificador')
```

Mirá `test/` para más ejemplos.

## ¿Necesitás algo más simple?

Si preferís una API REST en lugar de trabajar directamente con SOAP, probá **[Arca Kit](https://arcakit.dev)** — nuestro servicio hosteado (y también de código abierto y libre para te lo instales donde quieras) que cubre todos los webservices de AFIP con una API facilonga, webhooks y multi tenancy.

## Desarrollo

Usá el [devcontainer](.devcontainer/devcontainer.json): abrí este repo en tu IDE y elegí **Reopen in Container**. El container ejecuta `bundle install` y el test suite después de crearse.

Después ejecutá los tests:
```bash
bundle exec rake test
```

O `bundle exec rake` (la task default ejecuta tests).

**CI:** cada push corre tests en GitHub Actions. Para publicar en RubyGems se usa el action oficial [rubygems/release-gem](https://github.com/rubygems/release-gem) con Trusted Publishing; ver [CONTRIBUTING.md](CONTRIBUTING.md#publishing-to-rubygems-via-ci) para los pasos.

## Reportar bugs o solicitar features

Si encontrás un bug o tenés una sugerencia para mejorar `arca.rb`, por favor [abrí un issue](https://github.com/arcakit/arca.rb/issues) en GitHub. Tu feedback nos ayuda a mejorar la gema para toda la comunidad.

## Licencia
ARCA usa licencia MIT.

## Créditos

Versión original de esta gem: https://github.com/eeng/afipws/

---