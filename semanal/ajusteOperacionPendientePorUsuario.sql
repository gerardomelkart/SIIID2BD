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

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 53200, 'No existe dbo.semanal_carga.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
    BEGIN
        THROW 53201, 'No existe dbo.semanal_carga_bloque.', 1;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga_bloque', N'id_usuario_carga') IS NULL
    BEGIN
        ALTER TABLE dbo.semanal_carga_bloque
        ADD id_usuario_carga INT NULL;
    END;

    UPDATE bloque
    SET bloque.id_usuario_carga = carga.id_usuario_carga
    FROM dbo.semanal_carga_bloque bloque
    INNER JOIN dbo.semanal_carga carga
        ON carga.id_semanal_carga = bloque.id_semanal_carga
    WHERE bloque.id_usuario_carga IS NULL
       OR bloque.id_usuario_carga <> carga.id_usuario_carga;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga_bloque
        WHERE id_usuario_carga IS NULL
    )
    BEGIN
        THROW 53202, 'Existen bloques sin usuario propietario.', 1;
    END;

    ALTER TABLE dbo.semanal_carga_bloque
    ALTER COLUMN id_usuario_carga INT NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'FK_semanal_carga_bloque_usuario'
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga_bloque WITH CHECK
        ADD CONSTRAINT FK_semanal_carga_bloque_usuario
            FOREIGN KEY (id_usuario_carga)
            REFERENCES dbo.usuario(id_usuario);

        ALTER TABLE dbo.semanal_carga_bloque
        CHECK CONSTRAINT FK_semanal_carga_bloque_usuario;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana
        HAVING COUNT(*) > 1
    )
    BEGIN
        SELECT
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana,
            COUNT(*) AS operaciones_pendientes
        FROM dbo.semanal_carga
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana
        HAVING COUNT(*) > 1;

        THROW 53203, 'Existen operaciones pendientes duplicadas para el mismo usuario.', 1;
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
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1
    )
    BEGIN
        SELECT
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana,
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
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1;

        THROW 53204, 'Existen bloques pendientes duplicados para el mismo usuario.', 1;
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

    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_operacion_pendiente
    ON dbo.semanal_carga
    (
        id_entidad_federativa,
        id_usuario_carga,
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
        id_entidad_federativa,
        id_usuario_carga,
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

    PRINT N'Protección de operaciones preliminares separada correctamente por usuario.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    indice.name,
    tabla.name AS tabla,
    indice.is_unique,
    indice.has_filter,
    indice.filter_definition,
    STRING_AGG(columna.name, N', ') WITHIN GROUP (ORDER BY columnaIndice.key_ordinal) AS columnas
FROM sys.indexes indice
INNER JOIN sys.tables tabla
    ON tabla.object_id = indice.object_id
INNER JOIN sys.index_columns columnaIndice
    ON columnaIndice.object_id = indice.object_id
   AND columnaIndice.index_id = indice.index_id
   AND columnaIndice.key_ordinal > 0
INNER JOIN sys.columns columna
    ON columna.object_id = columnaIndice.object_id
   AND columna.column_id = columnaIndice.column_id
WHERE indice.name IN
(
    N'UX_semanal_carga_operacion_pendiente',
    N'UX_semanal_carga_bloque_pendiente'
)
GROUP BY
    indice.name,
    tabla.name,
    indice.is_unique,
    indice.has_filter,
    indice.filter_definition
ORDER BY tabla.name, indice.name;
GO