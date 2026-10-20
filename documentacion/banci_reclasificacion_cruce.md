# BANCI: reclasificación por víctima y cruce del Consolidado

Esta entrega sustituye el bloque 5 pendiente del diseño de octubre. BANCI mensual conserva únicamente carga y actualización masivas. Federal y Semanal no participan en el cruce. No se habilita todavía un módulo diario.

## Reclasificación

Se utilizan `constitutiva_delito` y `motivo_desaparicion`, dentro de localización, sin nuevas columnas de captura. El motivo de Delito corresponde al catálogo existente de delitos/modalidades; el de No delito, a su catálogo de motivos. Las claves de significado se resuelven en BD, sin depender de números fijos.

Una víctima localizada se reclasifica cuando su condición es No delito, con motivo, o su delito reportado deja de pertenecer a desaparición. Cambiar a otro delito del catálogo de desaparición mantiene su vigencia. Cada víctima se evalúa de manera independiente; no se modifica la clasificación del delito de origen compartido con otras víctimas.

El cambio tiene efecto solo al aprobar. Los registros se conservan activos para consulta, actualización y reversión; `reclasificada=1` los excluye de la vista `vw_banci_desaparicion_vigente`. No se eliminan folios, relaciones ni complementos. El historial conserva los valores anteriores y nuevos; `banci_reclasificado` registra la víctima y el movimiento, incluidos los reversos. Para revertir, se reporta otra vez una clasificación de desaparición o se vuelve al estado No localizado, con la normalización habitual de sus campos.

## Cruce al actualizar el Consolidado

El cruce funciona únicamente para una entidad/corte que ya tenga datos aprobados en BANCI. Está condicionado por la opción `MENSUAL/CRUCE_ACTUALIZACION_CONSOLIDADO` y por BANCI activo. Desactivar solo el cruce conserva el funcionamiento de BANCI. Una operación ya vinculada conserva su resolución conjunta aunque posteriormente se desactive el cruce.

- Una desaparición vigente en BANCI no puede desaparecer de los archivos, cambiar identificadores ni convertirse en otro delito sin reclasificación aprobada previamente en BANCI.
- Una víctima reclasificada puede dejar de aparecer. Si se reporta con otro delito, debe coincidir con el delito/modalidad aprobado en BANCI; No delito exige retirarla de los delitos del Consolidado.
- Una reclasificación aprobada no puede reaparecer como desaparición sin aprobar primero su reversión en BANCI.
- Si una víctima reclasificada cambia de delito dentro de la misma carpeta, se comprueba por `id_ci + id_vicf`, únicamente cuando la identificación es inequívoca en ambos conjuntos. No se relacionan personas por nombre ni por posición. Las víctimas vigentes conservan la clave completa `id_ci + id_delito + id_vicf`.
- Una carpeta con todas sus víctimas reclasificadas deja de ser exigible; si queda alguna vigente, esa víctima sigue siendo obligatoria.
- Las nuevas desapariciones generan una plantilla BANCI de tres hojas, solo con los registros nuevos y sus padres. Esto incluye nuevas víctimas dentro de carpetas o delitos ya existentes. Los complementos se validan contra la información recibida en los tres archivos mensuales y se conserva el original realmente adjuntado.

El primer paso que solicita complementos no crea staging ni integra información. La siguiente validación vuelve a procesar los tres archivos mensuales junto con el XLSX BANCI. Los errores permiten corregirlo; cambiar periodo o archivos de origen descarta la selección complementaria anterior.

## Resolución conjunta

La validación guarda el staging mensual y el BANCI, y su vínculo, en una sola transacción. Se conserva snapshot/huella del BANCI aprobado. La API bloquea la resolución independiente del envío BANCI vinculado; se revisa y resuelve desde la aprobación mensual, con resumen, muestra y Excel BANCI.

Al enviar y aprobar se comprueba de nuevo la huella y se toma el bloqueo de entidad/corte. Si BANCI cambió, no se integra ninguna parte. La integración BANCI, la del Consolidado, sus estados e historiales comparten la misma transacción: cualquier fallo revierte ambas. El rechazo o descarte tampoco modifica definitivos.

Las validaciones propias no enviadas de BANCI del mismo remitente pueden ser sustituidas por el cruce, con bitácora. No se sustituyen envíos de otro usuario ni pendientes de aprobación. Los vínculos vencidos se liberan al continuar el flujo y conservan su historial y archivos.

## Instalación

1. Tener aplicados los scripts 11, 12 y 13 del modelo mensual. Respaldar BD y originales.
2. Durante la publicación coordinada, ejecutar **`desarrollo/14_banci_reclasificacion_cruce.sql`**. Es incremental, no borra datos; agrega metadatos de reclasificación, adapta el historial, reconstruye el indicador de los datos ya aprobados y habilita la opción de cruce. Una reejecución conserva una desactivación posterior de esa opción.
3. Publicar API y Front juntos, conservando `ArchivosOriginalesBanci` y `UltimosArchivosEntidad` según la configuración existente. El endpoint mensual admite el cuarto archivo complementario; conservar los límites de proxy adecuados a los archivos permitidos.
4. Validaciones antiguas sin vínculo, de cortes que ya tienen BANCI, deben descartarse y validarse otra vez antes de enviarlas/aprobarlas con el cruce activo.
5. Ejecutar en QA las pruebas siguientes y revisar `herramientas/desarrollo/04_verificar_reclasificacion_cruce.sql`.

El SQL no fue ejecutado en el servidor del usuario desde el entorno de desarrollo. Las pruebas automáticas de reglas, archivos y componentes no sustituyen esta prueba con SQL Server.

## Pruebas de aceptación en QA

1. Con dos víctimas del mismo delito, reclasificar una como No delito, enviar y rechazar: ambas siguen vigentes. Repetir y aprobar: solo la primera queda reclasificada, con motivo e historial.
2. Retirar solo esa víctima del Consolidado: permitir. Retirar también la segunda, vigente, o cambiarle sus identificadores: bloquear.
3. Reclasificar una víctima a otro delito; trasladarla en el Consolidado a un delito del mismo CI con clasificación coincidente: permitir. Con clasificación distinta o identidad ambigua: bloquear.
4. Reclasificar todas las víctimas de una carpeta y retirarla del Consolidado: permitir, conservando BANCI, sus folios y complementos.
5. Revertir una reclasificación en BANCI y aprobarla; volver a reportarla como desaparición en el Consolidado: permitir. Sin aprobar la reversión: bloquear.
6. Agregar una desaparición, incluso como víctima nueva de un delito existente: pedir plantilla de complementos, bloquear alteraciones de origen y registros omitidos/adicionales. Validar, enviar y aprobar: integrar ambos módulos y conservar el original complementario con su nombre.
7. Validar con superusuario: integración directa conjunta. Validar con enlace: ninguna integración antes de aprobar. Rechazar desde mensual: ambos envíos rechazados sin cambios en definitivos. Intentar resolver el vínculo desde BANCI: bloquear.
8. Cambiar BANCI después de validar, o enviar una operación concurrente del mismo corte: impedir la integración obsoleta o simultánea; no cambiar ninguno de los dos definitivos.
9. Probar cruce desactivado, BANCI desactivado, corte sin BANCI, falta de permisos para complementos, archivo corrupto y servicio RENAPO no disponible. Comprobar que Federal y Semanal mantienen sus flujos.
