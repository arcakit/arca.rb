# Arca Changelog

## [1.0.1] - 2025-02-05
- Fix ruta hardcodeada de certificados SSL CA. Usar OpenSSL::X509::DEFAULT_CERT_FILE en lugar de la ruta hardcodeada
/etc/ssl/certs/ca-certificates.crt para soportar múltiples plataformas.

## [1.0.0] - 2025-01-31

- Primer release.
- Cliente Ruby para webservices de ARCA. Requiere Ruby >= 3.4.4.

### Servicios / clientes

- **WSAA** — Autenticación. TA (token/sign) cacheado como JSON; path del archivo TA sanitizado; ambientes development / production / test.
- **WSFE** — Factura Electrónica: dummy, tipos (comprobantes, documentos, monedas, IVA, tributos, etc.), puntos_venta, cotizacion, autorizar_comprobantes, CAE/CAEA (solicitar, consultar, informar, sin movimiento).
- **WSConstanciaInscripcion** — Constancia de inscripción (padrón).
- **PersonaServiceA4** — Padrón A4 (get_persona).
- **PersonaServiceA5** — Padrón A5 (get_persona, get_persona_list).
- **PersonaServiceA100** — Padrón A100 (dummy, jurisdictions, company_types, public_organisms).
- **WConsDeclaracion** — Declaraciones (tipo_agente, rol; detallada_lista_declaraciones, detallada_estado).
- **WSFeCred** — Factura Electrónica de Crédito MiPyMEs (FECredService): dummy, aceptar_f_e_cred, rechazar_f_e_cred, rechazar_nota_dc, informar_factura_agt_dpto_cltv, informar_cancelacion_total_f_e_cred, modificar_opcion_transferencia, consultar_comprobantes, consultar_ctas_ctes, consultar_cta_cte, consultar_cuentas_en_agt_dpto_cltv, consultar_monto_obligado_recepcion, consultar_tipos_retenciones, consultar_tipos_motivos_rechazo, consultar_facturas_agt_dpto_cltv, consultar_tipos_formas_cancelacion, obtener_remitos, consultar_historial_estados_comprobante, consultar_historial_estados_cta_cte, consultar_tipos_ajustes_operacion.
- **WSCDC** — Constatación de Comprobantes.
- **WSRgIVA** — RG IVA.