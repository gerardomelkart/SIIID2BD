USE siiid2;
GO

SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.semanal_carga', N'id_delito') IS NULL
        THROW 53300, 'No existe semanal_carga.id_delito.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
          AND name = N'UX_semanal_carga_operacion_pendiente'
    )
    BEGIN
        DROP INDEX UX_semanal_carga_operacion_pendiente
        ON dbo.semanal_carga;
    END;

    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_operacion_pendiente
    ON dbo.semanal_carga
    (
        id_usuario_carga,
        id_entidad_federativa,
        id_delito,
        anio_semana,
        numero_semana
    )
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      );

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'UX_semanal_carga_bloque_pendiente'
    )
    BEGIN
        DROP INDEX UX_semanal_carga_bloque_pendiente
        ON dbo.semanal_carga_bloque;
    END;

    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_bloque_pendiente
    ON dbo.semanal_carga_bloque
    (
        id_usuario_carga,
        id_entidad_federativa,
        id_semanal_carga,
        anio_semana,
        numero_semana,
        anio_corte,
        mes_corte
    )
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      );

    COMMIT TRANSACTION;

    PRINT N'Índices preliminares corregidos para separar operaciones por delito.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO