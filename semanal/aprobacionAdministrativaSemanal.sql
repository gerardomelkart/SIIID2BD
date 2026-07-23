USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 50001, 'No existe dbo.semanal_carga. Ejecute primero la base del módulo semanal.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_advertencia', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga_advertencia
        (
            id_semanal_carga_advertencia BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            codigo NVARCHAR(150) NOT NULL,
            archivo NVARCHAR(50) NOT NULL,
            numero_fila INT NULL,
            columna NVARCHAR(150) NULL,
            campo NVARCHAR(150) NULL,
            valor NVARCHAR(1000) NULL,
            descripcion_resumen NVARCHAR(500) NOT NULL,
            mensaje NVARCHAR(2000) NOT NULL,
            aceptada_usuario BIT NOT NULL CONSTRAINT DF_semanal_carga_advertencia_aceptada DEFAULT (0),
            id_usuario_aceptacion INT NULL,
            fecha_aceptacion DATETIME2(0) NULL,
            activo BIT NOT NULL CONSTRAINT DF_semanal_carga_advertencia_activo DEFAULT (1),
            CONSTRAINT PK_semanal_carga_advertencia PRIMARY KEY (id_semanal_carga_advertencia),
            CONSTRAINT FK_semanal_carga_advertencia_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_carga_advertencia_usuario FOREIGN KEY (id_usuario_aceptacion) REFERENCES dbo.usuario(id_usuario)
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_advertencia')
          AND name = N'IX_semanal_carga_advertencia_carga'
    )
    BEGIN
        CREATE INDEX IX_semanal_carga_advertencia_carga
        ON dbo.semanal_carga_advertencia
        (
            id_semanal_carga,
            activo
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_advertencia')
          AND name = N'IX_semanal_carga_advertencia_codigo'
    )
    BEGIN
        CREATE INDEX IX_semanal_carga_advertencia_codigo
        ON dbo.semanal_carga_advertencia(codigo);
    END;

    COMMIT TRANSACTION;

    SELECT
        OBJECT_SCHEMA_NAME(t.object_id) AS esquema,
        t.name AS tabla,
        i.name AS indice,
        i.type_desc AS tipo_indice
    FROM sys.tables t
    LEFT JOIN sys.indexes i
        ON i.object_id = t.object_id
       AND i.index_id > 0
    WHERE t.object_id = OBJECT_ID(N'dbo.semanal_carga_advertencia')
    ORDER BY i.index_id;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
GO