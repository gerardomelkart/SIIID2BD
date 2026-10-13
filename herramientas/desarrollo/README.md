# Herramientas de desarrollo

`01_borrar_registros_banci.sql` elimina los registros operativos de BANCI para reiniciar pruebas. Antes estaba en `desarrollo/01_borrar_registros_banci.sql`; su contenido no cambió.

Es una acción explícita de reinicio, no parte de una publicación. La comprobación del nombre de base que contiene el script no distingue por sí sola desarrollo de producción. Verificar servidor, base y carácter descartable de los datos antes de usarlo.

La reorganización del repositorio no requiere ejecutarlo. Para los requisitos de los ajustes históricos, consultar `../../desarrollo/README.md`.
