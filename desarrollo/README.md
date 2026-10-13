# Ajustes de desarrollo

Estos scripts reflejan etapas de desarrollo de BANCI. No constituyen una migración general de producción. Conservar su numeración y revisar el estado de las tablas y procedimientos antes de elegir qué ejecutar.

| Script | Alcance y requisitos |
|---|---|
| `02_ajustar_estructura_banci.sql` | Ajustes de BANCI v3. Requiere estructura BANCI v2, tablas operativas vacías y API detenida, tal como indica el script. No conserva datos existentes. |
| `03_ids_legibles_banci.sql` | Ajuste posterior de identificadores legibles. Revisar junto con el estado dejado por 02. |
| `04_motivo_desaparicion_banci.sql` | Ajustes de clasificación y motivo de desaparición. |
| `05_cruce_consolidado_banci.sql` | Estructura y procedimientos del cruce con Consolidado. |
| `06_cruce_previo_federal_banci.sql` | Incremental sobre 05: requiere `banci_cruce_mensual`; incorpora el cruce previo Federal. |

El script 01 de borrado se movió, sin modificar su contenido, a `../herramientas/desarrollo/01_borrar_registros_banci.sql`. Las referencias históricas a ese nombre dentro de 02 corresponden a esa nueva ubicación. No ejecutarlo como paso de publicación sobre una base con información que deba conservarse.

Las redefiniciones de un mismo procedimiento representan revisiones sucesivas. No eliminarlas solo porque comparten nombre ni ejecutar versiones anteriores sobre una instalación posterior. Esta reorganización no modifica ni ejecuta SQL y no certifica el esquema instalado en un servidor.
