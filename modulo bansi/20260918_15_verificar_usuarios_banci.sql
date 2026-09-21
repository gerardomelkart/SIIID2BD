-- Sólo lectura. Ejecutar después de instalar el script 15, en la base que se está probando.
USE [siiid2];
GO
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos;

SELECT clave, nombre, activo FROM dbo.catalogo_modulo ORDER BY id_modulo;

SELECT u.id_usuario, u.usuario, r.rol, u.id_entidad_federativa, u.activo AS cuenta_activa,
    cm.activo AS modulo_activo, um.habilitado, um.habilita_carga, um.habilita_modificacion, um.activo AS membresia_activa,
    CONVERT(bit, CASE WHEN u.activo = 1 AND r.activo = 1 AND cm.activo = 1
        AND (r.rol = N'SUPER_USUARIO' OR (um.activo = 1 AND um.habilitado = 1)) THEN 1 ELSE 0 END) AS acceso_banci
FROM dbo.usuario u
INNER JOIN dbo.roles r ON r.id_rol = u.id_rol
CROSS JOIN dbo.catalogo_modulo cm
LEFT JOIN dbo.usuario_modulo um ON um.id_usuario = u.id_usuario AND um.id_modulo = cm.id_modulo
WHERE cm.clave = N'BANCI'
ORDER BY r.rol, u.usuario;

SELECT p.name AS procedimiento, p.modify_date,
    CASE WHEN sm.definition LIKE N'%MENSUAL%' THEN N'REVISAR: contiene dependencia mensual' ELSE N'Sin referencia mensual' END AS revision_texto
FROM sys.procedures p INNER JOIN sys.sql_modules sm ON sm.object_id = p.object_id
WHERE p.name IN (N'sp_banci_vista_previa', N'sp_banci_confirmar_carga');

SELECT p.name AS procedimiento, a.name AS parametro, a.is_output
FROM sys.procedures p INNER JOIN sys.parameters a ON a.object_id = p.object_id
WHERE p.name = N'sp_banci_vista_previa' AND a.name = N'@PuedeAceptar';
-- Debe aparecer @PuedeAceptar con is_output = 1. Cero filas indica que falta el script 15.

SELECT um.id_usuario, um.id_modulo, COUNT(*) AS duplicados
FROM dbo.usuario_modulo um GROUP BY um.id_usuario, um.id_modulo HAVING COUNT(*) > 1;
-- Debe devolver cero filas.
