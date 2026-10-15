# BANCI mensual — bloque 1

## Entrega y alcance

El bloque 1 sustituye el modelo anterior, retira su cruce y prepara el esquema mensual. **Carga, actualización e informes BANCI no están habilitados todavía**: el Front muestra preparación y conserva usuarios. No es la entrega completa de BANCI por cortes; el siguiente bloque implementa precarga aceptada, Excel de tres pestañas y manual.

Se retiraron los controladores, lectores, normalizadores, validadores, DTO, servicios, pantallas, utilidades y pruebas que solo correspondían al modelo anterior. No quedan endpoints antiguos de escritura disponibles. Mensual y Federal dejan de llamar a BANCI al validar, guardar, confirmar o aprobar. Federal pierde también el privilegio especial dentro de usuarios BANCI; sus datos y permisos propios de Federal se conservan.

Se conserva la validación local de CURP en `CurpFormatoValidator`: eliminar el servicio viejo de BANCI no elimina las reglas locales de mensual/federal ni las dependencias de feminicidio/RENAPO.

## Inventario utilizado

Inventario recibido del servidor `sesnspcni-siinid`, base `siiid2`, SQL Server `17.0.4045.5`, compatibilidad 170, el 15/10/2026 a las 09:24. Se reconstruyeron los 21 módulos de la sección 09 respetando fragmentos y CRLF. Las tablas operativas estaban vacías; los snapshots anteriores contenían 269 filas mensuales y 5 federales. Estos snapshots duplicados se retiran, sin borrar sus cargas de origen.

Las dependencias y restricciones se contrastaron con las secciones 02–08; el mantenimiento general instalado llama a `usp_mantenimiento_banci`, cuya firma se conserva. El inventario no mostró permisos específicos de objetos, sinónimos ni pasos SQL Agent relacionados.

## Qué conserva y prepara el esquema

- Conserva usuarios, relaciones de acceso, catálogos compartidos y particulares vigentes. Las vistas de catálogos de motivos se conservan; la vista operativa de víctimas V2 se retira.
- `banci_carga` incorpora corte, tipo de operación, estado, aprobación, origen aceptado, snapshot y huella. Los originales, observaciones y bitácoras quedan relacionados con esa operación.
- `banci_carga_tmp_*` guardan filas de origen y propuestas separadas; los datos permanentes siguen en tablas relacionales de carpeta, delito y víctima.
- Los IDs externos `id_ci`, `id_delito`, `id_vicf` no tienen generación ni defaults. Los IDs internos de relación siguen siendo identidades SQL, como en los otros módulos.
- Se retira la restricción de un solo delito por carpeta; se conserva la unicidad de los IDs en su ámbito. Se recuperan tipos de víctima y catálogos compartidos.
- Se separan los campos copiados del consolidado de los complementos personales/localización. No hay default que reemplace localización reportada por No localizado.
- `no_banci` pertenece a una carpeta estable de la entidad y no se cambia por actualización; la asignación desde el sistema se implementa en el bloque de integración.
- `banci_reclasificado` referencia el delito conservado y su operación; guarda snapshot previo y motivo. La conservación de las víctimas originales no requiere borrarlas.
- `banci_operacion_vinculada` prepara la relación uno a uno entre actualización mensual y operación BANCI; no ejecuta el nuevo cruce todavía.
- Se eliminan los SP de procesamiento/confirmación originales y V2, sus funciones federales, el cruce viejo, actualización V2 y catálogos particulares ya sustituidos.
- El mantenimiento solo purga staging de rechazos vencidos; no elimina definitivos, originales, bitácoras, historial ni reclasificados.

Opciones nuevas en BANCI: `VALIDACIONES_CAMPOS` activa; `PERMITIR_CORTES_ANTERIORES` y `CRUCE_ACTUALIZACION_CONSOLIDADO` desactivadas y no disponibles hasta implementar sus bloques. Se retira `CRUCE_BANCI` de mensual/federal. La bitácora histórica de configuración no se borra.

## Instalación de una base existente

1. Probar primero en desarrollo o QA. El inventario recibido era de la base `siiid2` del servidor; no sustituye la prueba de ejecución en QA.
2. Respaldar esa base y detener la API correspondiente y su mantenimiento durante la instalación. Preparar los nuevos paquetes API/Front antes de comenzar: el código viejo no es compatible con el esquema nuevo.
3. Ejecutar **únicamente** `desarrollo/11_banci_mensual_bloque1.sql` en la conexión/base seleccionada. No tiene USE fijo. No ejecutar estructura/04 ni los scripts 02–10 antiguos.
4. El script aborta si encuentra registros operativos BANCI posteriores al inventario o dependencias externas no previstas. No vacía tablas compartidas. Los DROP usan una lista explícita, en una transacción; un error revierte el conjunto.
5. Publicar API y Front del bloque 1 y arrancar la API. Sin esos paquetes no reanudar la aplicación con el esquema nuevo.
6. Ejecutar `herramientas/desarrollo/03_verificar_banci_bloque1.sql` y probar los puntos siguientes.

Reejecutar el script 11 sobre una instalación completa reconoce la estructura y no vuelve a borrar datos. Si no se puede publicar el código nuevo después de aplicar el esquema, restaurar el respaldo junto con las versiones previas; no ejecutar scripts históricos para intentar reconstruir el modelo anterior.

Para una instalación nueva, crear primero base/usuarios/catálogos compartidos, luego `catalogos/banci.sql`, `estructura/04_banci.sql`, configuración y `estructura/08_significados_catalogos.sql`. Instalar también el mantenimiento actualizado. La carpeta estructura conserva otras secuencias históricas del sistema y no es un instalador completo de cero.

## Prueba manual del bloque 1

- Iniciar sesión en mensual, semanal y federal; validar, enviar, aprobar/rechazar con archivos habituales. No debe ofrecer actualización BANCI ni guardar snapshots del cruce anterior.
- Verificar sábanas y originales de esos módulos; el cambio no modifica sus consultas ni datos estadísticos.
- Entrar a BANCI: solo inicio de preparación y usuarios. Las rutas viejas de carga/formulario/actualización/consulta ya no deben mostrar formularios operativos.
- En API, los endpoints viejos de carga/cruce/actualización BANCI ya no existen. `GET /api/banci/modelo` requiere sesión/acceso y muestra `instalado=true` después del script.
- Probar listado, edición y permisos de usuarios BANCI. Un enlace necesita una entidad territorial activa; no tiene la excepción federal anterior. Ninguna cuenta de los otros módulos se elimina.
- Revisar configuración: desaparece el cruce viejo. Las opciones nuevas no disponibles no se pueden activar aún. Mensual/federal conservan que apagar feminicidio apaga RENAPO y apagar RENAPO no apaga feminicidio.
- Ejecutar mantenimiento general en simulación y verificar que termina sin referencias V2. No deben desaparecer datos ni reclasificados.

Las pruebas automáticas verifican compilación, reglas compartidas, rutas retiradas y pantalla transitoria. El SQL se analiza también dentro de sus bloques dinámicos y se contrasta con el inventario; no se ejecutó en el servidor desde este entorno. La ejecución de QA y las pruebas manuales son el cierre de aceptación de este bloque antes de empezar carga.
