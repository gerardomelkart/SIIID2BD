# BANCI mensual — preparación y plan de sustitución

Decisiones acordadas el 14 de octubre de 2026. Diseño de referencia del rediseño. El bloque 1 y su instalación coordinada se describen en `banci_bloque1_instalacion.md`; los bloques de carga, aprobación y cruce aún están pendientes.

## Fuentes revisadas

| Repositorio | Main revisado |
|---|---|
| SIIID.API | `0da9eea0bd3c3debbe31706bc70a0511960b2027` |
| SIIID2.FrontEnd | `c07c9bceb7dabf843724cd6db2dd160d07710329` |
| SIIID2BD | `aed5a23c8d3eb0c18a763ad7cf07782306a70154` |

## Comportamiento acordado

- BANCI solo toma el consolidado mensual; Federal queda completamente fuera.
- Corte correspondiente igual al mensual, calculado con la fecha civil de Ciudad de México. Se puede autorizar elegir cortes anteriores para carga histórica en el mismo módulo, no en otro módulo.
- La precarga parte exclusivamente del corte aceptado: todas sus carpetas con delitos de desaparición, solo esos delitos y las víctimas asociadas. Las demás clasificaciones de una misma carpeta no se incluyen.
- Identificadores y campos de origen se conservan; solo `no_banci` se genera, uno por carpeta, y no cambia al actualizarla. Se admite más de un delito de desaparición por carpeta y los tipos de víctima del consolidado.
- Excel único de tres pestañas (Carpetas, Delitos y Víctimas), con origen precargado y complementos BANCI. Manual: los mismos registros y campos de origen bloqueados.
- El conjunto de registros y los datos del origen deben coincidir exactamente. Protección de hojas Excel solo facilita la captura: la API verifica la información contra un snapshot confiable del servidor.
- Datos personales y localización pueden capturarse en el alta inicial. No se vuelve a forzar No localizado ignorando lo que se reportó.
- Histórico directo permitido únicamente para cortes anteriores cuando la opción correspondiente esté habilitada; si no hay origen consolidado aceptado para ese histórico, no se inventa una precarga. Cuando sí hay origen precargado, su protección se conserva.
- La opción de validaciones puede omitir validaciones de contenido, pero mantiene relaciones, duplicados, alcance del usuario, protección del origen precargado e integridad de la operación.
- Actualización BANCI: cualquier corte seleccionable, manual o masiva precargada; edición de datos personales y localización. La restricción de carga histórica no bloquea la selección de mes en actualización.
- Cargas y actualizaciones pasan por aprobación administrativa como en mensual; validar o enviar no equivale a integrar.
- Usuarios, configuración, aprobación, consulta de envíos, reporte de cargas y originales siguen el funcionamiento mensual, con alcance y datos propios de BANCI.
- Nuevo cruce únicamente en actualizaciones del consolidado; desactivable. Desactivar BANCI desactiva el cruce, pero desactivar el cruce no desactiva BANCI ni cambia sus reglas de carga propias.
- Con cruce activo, cambios de información ya reportada requieren actualización BANCI; nuevas desapariciones requieren complementos. La operación vinculada se aprueba de forma conjunta sin integración parcial.
- Omitir víctimas o cambiar identificadores mientras subsista el delito de desaparición es bloqueante.
- Quitar un delito de desaparición exige declarar su reclasificación: Delito/No delito y motivo. Solo ese delito y sus víctimas pasan a reclasificados. Si quedan otras desapariciones, la carpeta sigue vigente y mantiene `no_banci`.
- La conservación de reclasificados incluye vínculos, complementos e historial. El borrado autorizado corresponde a pruebas anteriores a la sustitución, no al funcionamiento futuro.

## Datos y versión de origen

La referencia mensual existente reconstruye información aceptada con `InformeRepository.ObtenerCarpetasConfirmadasPeriodoAsync`, `ObtenerDelitosConfirmadosPeriodoAsync` y `ObtenerVictimasConfirmadasPeriodoAsync`. Relaciona `carga`, `carpeta_investigacion`, `delito`, `victima` y los catálogos compartidos. Estados aceptados actuales: `CONFIRMADO` y `CONFIRMADO_ACTUALIZACION`, según tipo de operación.

No se debe copiar solamente la última carga y asumir que contiene todas las filas vigentes: las consultas actuales consideran cargas aceptadas del período y registros activos. El diseño debe preservar ese comportamiento al extraer el subconjunto de desaparición. Tampoco se debe interpretar el estado más reciente de un intento rechazado como versión aceptada.

La precarga deberá registrar entidad, corte, versión aceptada de origen, snapshot completo y huella. Antes de enviar y aprobar se verificará que el origen no haya cambiado; si cambió, se pedirá regenerar la precarga. La comparación conservará valores y tratará las representaciones de fechas/números de Excel de manera consistente, sin permitir modificar su contenido. La definición de desaparición proviene de los catálogos/configuración vigentes, no de listas en C# o TS.

Los IDs externos son claves compuestas en su ámbito: carpeta + delito + víctima, entidad y corte para la operación. No se supondrá unicidad global de un ID de víctima ni se generarán sustitutos. La identificación de una carpeta y su `no_banci` estable debe mantener también el vínculo con el registro fuente del consolidado.

## Disposición de los componentes actuales

| Componente real | Disposición prevista |
|---|---|
| `banci_carpeta_investigacion`, `banci_delito`, `banci_victima` | Sustituir su estructura operativa para cortes, origen, tipos de víctima y conservación; no conservar columnas del modelo descartado por compatibilidad. |
| `banci_carga`, `banci_carga_archivo`, `banci_carga_bitacora_estado`, `banci_carga_observacion` | Adaptar al ciclo de envío y aprobación mensual, originales y trazabilidad. |
| `banci_carga_tmp_carpeta`, `banci_carga_tmp_delito`, `banci_carga_tmp_victima` | Redefinir como staging del contrato nuevo, incluyendo snapshot de origen. |
| `banci_actualizacion_v2` | Sustituir por el ciclo de operaciones y aprobación equivalente a mensual; retirar cuando todas sus llamadas hayan sido reemplazadas. |
| `banci_historial_cambio`, `banci_consecutivo_carpeta` | Conservar el concepto de historial/consecutivo, revisando claves y vínculos del nuevo modelo. |
| `banci_cruce_mensual`, `banci_cruce_federal` | Retirar ambos snapshots del cruce anterior. El nuevo vínculo es una operación de actualización, no reutiliza esos contratos. |
| `fn_banci_es_usuario_federal`, `id_usuario_reporte_federal` y ramas federales de `fn_banci_puede_actualizar_victima` | Retirar exclusividad/facultades federales BANCI y revisar dependientes antes de eliminar. |
| Procedimientos BANCI originales y `_v2` | Identificar llamadas reales, reemplazar el contrato operativo y retirar los SP sustituidos; no dejar dos versiones funcionales por compatibilidad. |
| Catálogos viejos `banci_catalogo_voluntaria`, `banci_catalogo_fue_delito`, `banci_catalogo_motivo_localizacion` | Candidatos a retiro, previa comprobación de referencias instaladas; reemplazados por constitutiva/motivo. |
| `banci_catalogo_constitutiva_delito`, `banci_catalogo_motivo_no_delito`, localización y condición de vida | Conservar/adaptar las opciones particulares aún vigentes, incluidas en alta y actualización. |
| `catalogo_*`, `vw_catalogos_reglas`, `CatalogoReglasRepository` | Compartidos: conservar. Ajustar la vista al retirar catálogos exclusivos viejos; no romper mensual, semanal ni federal. |
| `usuario`, `roles`, `usuario_modulo`, `sistema_configuracion` y bitácoras compartidas | Conservar cuentas/permisos/configuración; modificar únicamente relaciones/opciones BANCI necesarias. No borrar usuarios. |
| `usp_mantenimiento_banci` y coordinador `usp_mantenimiento_siiid2` | Adaptar referencias y retención al modelo nuevo; nunca limpiar reclasificados por estar fuera del conjunto vigente. |
| Scripts anteriores de `desarrollo/`, `catalogos/banci.sql`, `estructura/04_banci.sql` y herramienta de borrado | Reemplazar secuencias incompatibles con una instalación/sustitución coherente. No reejecutar archivos viejos que reinstalen objetos retirados. |

La autorización de limpiar pruebas no autoriza vaciar tablas compartidas ni datos de mensual/federal/semanal. El script de sustitución tendrá una lista explícita de objetos, orden de dependencias, comprobaciones de versión y una transacción. No se ejecutará un DROP genérico por prefijo.

## Dependencias concretas de API y Front

- El cruce anterior no vive solo en `BanciCruceController`/`BanciCruceService`: aparece en `CargaArchivosService`, `ActualizacionArchivosService`, `CargaRepository`, `ActualizacionCargaRepository`, `FederalCargaArchivosService`, `FederalActualizacionArchivosService`, `FederalCargaRepository` y `FederalActualizacionRepository`. Federal debe quedar sin ninguna llamada BANCI.
- Se retirarán `BanciAltaNormalizer` y la generación automática de IDs CI/DEL/VIC al sustituir el alta. `BanciMetodologiaValidator` debe dejar de vaciar localización y forzar su estado. Las validaciones compartidas no se eliminan.
- El Front conecta el flujo anterior mediante `core/services/banci-cruce.service.ts`, utilidades/tablas del cruce, carga inicial y actualización mensual, aprobación y las tres pantallas federales. El iframe opcional anterior y su retorno se reemplazan por el flujo vinculante del nuevo cruce.
- `banci-layout`, rutas, controladores, modelos, servicios y pruebas deben reflejar carga por corte, configuración, aprobación e informes. No se conservarán endpoints antiguos para simular compatibilidad.
- Los originales en disco, generación de plantillas, limpieza programada y rutas de publicación también se revisarán; eliminar tablas no limpia esas referencias.

## Bloques y pruebas de aceptación

| Bloque | Resultado verificable en QA |
|---|---|
| 1. Esquema/configuración y retiro anterior | Pruebas borradas solo en BANCI; estructura nueva; no referencias federales BANCI; catálogos compartidos intactos; mensual/semanal/federal siguen operando. |
| 2. Carga inicial | Origen aceptado correcto; tres pestañas/manual equivalentes; ni más ni menos; múltiples desapariciones; moral/física; localización inicial; histórico controlado; edición de origen bloqueada. |
| 3. Aprobación e informes | Envío no integra; aprobar integra; rechazar conserva original/bitácora; filtros, permisos y descarga equivalentes a mensual. |
| 4. Actualización | Precarga del corte elegido; solo campos permitidos; aprobación; historial y folio conservados. |
| 5. Nuevo cruce/reclasificación | Cambio de IDs y omisión de víctima bloqueantes; altas complementadas; reclasificación parcial; ninguna pérdida; aprobación/rechazo conjunta; cruce apagado y módulo apagado. |
| 6. Cierre de limpieza | Sin rutas, tipos, SP, vistas, columnas, tablas, imports, scripts ni jobs sustituidos; búsquedas de referencias y catálogo de objetos real revisados nuevamente. |

Cada bloque será un commit por repositorio afectado en main, sin ramas nuevas. El DDL y las llamadas de API/Front dependientes se entregarán en coordinación: no borrar objetos mientras siga publicada una versión que los use. Un bloque debe quedar utilizable o temporalmente inhabilitado de forma explícita; no se dejarán botones apuntando a contratos retirados.

## Inventario necesario antes del DDL

Ejecutar `herramientas/desarrollo/02_inventario_modelo_banci.sql` en QA y devolver todos los resultados en archivo. En SSMS, configurar Resultados en texto a 8192 caracteres por columna, abrir una ventana nueva y activar resultados a archivo con Ctrl+Shift+F antes de ejecutar; evita perder fragmentos de definiciones. Incluye objetos, columnas, restricciones, índices, dependencias, definiciones fragmentadas, permisos, secuencias, sinónimos, configuración y referencias de SQL Agent cuando sean visibles. No exporta registros personales ni modifica objetos o datos persistentes.

Las dependencias catalogadas no detectan por sí solas SQL dinámico o consumidores externos. Se contrastarán también los cuerpos instalados, llamadas de los tres repos y mantenimiento/jobs. Si los jobs no son visibles, el resultado lo indica: su ausencia en el inventario no equivale a que no existan.

Se recibió el inventario completo del servidor el 15/10/2026. La sustitución del bloque 1 está preparada; su aceptación requiere ejecutar el script y las pruebas de la guía en desarrollo/QA.
