USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.carga', N'U') IS NULL
    THROW 50090, 'No existe dbo.carga.', 1;

IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    THROW 50091, 'No existe dbo.semanal_carga.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.carga', N'rechazo_visto') IS NULL
    BEGIN
        ALTER TABLE dbo.carga
        ADD rechazo_visto BIT NOT NULL CONSTRAINT DF_carga_rechazo_visto DEFAULT (1) WITH VALUES;
    END;

    IF COL_LENGTH(N'dbo.carga', N'fecha_rechazo_visto') IS NULL
    BEGIN
        ALTER TABLE dbo.carga
        ADD fecha_rechazo_visto DATETIME2(0) NULL;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga', N'rechazo_visto') IS NULL
    BEGIN
        ALTER TABLE dbo.semanal_carga
        ADD rechazo_visto BIT NOT NULL CONSTRAINT DF_semanal_carga_rechazo_visto DEFAULT (1) WITH VALUES;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga', N'fecha_rechazo_visto') IS NULL
    BEGIN
        ALTER TABLE dbo.semanal_carga
        ADD fecha_rechazo_visto DATETIME2(0) NULL;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    OBJECT_NAME(c.object_id) AS tabla,
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id IN (OBJECT_ID(N'dbo.carga'), OBJECT_ID(N'dbo.semanal_carga'))
  AND c.name IN (N'rechazo_visto', N'fecha_rechazo_visto')
ORDER BY tabla, columna;
GO