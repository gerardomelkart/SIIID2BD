USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF OBJECT_ID(N'dbo.usuario', N'U') IS NULL
    THROW 50100, 'No existe dbo.usuario.', 1;

IF COL_LENGTH(N'dbo.usuario', N'rfc') IS NULL
    THROW 50101, 'No existe dbo.usuario.rfc.', 1;

IF COL_LENGTH(N'dbo.usuario', N'curp') IS NULL
    THROW 50102, 'No existe dbo.usuario.curp.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'uk_usuario_rfc'
    )
        ALTER TABLE dbo.usuario DROP CONSTRAINT [uk_usuario_rfc];

    IF EXISTS (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'uk_usuario_curp'
    )
        ALTER TABLE dbo.usuario DROP CONSTRAINT [uk_usuario_curp];

    IF EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'rfc'
          AND is_nullable = 0
    )
        ALTER TABLE dbo.usuario ALTER COLUMN rfc NVARCHAR(13) NULL;

    IF EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'curp'
          AND is_nullable = 0
    )
        ALTER TABLE dbo.usuario ALTER COLUMN curp NVARCHAR(18) NULL;

    UPDATE dbo.usuario
    SET rfc = NULL
    WHERE rfc IS NOT NULL
      AND LTRIM(RTRIM(rfc)) = N'';

    UPDATE dbo.usuario
    SET curp = NULL
    WHERE curp IS NOT NULL
      AND LTRIM(RTRIM(curp)) = N'';

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'ux_usuario_rfc_no_nulo'
    )
        CREATE UNIQUE INDEX [ux_usuario_rfc_no_nulo]
        ON dbo.usuario (rfc)
        WHERE rfc IS NOT NULL;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'ux_usuario_curp_no_nulo'
    )
        CREATE UNIQUE INDEX [ux_usuario_curp_no_nulo]
        ON dbo.usuario (curp)
        WHERE curp IS NOT NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.max_length / 2 AS longitud,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(N'dbo.usuario')
  AND c.name IN (N'rfc', N'curp')
ORDER BY c.name;

SELECT
    i.name AS indice,
    i.is_unique,
    i.has_filter,
    i.filter_definition
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID(N'dbo.usuario')
  AND i.name IN (
      N'ux_usuario_rfc_no_nulo',
      N'ux_usuario_curp_no_nulo'
  )
ORDER BY i.name;
GO