USE [siiid2];
GO
SET NOCOUNT ON;
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos;
SELECT t.name AS tabla, c.name AS columna, TYPE_NAME(c.user_type_id) AS tipo, c.max_length, c.is_nullable FROM sys.tables t JOIN sys.columns c ON c.object_id = t.object_id WHERE t.name IN (N'federal_carga_tmp_victima', N'federal_victima', N'federal_victima_historico') AND c.name IN (N'nombre_vicfem', N'primer_apellido_vicfem', N'segundo_apellido_vicfem', N'curp_vicfem') ORDER BY t.name, c.column_id;
SELECT m.clave AS modulo, c.clave, c.habilitado, c.disponible FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo = c.id_modulo WHERE m.clave = N'FEDERAL';
SELECT OBJECT_ID(N'dbo.sp_sistema_administrador_cambiar', N'P') AS procedimiento_administradores;
SELECT u.id_usuario, u.usuario, a.activo AS administra_sistema FROM dbo.usuario u JOIN dbo.roles r ON r.id_rol = u.id_rol LEFT JOIN dbo.sistema_administrador a ON a.id_usuario = u.id_usuario WHERE u.activo = 1 AND r.activo = 1 AND r.rol = N'SUPER_USUARIO' ORDER BY u.usuario;
SELECT TOP (20) b.id, b.fecha_utc, actor.usuario AS ejecutor, objetivo.usuario AS usuario_objetivo, b.valor_anterior, b.valor_nuevo, b.motivo, b.version FROM dbo.sistema_configuracion_bitacora b LEFT JOIN dbo.usuario actor ON actor.id_usuario = b.id_usuario LEFT JOIN dbo.usuario objetivo ON objetivo.id_usuario = b.id_usuario_objetivo WHERE b.clave = N'ADMINISTRADOR_ACCESO' ORDER BY b.id DESC;
