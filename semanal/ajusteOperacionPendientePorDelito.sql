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

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    THROW 53300, 'No existe dbo.semanal_carga.', 1;
GO

IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
    THROW 53301, 'No existe dbo.semanal_carga_bloque.', 1;
GO

IF COL_LENGTH(N'dbo.semanal_carga', N'id_delito') IS NULL
    THROW 53302, 'No existe semanal_carga.id_delito.', 1;
GO

IF COL_LENGTH(N'dbo.semanal_carga_bloque', N'id_delito') IS NULL
BEGIN
    ALTER TABLE dbo.semanal_carga_bloque
    ADD id_delito INT NULL;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE bloque
    SET bloque.id_delito = carga.id_delito
    FROM dbo.semanal_carga_bloque bloque
    INNER JOIN dbo.semanal_carga carga
        ON carga.id_semanal_carga = bloque.id_semanal_carga
    WHERE carga.id_delito IS NOT NULL
      AND
      (
          bloque.id_delito IS NULL
          OR bloque.id_delito <> carga.id_delito
      );

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND id_delito IS NULL
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
    )
    BEGIN
        THROW 53303, 'Existen bloques pendientes sin delito asociado.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'FK_semanal_carga_bloque_delito'
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga_bloque WITH CHECK
        ADD CONSTRAINT FK_semanal_carga_bloque_delito
            FOREIGN KEY (id_delito)
            REFERENCES dbo.catalogo_delito(id_delito);

        ALTER TABLE dbo.semanal_carga_bloque
        CHECK CONSTRAINT FK_semanal_carga_bloque_delito;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'CK_semanal_carga_bloque_delito_pendiente'
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga_bloque WITH CHECK
        ADD CONSTRAINT CK_semanal_carga_bloque_delito_pendiente
        CHECK
        (
            activo = 0
            OR estado NOT IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            OR id_delito IS NOT NULL
        );
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_usuario_carga,
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1
    )
    BEGIN
        SELECT
            id_usuario_carga,
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte,
            COUNT(*) AS bloques_pendientes
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_usuario_carga,
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1;

        THROW 53304, 'Existen bloques pendientes duplicados.', 1;
    END;

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
        id_delito,
        fecha_inicio_semana,
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

    PRINT N'Protección pendiente corregida por bloque lunes-domingo y delito.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO