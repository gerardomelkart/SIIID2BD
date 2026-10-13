# Ajustes de desarrollo

Estos scripts reflejan etapas de desarrollo de BANCI. No constituyen una migración general de producción. Conservar su numeración y revisar el estado de las tablas y procedimientos antes de elegir qué ejecutar.

| Script | Alcance y requisitos |
|---|---|
| `02_ajustar_estructura_banci.sql` | Ajustes de BANCI v3. Requiere estructura BANCI v2, tablas operativas vacías y API detenida, tal como indica el script. No conserva datos existentes. |
| `03_ids_legibles_banci.sql` | Ajuste posterior de identificadores legibles. Revisar junto con el estado dejado por 02. |
| `04_motivo_desaparicion_banci.sql` | Ajustes de clasificación y motivo de desaparición. |
| `05_cruce_consolidado_banci.sql` | Estructura y procedimientos del cruce con Consolidado. |
| `06_cruce_previo_federal_banci.sql` | Incremental sobre 05: requiere `banci_cruce_mensual`; incorpora el cruce previo Federal. |
| `07_observaciones_banci_20261013.sql` | Incremental posterior a 06: amplía el periodo BANCI a octubre 2024–mes actual; elimina la obligatoriedad de FUB en confirmación, vista previa y actualización; migra POB/DISC 0→2 y restringe 1–4 en definitivos. **Requiere no tener cargas abiertas, validar previamente los catálogos compartidos y probar en QA.** |

El script 01 de borrado se movió, sin modificar su contenido, a `../herramientas/desarrollo/01_borrar_registros_banci.sql`. Las referencias históricas a ese nombre dentro de 02 corresponden a esa nueva ubicación. No ejecutarlo como paso de publicación sobre una base con información que deba conservarse.

Las redefiniciones de un mismo procedimiento representan revisiones sucesivas. No eliminarlas solo porque comparten nombre ni ejecutar versiones anteriores sobre una instalación posterior. Esta reorganización no modifica ni ejecuta SQL y no certifica el esquema instalado en un servidor.

## Ajuste 07 — observaciones BANCI (octubre de 2026)

No ejecutar 02 ni el borrado de herramientas para aplicar 07. Seleccionar la base explícitamente en SSMS, verificar los catálogos compartidos y respaldar la base. El script **no contiene USE, DROP TABLE, DROP DATABASE ni TRUNCATE**. Realiza prevalidaciones y desiste sin aplicar cambios si hay cargas BANCI abiertas o si las definiciones vigentes de los tres procedimientos difieren de la versión esperada del script 06. Modifica únicamente `dbo.banci_victima` (restricciones y 0→2) y las definiciones de `sp_banci_procesar_carga_v2`, `sp_banci_vista_previa_v2` y `sp_banci_calcular_actualizacion_v2`. Los históricos, staging, FUB, CURP e ID_TV/ID_TPM físicos se conservan. No ejecutarlo en producción sin probar antes la operación completa en QA y revisar el estado real del esquema.
