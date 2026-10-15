# BANCI: vistas y operación mensual

Entrega coordinada posterior al bloque 1. Recupera el diseño original del módulo: barra institucional, menú lateral, tarjeta de usuario, colores, bienvenida y accesos. No utiliza la pantalla provisional ni los endpoints del modelo retirado.

## Vistas

- Carga masiva y manual: entidad/corte, precarga del consolidado aceptado, plantilla única con Carpetas, Delitos y Victimas, validación por campo y envío.
- Actualización masiva y manual: selección de cortes sin depender del permiso de históricos, precarga de BANCI aprobado, edición de datos personales y localización. Carpetas, delitos, tipos de víctima e identificadores permanecen protegidos.
- Consulta de envíos: estados, motivos, detalle de las tres hojas, ordenamiento, paginación y descarga de la tabla.
- Reporte de cargas y archivos originales: acceso de superusuario. Cada original se conserva separado por referencia; una captura manual guarda el libro equivalente.
- Aprobación administrativa: revisión de registros y diferencias personales/localización, aprobación o rechazo motivado. Los enlaces envían a revisión; los superusuarios integran directamente, como mensual.
- Usuarios: conserva el CRUD y sus controles de cuentas protegidas.
- Configuración: acceso/carga/actualización por usuario, permisos operativos globales, autorización de cortes anteriores y validaciones de contenido. Los cambios de reglas usan versión y motivo, con bitácora.

Las opciones de catálogo se consultan en la base. Se reutilizan los validadores del consolidado para los campos compartidos y sus significados de catálogo. CURP conserva validación local sin depender de RENAPO. Las consultas externas dependen de su configuración y conectividad; si RENAPO no está disponible, el informe previo muestra la advertencia.

## Protección e integración

El origen se obtiene exclusivamente de registros activos de cargas mensuales aceptadas del mismo corte/entidad, filtrando el catálogo BANCI de desapariciones. Federal no interviene. Se conservan víctimas físicas y morales y todos los delitos de desaparición de una carpeta.

La validación comprueba el conjunto completo de carpetas/delitos/víctimas, sus identificadores y los campos protegidos. El Excel guarda IDs como texto. En históricos sin consolidado aceptado, con autorización, se admite captura directa; incluso sin validaciones de contenido se verifican relaciones, duplicados, tipos, tamaños y claves existentes para evitar truncamientos o errores al aprobar.

Un envío validado conserva snapshot y huella del origen. Al aprobar se vuelve a leer el origen bajo transacción y se rechaza la integración si cambió. La integración, estados e historial se confirman juntos; el bloqueo por entidad/corte impide integrar dos cargas simultáneamente. Un nuevo envío del remitente sustituye su validación anterior; una carga en revisión debe resolverse antes de volver a enviar.

Los IDs fiscales se conservan. Solo se genera `no_banci`, con el formato anterior `BANCI/EE/AAAA/NNNNNN`, al aprobar una carpeta. En actualización se conserva ese folio y solo se registran en historial los campos que realmente cambiaron.

## Instalación y prueba

1. Aplicar primero en desarrollo/QA. Detener API, respaldar y preparar los paquetes coordinados.
2. Si ya aplicó el bloque 1, ejecutar **solo** `desarrollo/12_banci_mensual_operacion.sql`. Si falta el bloque 1, aplicar primero el 11 actualizado. El 12 no elimina ni recrea datos; amplía campos heredados y habilita la disponibilidad de históricos sin activar el permiso.
3. Publicar API y Front de esta entrega. Conservar la carpeta `ArchivosOriginalesBanci` en la raíz de contenido de la API en cada publicación y respaldo; la cuenta de la API necesita escritura en ella. No queda bajo wwwroot.
4. Probar acceso de superusuario, enlace, consulta estatal y consulta nacional; Federal no debe tener un trato especial.
5. Precargar un corte con consolidado aceptado y desapariciones. Probar masiva/manual, localización inicial y datos de personas físicas/morales. Descargar nuevamente el original después de enviar.
6. Alterar nomenclatura/delito/tipo de víctima, omitir o agregar registros: debe mostrar errores por fila y permitir descargar sus observaciones.
7. Con enlace, confirmar y revisar que quede pendiente; aprobar/rechazar con superusuario. Verificar que no haya definitivos antes de aprobar y que rechazo conserve su original y motivo.
8. Probar actualización por otro corte, diferencias de personales/localización, estabilidad de no_banci e historial solo de campos modificados. Cambiar el origen después de validar debe impedir aprobar un envío obsoleto.
9. Probar históricos activados/desactivados y con/sin origen; desactivar contenido no permite romper integridad ni cambiar campos protegidos.
10. Verificar que mensual, semanal y Federal sigan independientes.

La compilación, las regresiones de reglas/Excel y las pruebas de componentes/contratos no sustituyen esta prueba de integración con SQL Server. No se ejecutó SQL en el servidor del usuario desde este entorno.

## Bloque separado

El nuevo cruce dentro de actualizaciones del consolidado y la reclasificación con aprobación conjunta siguen en el bloque 5 del diseño acordado. Su opción permanece desactivada y no disponible; esta entrega no la habilita ni vuelve a instalar el cruce anterior.
