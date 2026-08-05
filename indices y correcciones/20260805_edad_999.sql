USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.victima', N'edad') IS NULL
    THROW 50080, 'No existe dbo.victima.edad.', 1;

IF COL_LENGTH(N'dbo.victima_historico', N'edad') IS NULL
    THROW 50081, 'No existe dbo.victima_historico.edad.', 1;

IF COL_LENGTH(N'dbo.semanal_victima', N'edad') IS NULL
    THROW 50082, 'No existe dbo.semanal_victima.edad.', 1;

IF COL_LENGTH(N'dbo.semanal_victima_historico', N'edad') IS NULL
    THROW 50083, 'No existe dbo.semanal_victima_historico.edad.', 1;
GO

DECLARE @RecrearIndiceVictimaCarga BIT =
    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.victima')
          AND name = N'IX_victima_carga_activo_delito_identificador'
    ) THEN 1 ELSE 0 END;

DECLARE @RecrearIndiceVictimaSabanas BIT =
    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.victima')
          AND name = N'IX_victima_sabanas_carga_activo_delito'
    ) THEN 1 ELSE 0 END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF @RecrearIndiceVictimaCarga = 1
        DROP INDEX IX_victima_carga_activo_delito_identificador ON dbo.victima;

    IF @RecrearIndiceVictimaSabanas = 1
        DROP INDEX IX_victima_sabanas_carga_activo_delito ON dbo.victima;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.victima') AND name = N'edad' AND system_type_id <> TYPE_ID(N'smallint'))
        ALTER TABLE dbo.victima ALTER COLUMN edad SMALLINT NULL;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.victima_historico') AND name = N'edad' AND system_type_id <> TYPE_ID(N'smallint'))
        ALTER TABLE dbo.victima_historico ALTER COLUMN edad SMALLINT NULL;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.semanal_victima') AND name = N'edad' AND system_type_id <> TYPE_ID(N'smallint'))
        ALTER TABLE dbo.semanal_victima ALTER COLUMN edad SMALLINT NULL;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.semanal_victima_historico') AND name = N'edad' AND system_type_id <> TYPE_ID(N'smallint'))
        ALTER TABLE dbo.semanal_victima_historico ALTER COLUMN edad SMALLINT NULL;

    IF @RecrearIndiceVictimaCarga = 1
    BEGIN
        CREATE INDEX IX_victima_carga_activo_delito_identificador
        ON dbo.victima (
            id_carga,
            activo,
            id_delito,
            identificador_victima_fiscalia
        )
        INCLUDE (
            id_victima,
            id_tipo_victima,
            id_tipo_victima_moral,
            id_sexo,
            id_genero,
            id_nacionalidad,
            id_pertenece_poblacion_indigena,
            id_presenta_discapacidad,
            fecha_nacimiento,
            edad
        );
    END;

    IF @RecrearIndiceVictimaSabanas = 1
    BEGIN
        CREATE INDEX IX_victima_sabanas_carga_activo_delito
        ON dbo.victima (
            id_carga,
            activo,
            id_delito
        )
        INCLUDE (
            id_tipo_victima,
            id_sexo,
            edad
        );
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS esquema,
    OBJECT_NAME(c.object_id) AS tabla,
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.victima'),
    OBJECT_ID(N'dbo.victima_historico'),
    OBJECT_ID(N'dbo.semanal_victima'),
    OBJECT_ID(N'dbo.semanal_victima_historico')
)
  AND c.name = N'edad'
ORDER BY tabla;
GO