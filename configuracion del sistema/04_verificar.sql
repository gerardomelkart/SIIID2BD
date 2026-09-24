USE [siiid2];
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.sistema_configuracion', N'U') IS NULL THROW 52600, 'No está instalada la configuración del sistema.', 1;
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos;
SELECT version, fecha_modificacion AS fecha_utc FROM dbo.sistema_configuracion_version WHERE id = 1;
SELECT u.id_usuario, u.usuario, r.rol, a.activo AS permiso_activo, u.activo AS usuario_activo
FROM dbo.sistema_administrador a JOIN dbo.usuario u ON u.id_usuario = a.id_usuario JOIN dbo.roles r ON r.id_rol = u.id_rol;
SELECT clave AS modulo, nombre, activo FROM dbo.catalogo_modulo WHERE clave IN (N'MENSUAL', N'SEMANAL', N'FEDERAL', N'BANCI') ORDER BY id_modulo;
SELECT m.clave AS modulo, c.clave, c.descripcion, c.habilitado AS valor_configurado, c.disponible,
    CAST(CASE WHEN m.activo = 0 OR c.disponible = 0 OR c.habilitado = 0 THEN 0
        WHEN m.clave = N'MENSUAL' AND c.clave = N'RENAPO' AND NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion f WHERE f.id_modulo = m.id_modulo AND f.clave = N'FEMINICIDIO_DATOS_ADICIONALES' AND f.habilitado = 1) THEN 0
        WHEN c.clave = N'CRUCE_BANCI' AND NOT EXISTS (SELECT 1 FROM dbo.catalogo_modulo b WHERE b.clave = N'BANCI' AND b.activo = 1) THEN 0
        ELSE 1 END AS BIT) AS valor_efectivo_para_api
FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo = c.id_modulo ORDER BY m.id_modulo, c.clave;
SELECT TOP (50) id, fecha_utc, id_usuario, ejecutor_sql, modulo, clave, valor_anterior, valor_nuevo, motivo, version FROM dbo.sistema_configuracion_bitacora ORDER BY id DESC;
SELECT OBJECT_ID(N'dbo.sp_sistema_configuracion_cambiar', N'P') AS procedimiento_cambio;
-- valor_efectivo_para_api describe el contrato de la próxima API. La API actual aún no consume estos interruptores.
