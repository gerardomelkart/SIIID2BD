# Ajustes de desarrollo

Estos scripts reflejan etapas de desarrollo de BANCI. No constituyen una migración general de producción. Conservar su numeración y revisar el estado de las tablas y procedimientos antes de elegir qué ejecutar.

| Script | Alcance y requisitos |
|---|---|
| `02_ajustar_estructura_banci.sql` | Ajustes de BANCI v3. Requiere estructura BANCI v2, tablas operativas vacías y API detenida, tal como indica el script. No conserva datos existentes. |
| `03_ids_legibles_banci.sql` | Ajuste posterior de identificadores legibles. Revisar junto con el estado dejado por 02. |
| `04_motivo_desaparicion_banci.sql` | Ajustes de clasificación y motivo de desaparición. |
| `05_cruce_consolidado_banci.sql` | Estructura y procedimientos del cruce con Consolidado. |
| `06_cruce_previo_federal_banci.sql` | Incremental sobre 05: requiere `banci_cruce_mensual`; incorpora el cruce previo Federal. |
| `07_observaciones_banci_20261013.sql` | Incremental seguro para **POB/DISC exclusivamente**: migra el 0 antiguo a la clave 2, elimina los CHECK heredados y crea FK a las claves de los catálogos institucionales. Se puede ejecutar por separado en Desarrollo/QA/Producción, seleccionando la base. No cambia procedimientos. |

El script 01 de borrado se movió, sin modificar su contenido, a `../herramientas/desarrollo/01_borrar_registros_banci.sql`. Las referencias históricas a ese nombre dentro de 02 corresponden a esa nueva ubicación. No ejecutarlo como paso de publicación sobre una base con información que deba conservarse.

Las redefiniciones de un mismo procedimiento representan revisiones sucesivas. No eliminarlas solo porque comparten nombre ni ejecutar versiones anteriores sobre una instalación posterior. Esta reorganización no modifica ni ejecuta SQL y no certifica el esquema instalado en un servidor.

## Ajuste 07 — catálogos de BANCI (octubre de 2026)

Respaldar la base, detener la operación de BANCI y seleccionar explícitamente la base correcta en SSMS antes de ejecutar. El script **no contiene USE ni una variable para aplicar/no aplicar**; es idempotente y conserva los registros de staging, históricos y auditoría. Sólo migra `dbo.banci_victima.pob/disc` desde 0 (No) a 2 (No), retira los CHECK 0/1 y añade FK a `catalogo_pertenece_poblacion_indigena(clave)` y `catalogo_presenta_discapacidad(clave)`. Se comprueban catálogos, valores y cargas/actualizaciones pendientes antes de cambiar datos. Las claves activas se verifican en la API (no mediante valores fijos en BANCI).

**Fechas/FUB son un despliegue distinto:** las definiciones de referencia de `sp_banci_procesar_carga_v2`, `sp_banci_vista_previa_v2` y `sp_banci_calcular_actualizacion_v2` están corregidas en el script fuente `06_cruce_previo_federal_banci.sql`: desde octubre de 2024 y FUB opcional. **No vuelva a ejecutar 06 sobre una base existente**: contiene otros cambios de instalación y podría sobrescribir definiciones distintas instaladas en cada ambiente. Para actualizar esos tres SP en Desarrollo/QA/Producción, primero comparar sus definiciones reales y preparar scripts `CREATE OR ALTER` específicos, con aprobación de despliegue. Ejecutar 07 por sí solo NO aplica los cambios de fecha/FUB a los procedimientos de la base. El cruce con el mes reportado en Consolidado permanece independiente y sin modificaciones.
