# Desarrollo — BANCI mensual

La sustitución vigente es `11_banci_mensual_bloque1.sql`. Requiere detener la API del ambiente, respaldo y paquetes API/Front del mismo bloque preparados. Probar primero en desarrollo/QA. Instrucciones: `../documentacion/banci_bloque1_instalacion.md`.

Los scripts 02–10 se retiraron porque reconstruían contratos incompatibles del modelo anterior. No ejecutar copias antiguas. Los significados compartidos de los catálogos se conservan en `estructura/08_significados_catalogos.sql`; el script 11 no borra sus columnas ni opciones.

El script 11 no elimina usuarios ni cargas de mensual/semanal/federal. Sustituye las tablas operativas anteriores de BANCI y elimina sus datos de prueba aunque tengan registros; también retira los snapshots viejos de cruce. Si el esquema mensual ya está instalado, no vuelve a borrar información. La nueva carga por cortes se implementa en el siguiente bloque.

## Operación y vistas mensuales

Después del 11, aplicar `12_banci_mensual_operacion.sql` con los paquetes API/Front de operación mensual. El 12 no borra datos. Consultar `../documentacion/banci_operacion_mensual.md` para la publicación coordinada y prueba de QA. No se habilita el nuevo cruce del consolidado en esta entrega.

Aplicar después `13_banci_ajustes_carga_configuracion.sql`: reubica la opción pendiente del cruce en MENSUAL (Consolidado); no borra datos y no activa una funcionalidad incompleta. Publicar API y Front con soporte para cargas adicionales del mismo corte. Cada carga incorpora solo carpetas nuevas; lo previamente aprobado se conserva. La plantilla con origen consolidado incluye las carpetas nuevas todavía pendientes de reportar.
