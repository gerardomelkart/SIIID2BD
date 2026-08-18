USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_delito', N'U') IS NULL
        THROW 50001, 'No existe la tabla dbo.semanal_delito.', 1;

    IF OBJECT_ID(N'dbo.semanal_delito_historico', N'U') IS NULL
        THROW 50002, 'No existe la tabla dbo.semanal_delito_historico.', 1;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_delito', N'U') IS NULL
        THROW 50003, 'No existe la tabla dbo.semanal_carga_tmp_delito.', 1;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_victima', N'U') IS NULL
        THROW 50004, 'No existe la tabla dbo.semanal_carga_tmp_victima.', 1;

    IF COL_LENGTH(N'dbo.semanal_delito', N'identificador_delito_fiscalia') < 500
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.semanal_delito')
              AND name = N'IX_semanal_delito_carga_carpeta_identificador'
        )
        BEGIN
            DROP INDEX IX_semanal_delito_carga_carpeta_identificador
            ON dbo.semanal_delito;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.semanal_delito')
              AND name = N'IX_semanal_delito_carpeta_identificador_activo'
        )
        BEGIN
            DROP INDEX IX_semanal_delito_carpeta_identificador_activo
            ON dbo.semanal_delito;
        END;

        ALTER TABLE dbo.semanal_delito
        ALTER COLUMN identificador_delito_fiscalia NVARCHAR(250) NOT NULL;

        CREATE INDEX IX_semanal_delito_carga_carpeta_identificador
        ON dbo.semanal_delito
        (
            id_semanal_carga,
            activo,
            id_semanal_carpeta_investigacion,
            identificador_delito_fiscalia
        )
        INCLUDE
        (
            id_semanal_delito,
            id_catalogo_delito
        );

        CREATE INDEX IX_semanal_delito_carpeta_identificador_activo
        ON dbo.semanal_delito
        (
            id_semanal_carpeta_investigacion,
            identificador_delito_fiscalia,
            activo,
            id_semanal_carga
        )
        INCLUDE
        (
            id_semanal_delito,
            id_catalogo_delito
        );
    END;

    IF COL_LENGTH(N'dbo.semanal_delito_historico', N'identificador_delito_fiscalia') < 500
    BEGIN
        ALTER TABLE dbo.semanal_delito_historico
        ALTER COLUMN identificador_delito_fiscalia NVARCHAR(250) NOT NULL;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga_tmp_delito', N'id_delito') < 500
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_tmp_delito')
              AND name = N'IX_semanal_tmp_delito_carga_ci_delito'
        )
        BEGIN
            DROP INDEX IX_semanal_tmp_delito_carga_ci_delito
            ON dbo.semanal_carga_tmp_delito;
        END;

        ALTER TABLE dbo.semanal_carga_tmp_delito
        ALTER COLUMN id_delito NVARCHAR(250) NOT NULL;

        CREATE INDEX IX_semanal_tmp_delito_carga_ci_delito
        ON dbo.semanal_carga_tmp_delito
        (
            id_semanal_carga,
            id_ci,
            id_delito,
            incluido
        );
    END;

    IF COL_LENGTH(N'dbo.semanal_carga_tmp_victima', N'id_delito') < 500
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_tmp_victima')
              AND name = N'IX_semanal_tmp_victima_carga_ci_delito'
        )
        BEGIN
            DROP INDEX IX_semanal_tmp_victima_carga_ci_delito
            ON dbo.semanal_carga_tmp_victima;
        END;

        ALTER TABLE dbo.semanal_carga_tmp_victima
        ALTER COLUMN id_delito NVARCHAR(250) NOT NULL;

        CREATE INDEX IX_semanal_tmp_victima_carga_ci_delito
        ON dbo.semanal_carga_tmp_victima
        (
            id_semanal_carga,
            id_ci,
            id_delito,
            incluido
        );
    END;

    COMMIT TRANSACTION;

    PRINT 'El campo id_delito semanal fue ampliado correctamente a 250 caracteres.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO