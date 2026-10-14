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

| `08_periodo_y_fub_banci_20261013.sql` | Incremental posterior al 07. Modifica únicamente dos restricciones de fecha y tres validaciones FUB de los procedimientos BANCI v2 instalados; valida cada bloque, conserva el resto y aborta si una variante es desconocida. Probar primero en Desarrollo y QA. |

El script 01 de borrado se movió, sin modificar su contenido, a `../herramientas/desarrollo/01_borrar_registros_banci.sql`. Las referencias históricas a ese nombre dentro de 02 corresponden a esa nueva ubicación. No ejecutarlo como paso de publicación sobre una base con información que deba conservarse.

Las redefiniciones de un mismo procedimiento representan revisiones sucesivas. No eliminarlas solo porque comparten nombre ni ejecutar versiones anteriores sobre una instalación posterior. Esta reorganización no modifica ni ejecuta SQL y no certifica el esquema instalado en un servidor.

## Ajuste 07 — catálogos de BANCI (octubre de 2026)

Respaldar la base, detener la operación de BANCI y seleccionar explícitamente la base correcta en SSMS antes de ejecutar. El script **no contiene USE ni una variable para aplicar/no aplicar**; es idempotente y conserva los registros de staging, históricos y auditoría. Sólo migra `dbo.banci_victima.pob/disc` desde 0 (No) a 2 (No), retira los CHECK 0/1 y añade FK a `catalogo_pertenece_poblacion_indigena(clave)` y `catalogo_presenta_discapacidad(clave)`. Se comprueban catálogos, valores y cargas/actualizaciones pendientes antes de cambiar datos. Las claves activas se verifican en la API (no mediante valores fijos en BANCI).

**Fechas/FUB son un despliegue distinto:** las definiciones de referencia de `sp_banci_procesar_carga_v2`, `sp_banci_vista_previa_v2` y `sp_banci_calcular_actualizacion_v2` están corregidas en el script fuente `06_cruce_previo_federal_banci.sql`: desde octubre de 2024 y FUB opcional. **No vuelva a ejecutar 06 sobre una base existente**: contiene otros cambios de instalación y podría sobrescribir definiciones distintas instaladas en cada ambiente. Para actualizar esos tres SP en Desarrollo/QA/Producción, ejecute **08_periodo_y_fub_banci_20261013.sql** después del 07 con respaldo y operación BANCI detenida; el 08 ajusta únicamente bloques reconocidos de los procedimientos instalados y rechaza definiciones desconocidas. No ejecute el 06 completo. Ejecutar 07 por sí solo NO aplica los cambios de fecha/FUB a los procedimientos de la base. El cruce con el mes reportado en Consolidado permanece independiente y sin modificaciones.

## Ajuste 09 — homologación de catálogos y CP

Ejecutar `09_catalogos_y_cp_banci.sql` primero en QA, con la base seleccionada y una ventana sin confirmaciones en ejecución. Requiere el 07 de POB/DISC y la API vigente; no volver a ejecutar la estructura completa. Si CP ya se amplió manualmente a 100, el paso se omite.

El ajuste retira CHECK con listas/rangos fijos y conserva o crea FK a los catálogos existentes de tipos de víctima, sexo, género, población indígena, discapacidad, nacionalidad, forma de acción, instrumento y grado de consumación. Verifica entidad y municipio contra las mismas tablas compartidas de Consolidado. Los catálogos específicos de BANCI conservan sus propias relaciones; clasificación de desaparición y motivo no se sustituyen por modalidades de Consolidado.

CP queda como `NVARCHAR(100) NULL`, igual que staging. No se transforman datos, no se modifican catálogos ni SP, y se conservan cargas pendientes para reintentar su decisión. Las FK se verifican con `WITH CHECK`; si hay datos definitivos ajenos al catálogo o una relación apunta a otra columna, la transacción se revierte íntegramente. La API continúa comprobando claves activas.

### 10 — Significados de catálogos

Ejecutar `10_significados_catalogos.sql` en cada base antes de publicar la API y el Front de este cambio, después de 09. También se ejecuta en instalaciones nuevas, después de estructuras y semillas. Agrega `codigo_regla` a las opciones existentes y la vista `vw_catalogos_reglas`. No altera claves ni descripciones, ni procesa datos operativos. Es transaccional y repetible; preserva códigos ya configurados y exige una opción activa por significado requerido. Las reglas permanecen en C#. Si una clave se sustituye, conservar su código de significado en la nueva opción.

El ajuste 10 también sustituye las listas fijas de localización/condición de vida/constitutiva en la guarda del SP de actualización y obtiene el estado inicial desde el catálogo en los SP de carga y vista previa. Conserva las definiciones instaladas mediante sustituciones verificadas, sin copiar versiones anteriores ni alterar permisos. Mantiene el CHECK de campos emparejados y las claves foráneas. No ejecuta cargas ni modifica víctimas existentes. Si no reconoce la versión instalada revierte la transacción completa.
