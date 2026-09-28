# SIIID2 — Base de datos

SQL Server para Consolidado (Mensual), Semanal, Federal, BANCI y Configuración del sistema.

## Organización

| Carpeta | Contenido |
|---|---|
| `catalogos/` | Catálogos generales, municipios INEGI, actualización de códigos postales, Federal y BANCI. |
| `estructura/` | Base inicial y ajustes agrupados por módulo; índices y vistas de compatibilidad. |
| `mantenimiento/` | Cuatro procedimientos de limpieza, un coordinador y el ejecutor Linux. |

La reorganización parte del commit `4586325`. Los scripts históricos de publicación, migración FGR, pruebas, borrado de datos, alta de usuarios, jobs individuales, DBML y dbdiagram se retiraron del árbol actual. Siguen recuperables en el historial Git. No se reescribió ese historial.

## Modelo de datos

| Módulo | Prefijo | Función |
|---|---|---|
| Consolidado | Sin prefijo de módulo | Carpetas, delitos y víctimas de remisiones mensuales. |
| Semanal | `semanal_` | Remisiones por periodo y delito configurado; bloques y aprobación. |
| Federal | `federal_` | Remisiones federales y sus históricos. |
| BANCI | `banci_` | Ingreso y actualización de carpetas, delitos y víctimas, con trazabilidad de operaciones. |

En los módulos de remisión, una carga agrupa las filas de `carga_tmp_carpeta`, `carga_tmp_delito` y `carga_tmp_victima` (con el prefijo correspondiente). La validación y aprobación deciden su integración. Las tablas definitivas forman la relación carpeta → delito → víctima; las tablas históricas conservan versiones anteriores.

Los temporales no son descartables indiscriminadamente: pueden respaldar una operación pendiente, un rechazo administrativo vigente o los acuses de BANCI. La carga, sus archivos, observaciones y bitácoras documentan el proceso.

`banci_actualizacion_v2` conserva propuestas JSON y su decisión (`PENDIENTE`, `INTEGRADA`, `RECHAZADA`); `banci_historial_cambio` puede referenciar esas operaciones. Este mantenimiento conserva ambas tablas.

Los catálogos aportan claves geográficas y clasificaciones. Los polígonos municipales INEGI respaldan el cruce de coordenadas. Configuración del sistema contiene reglas activables por módulo y administración de accesos; no se deben restablecer sus valores al reorganizar archivos.

## Alcance de estructura

**Es referencia técnica, no una exportación completa de la base actual ni un instalador para ejecutar sobre producción.** El repositorio original combina una estructura inicial con modificaciones posteriores; agruparlas no permite certificar que reflejen todos los objetos del servidor.

- `01_base.sql`: estructura inicial; se retiraron `DROP DATABASE`, el cambio a usuario único y la creación automática de la base. Requiere una base vacía seleccionada.
- `02_semanal.sql`: bases y ajustes del módulo semanal.
- `03_federal.sql`: estructura Federal; catálogos separados.
- `04_banci.sql`: secuencia de definiciones del paquete de instalación utilizado para publicar BANCI; se conserva la variante que omite asignaciones masivas de permisos.
- `05_configuracion.sql`: estructura, procedimientos, administradores y reglas (incluidas coordenadas y cruce pendiente).
- `06_ajustes_comunes.sql`: índices y cambios compartidos, incluido feminicidio de Consolidado.
- `07_vistas_compatibilidad.sql`: vistas locales Mensual, Semanal y Federal.

Cada sección identifica el archivo fuente. Se conservan secuencias de ajustes y redefiniciones cuando son necesarias para interpretar las dependencias; el número del archivo no establece por sí solo un orden de creación de una base completa. Algunos bloques heredados contienen `USE siiid2`, cambios de catálogos o valores iniciales: no utilizarlos para construir QA automáticamente. Para crear un ambiente equivalente use respaldo/restauración o una exportación del esquema real revisada, como se hizo con `SIIID2_QA`.

## Mantenimiento unificado

Instalar en la base elegida los archivos `mantenimiento/01_mensual.sql` a `05_general.sql`, en ese orden. **Instalar los SP no ejecuta la limpieza.** Estos cinco archivos no contienen `USE` fijo. Verifique `SELECT DB_NAME();` en SSMS antes de instalarlos y use una ventana sin transacciones abiertas.

