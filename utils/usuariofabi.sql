USE [master];
GO

DECLARE @Contrasena NVARCHAR(128) = N'PassCNI2026!1234567890';

IF LEN(@Contrasena) < 16
BEGIN
    THROW 52000, 'La contraseña debe tener al menos 16 caracteres.', 1;
END;

IF SUSER_ID(N'fabiola.martinez') IS NULL
BEGIN
    DECLARE @SqlLogin NVARCHAR(MAX) =
        N'CREATE LOGIN [fabiola.martinez]
          WITH PASSWORD = ' + QUOTENAME(@Contrasena, '''') + N',
          DEFAULT_DATABASE = [siiid2],
          CHECK_POLICY = ON,
          CHECK_EXPIRATION = ON;';

    EXEC sys.sp_executesql @SqlLogin;

    PRINT N'Login fabiola.martinez creado.';
END
ELSE
BEGIN
    ALTER LOGIN [fabiola.martinez] WITH DEFAULT_DATABASE = [siiid2];

    PRINT N'El login fabiola.martinez ya existía.';
END;

SET @Contrasena = NULL;
GO

USE [siiid2];
GO

IF USER_ID(N'fabiola.martinez') IS NULL
BEGIN
    CREATE USER [fabiola.martinez]
    FOR LOGIN [fabiola.martinez]
    WITH DEFAULT_SCHEMA = [dbo];

    PRINT N'Usuario fabiola.martinez creado en siiid2.';
END
ELSE
BEGIN
    ALTER USER [fabiola.martinez] WITH LOGIN = [fabiola.martinez];

    PRINT N'El usuario fabiola.martinez ya existía.';
END;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_listado_nominal_lectura') IS NULL
BEGIN
    CREATE ROLE [rol_listado_nominal_lectura] AUTHORIZATION [dbo];

    PRINT N'Rol rol_listado_nominal_lectura creado.';
END;
GO

GRANT SELECT ON OBJECT::[dbo].[vw_listado_nominal_delitos]
TO [rol_listado_nominal_lectura];

GRANT SELECT ON OBJECT::[dbo].[vw_listado_nominal_victimas]
TO [rol_listado_nominal_lectura];
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    INNER JOIN sys.database_principals rol ON rol.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals miembro ON miembro.principal_id = drm.member_principal_id
    WHERE rol.name = N'rol_listado_nominal_lectura'
      AND miembro.name = N'fabiola.martinez'
)
BEGIN
    ALTER ROLE [rol_listado_nominal_lectura] ADD MEMBER [fabiola.martinez];

    PRINT N'Usuario agregado al rol de lectura.';
END
ELSE
BEGIN
    PRINT N'El usuario ya pertenecía al rol de lectura.';
END;
GO


USE [siiid2];
GO

GRANT SELECT ON OBJECT::[dbo].[tbl_carpetas] TO [rol_listado_nominal_lectura];
GRANT SELECT ON OBJECT::[dbo].[tbl_delitos] TO [rol_listado_nominal_lectura];
GRANT SELECT ON OBJECT::[dbo].[tbl_victimas] TO [rol_listado_nominal_lectura];
GO