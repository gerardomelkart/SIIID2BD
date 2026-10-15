# Desarrollo — BANCI mensual

La sustitución vigente es `11_banci_mensual_bloque1.sql`. Requiere detener la API del ambiente, respaldo y paquetes API/Front del mismo bloque preparados. Probar primero en desarrollo/QA. Instrucciones: `../documentacion/banci_bloque1_instalacion.md`.

Los scripts 02–10 se retiraron porque reconstruían contratos incompatibles del modelo anterior. No ejecutar copias antiguas. Los significados compartidos de los catálogos se conservan en `estructura/08_significados_catalogos.sql`; el script 11 no borra sus columnas ni opciones.

El script 11 no elimina usuarios ni cargas de mensual/semanal/federal. Solo sustituye las tablas operativas BANCI vacías y retira los snapshots viejos de cruce; si encuentra datos operativos posteriores al inventario, aborta. La nueva carga por cortes se implementa en el siguiente bloque.
