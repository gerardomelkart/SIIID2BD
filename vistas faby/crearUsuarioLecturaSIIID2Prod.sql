/*
    Ejecutar en el SQL Server nuevo de produccion: 10.100.75.51,1433.
    Crea un login dedicado que solamente puede consultar las cinco vistas
    de compatibilidad de la base siiid2.

    IMPORTANTE:
    1. Pegar el valor solamente entre las comillas de @Contrasena.
    2. Usar exactamente la misma contrasena en el script 02.
    3. No guardar ni compartir la copia que contenga la contrasena real.
*/

USE [siiid2];

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @NombreLogin SYSNAME = N'siiid2_inc20_lectura';
DECLARE @Contrasena NVARCHAR(128) = N'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%*-_=+'; -- Pegar aqui la contrasena nueva.

IF DB_NAME() <> N'siiid2'
BEGIN
    THROW 51001, 'Este script debe ejecutarse en la base siiid2 del servidor nuevo de produccion.', 1;
END;

IF LEN(ISNULL(@Contrasena, N'')) < 16 OR LEN(@Contrasena) > 128
BEGIN
    THROW 51002, 'Reemplaza @Contrasena por una contrasena segura de 16 a 128 caracteres.', 1;
END;

DECLARE @VistasRequeridas TABLE (nombre SYSNAME PRIMARY KEY);

INSERT INTO @VistasRequeridas (nombre)
VALUES
    (N'tbl_carpetas'),
    (N'tbl_delitos'),
    (N'tbl_victimas'),
    (N'vw_listado_nominal_delitos'),
    (N'vw_listado_nominal_victimas');

IF EXISTS
(
    SELECT 1
    FROM @VistasRequeridas r
    WHERE OBJECT_ID(N'dbo.' + r.nombre, N'V') IS NULL
)
BEGIN
    SELECT r.nombre AS vista_faltante
    FROM @VistasRequeridas r
    WHERE OBJECT_ID(N'dbo.' + r.nombre, N'V') IS NULL
    ORDER BY r.nombre;

    THROW 51003, 'Falta una o mas vistas de compatibilidad en siiid2. No se creo el acceso remoto.', 1;
END;

IF SUSER_ID(@NombreLogin) IS NULL
BEGIN
    DECLARE @CrearLogin NVARCHAR(MAX) =
        N'CREATE LOGIN ' + QUOTENAME(@NombreLogin) +
        N' WITH PASSWORD = N''' + REPLACE(@Contrasena, N'''', N'''''') +
        N''', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF, DEFAULT_DATABASE = [siiid2];';

    EXEC sys.sp_executesql @CrearLogin;
    PRINT N'Se creo el login dedicado de lectura.';
END
ELSE
BEGIN
    PRINT N'El login dedicado ya existia; su contrasena no fue modificada.';
END;

DECLARE @ConfigurarLogin NVARCHAR(MAX) =
    N'ALTER LOGIN ' + QUOTENAME(@NombreLogin) + N' ENABLE; ' +
    N'ALTER LOGIN ' + QUOTENAME(@NombreLogin) + N' WITH DEFAULT_DATABASE = [siiid2];';

EXEC sys.sp_executesql @ConfigurarLogin;

IF DATABASE_PRINCIPAL_ID(@NombreLogin) IS NULL
BEGIN
    CREATE USER [siiid2_inc20_lectura] FOR LOGIN [siiid2_inc20_lectura];
END
ELSE
BEGIN
    ALTER USER [siiid2_inc20_lectura] WITH LOGIN = [siiid2_inc20_lectura];
END;

GRANT SELECT ON OBJECT::dbo.tbl_carpetas TO [siiid2_inc20_lectura];
GRANT SELECT ON OBJECT::dbo.tbl_delitos TO [siiid2_inc20_lectura];
GRANT SELECT ON OBJECT::dbo.tbl_victimas TO [siiid2_inc20_lectura];
GRANT SELECT ON OBJECT::dbo.vw_listado_nominal_delitos TO [siiid2_inc20_lectura];
GRANT SELECT ON OBJECT::dbo.vw_listado_nominal_victimas TO [siiid2_inc20_lectura];

SET @Contrasena = NULL;

SELECT
    dp.name AS usuario,
    OBJECT_SCHEMA_NAME(p.major_id) AS esquema,
    OBJECT_NAME(p.major_id) AS objeto,
    p.permission_name AS permiso,
    p.state_desc AS estado_permiso
FROM sys.database_permissions p
INNER JOIN sys.database_principals dp ON dp.principal_id = p.grantee_principal_id
WHERE dp.name = @NombreLogin
  AND p.permission_name = N'SELECT'
  AND p.class_desc = N'OBJECT_OR_COLUMN'
ORDER BY objeto;

PRINT N'Acceso remoto de solo lectura preparado correctamente en siiid2.';
