USE [siiid2];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 THROW 52700, 'Ejecute sin transacciones abiertas.', 1;
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos, SERVERPROPERTY('Edition') AS edicion;
IF OBJECT_ID(N'dbo.banci_carga', N'U') IS NOT NULL OR OBJECT_ID(N'dbo.sistema_configuracion', N'U') IS NOT NULL THROW 52700, 'Esta instalación es solo para una base SIN BANCI ni configuración. No repetir ni usar en desarrollo ya instalado.', 1;
IF (SELECT compatibility_level FROM sys.databases WHERE name = DB_NAME()) < 130 THROW 52700, 'La API requiere compatibilidad SQL 130 o superior para OPENJSON.', 1;
IF OBJECT_ID(N'dbo.catalogo_municipios_inegi', N'U') IS NULL THROW 52700, 'Falta el catálogo geográfico INEGI. Revisar antes de instalar; no ejecutar un DROP para recrearlo.', 1;
IF OBJECT_ID(N'dbo.usuario_modulo', N'U') IS NULL OR OBJECT_ID(N'dbo.habilita_carga_modificacion', N'U') IS NULL THROW 52700, 'Falta estructura previa de permisos por módulo.', 1;
IF (SELECT COUNT(*) FROM dbo.catalogo_modulo WHERE clave IN (N'MENSUAL', N'SEMANAL', N'FEDERAL')) <> 3 THROW 52700, 'Faltan módulos previos.', 1;
IF COL_LENGTH(N'dbo.victima', N'curp_vicfem') IS NULL OR COL_LENGTH(N'dbo.carga_tmp_victima', N'curp_vicfem') IS NULL THROW 52700, 'Falta feminicidio de Consolidado: revisar scripts pendientes de producción antes de continuar.', 1;
GO
IF NOT EXISTS (SELECT 1 FROM dbo.catalogo_municipios_inegi WHERE poligono IS NOT NULL) THROW 52700, 'El catálogo geográfico está vacío.', 1;
IF EXISTS (SELECT 1 FROM dbo.catalogo_municipios_inegi WHERE poligono IS NULL OR poligono.STSrid <> 4326 OR poligono.STIsValid() = 0) THROW 52700, 'Revise polígonos nulos, inválidos o SRID distinto de 4326.', 1;
SELECT COUNT(*) AS poligonos_inegi FROM dbo.catalogo_municipios_inegi;
SELECT clave, activo FROM dbo.catalogo_modulo;
SELECT u.id_usuario, u.usuario FROM dbo.usuario u JOIN dbo.roles r ON r.id_rol = u.id_rol WHERE u.activo = 1 AND r.activo = 1 AND r.rol = N'SUPER_USUARIO';
