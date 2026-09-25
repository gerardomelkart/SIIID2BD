USE [siiid2];
GO
SET NOCOUNT ON;
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos;
IF EXISTS (SELECT 1 FROM dbo.catalogo_modulo WHERE clave = N'BANCI' AND activo = 1) THROW 52700, 'La primera publicación debe dejar BANCI apagado.', 1;
IF EXISTS (SELECT 1 FROM (VALUES (N'sp_banci_procesar_carga'), (N'sp_banci_confirmar_carga'), (N'sp_banci_calcular_actualizacion_v2'), (N'sp_sistema_administrador_cambiar')) t(nombre) WHERE OBJECT_ID(N'dbo.' + t.nombre, N'P') IS NULL) THROW 52700, 'Faltan procedimientos finales.', 1;
IF OBJECT_ID(N'dbo.banci_vw_victimas_v2', N'V') IS NULL OR OBJECT_ID(N'dbo.sistema_validacion_configuracion', N'U') IS NULL THROW 52700, 'Faltan objetos finales.', 1;
IF (SELECT COUNT(*) FROM dbo.sistema_configuracion WHERE clave IN (N'COORDENADAS_MUNICIPIO', N'COORDENADAS_MUNICIPIO_HOMICIDIO_DOLOSO')) <> 5 THROW 52700, 'Faltan opciones de municipio.', 1;
IF (SELECT COUNT(*) FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo = c.id_modulo WHERE m.clave IN (N'MENSUAL', N'FEDERAL') AND c.clave = N'CRUCE_BANCI' AND c.habilitado = 0 AND c.disponible = 0) <> 2 THROW 52700, 'Los cruces BANCI deben permanecer pendientes.', 1;
SELECT m.clave AS modulo, c.clave, c.descripcion, c.habilitado, c.disponible FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo = c.id_modulo ORDER BY m.id_modulo, c.clave;
SELECT u.usuario, a.activo AS administra_sistema FROM dbo.sistema_administrador a JOIN dbo.usuario u ON u.id_usuario = a.id_usuario;
SELECT clave, activo FROM dbo.catalogo_modulo;
SELECT version, fecha_modificacion FROM dbo.sistema_configuracion_version WHERE id = 1;