El coordinador conserva el nombre y los parámetros existentes:

```sql
-- Seleccionar siiid2 o SIIID2_QA antes de ejecutar.
SET IMPLICIT_TRANSACTIONS OFF;
EXEC dbo.usp_mantenimiento_general
    @EjecutarMantenimiento = 0,
    @ActualizarEstadisticas = 0;
```

Simula Mensual → Semanal → Federal → BANCI y registra el resultado en `dbo.mantenimiento_ejecucion`. La simulación ejecuta DELETE y ROLLBACK: consume recursos y toma bloqueos; no es una consulta sin efectos operativos. Para aplicar, cambiar ambos parámetros a `1`, después de revisar la simulación en QA y disponer de respaldo.

| Módulo | Política |
|---|---|
| Mensual, Semanal, Federal | Mantienen las reglas existentes de protección de pendientes y último rechazo administrativo vigente. Limpian otros temporales; no eliminan definitivos ni históricos. |
| BANCI | Solo temporales de cargas `RECHAZADO_VALIDACION` con antigüedad superior a 90 días tanto en fecha de carga como en la fecha de decisión/fin disponible. Conserva cargas procesadas, pendientes, estados ERROR, cabeceras, archivos, observaciones, bitácoras, actualizaciones e históricos. |

BANCI no elimina los temporales de cargas procesadas porque pueden intervenir en los acuses. Los detalles temporales de rechazos antiguos sí desaparecen al aplicar la política; cabecera y observaciones permanecen. `@DiasRetencion` permite ampliar la retención al ejecutar directamente `usp_mantenimiento_banci` (mínimo 90 días). El general usa 90.

Cada módulo confirma su propia transacción; si falla uno, los anteriores pueden haber terminado y los posteriores quedan omitidos. Las estadísticas se actualizan después del COMMIT: un fallo de estadísticas no revierte una limpieza ya confirmada. El general usa un bloqueo de aplicación para impedir dos ejecuciones generales simultáneas. Ejecutar fuera de las cargas de usuarios: se bloquean cabeceras de cargas durante la limpieza.

Se corrigieron dos problemas del código anterior: protecciones Mensual/Semanal calculadas antes de la transacción, y reportes posteriores al ROLLBACK que dependían de tablas temporales revertidas. Se conservan los conteos anteriores y las filas afectadas; se retiró el reporte posterior redundante.

## Linux y programación

`mantenimiento/ejecutarMantenimientoGeneral.sh` conserva su interfaz:

```bash
/home/opc/mantenimiento_siiid2/ejecutarMantenimientoGeneral.sh simular
/home/opc/mantenimiento_siiid2/ejecutarMantenimientoGeneral.sh aplicar
```

Al actualizar el servidor, copiar ese ejecutor a la ruta utilizada por el cron existente. No es necesario cambiar la llamada del cron si se mantiene esa ruta. El repositorio no instala cron ni modifica servicios.

Lee `/home/opc/.config/siiid2/mantenimiento.env` (o `SIIID_MANTENIMIENTO_CONFIG`) con `SQLCMD_SERVER`, `SQLCMD_USER` y `SQLCMDPASSWORD`; opcionalmente `SQLCMD_BIN`, `SQLCMD_TRUST_SERVER_CERTIFICATE` y `SQLCMD_DATABASE`. La base predeterminada sigue siendo `siiid2`; para QA use un archivo de configuración separado con `SQLCMD_DATABASE=SIIID2_QA`. Mantener las credenciales fuera de Git y el archivo con permisos 600. Los logs se guardan en `/home/opc/mantenimiento_siiid2/logs`, configurable con `SIIID_MANTENIMIENTO_LOG_DIR`.

## Verificación y publicación

Esta reorganización cambia el repositorio; no modifica QA ni producción. Se verificaron sintaxis Bash, propagación del código de error de sqlcmd, selección de base y conservación de catálogos. **Los SP nuevos requieren validación real en QA antes de instalarlos en producción.** No se afirma que coincidan con procedimientos modificados directamente en el servidor: deben compararse con esas definiciones si hubo cambios fuera de Git.
