USE [siiid2];
GO
SET NOCOUNT ON;
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos, SERVERPROPERTY('Edition') AS edicion;
SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID();
SELECT clave, nombre, activo FROM dbo.catalogo_modulo ORDER BY id_modulo;
SELECT s.name AS esquema, o.name AS objeto, o.type_desc FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id WHERE o.is_ms_shipped = 0 AND (o.name LIKE N'banci[_]%' OR o.name LIKE N'sp[_]banci[_]%' OR o.name LIKE N'sistema[_]%' OR o.name = N'sp_sistema_configuracion_cambiar') ORDER BY o.type_desc, o.name;
SELECT c.name AS columna, TYPE_NAME(c.user_type_id) AS tipo FROM sys.columns c WHERE c.object_id = OBJECT_ID(N'dbo.victima') AND c.name IN (N'nombre_vicfem', N'primer_apellido_vicfem', N'segundo_apellido_vicfem', N'curp_vicfem');
-- No consultar contraseñas ni datos personales de víctimas.
SELECT u.id_usuario, u.usuario, r.rol, u.activo FROM dbo.usuario u JOIN dbo.roles r ON r.id_rol = u.id_rol WHERE r.rol = N'SUPER_USUARIO' AND u.activo = 1 AND r.activo = 1 ORDER BY u.id_usuario;
