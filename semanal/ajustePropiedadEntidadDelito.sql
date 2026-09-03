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

IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
    THROW 53400, 'No existe dbo.semanal_carga_bloque.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

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
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1
    )
    BEGIN
        SELECT
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte,
            COUNT(*) AS bloques_pendientes,
            COUNT(DISTINCT id_usuario_carga) AS usuarios_distintos
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
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1;

        THROW 53401, 'Existen bloques pendientes duplicados para la misma entidad, delito y periodo.', 1;
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

    PRINT N'Propiedad semanal corregida: entidad + delito + periodo, independientemente del usuario.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    indice.name,
    indice.is_unique,
    indice.filter_definition,
    STRING_AGG(columna.name, N', ') WITHIN GROUP (ORDER BY indice_columna.key_ordinal) AS columnas
FROM sys.indexes indice
INNER JOIN sys.index_columns indice_columna
    ON indice_columna.object_id = indice.object_id
   AND indice_columna.index_id = indice.index_id
   AND indice_columna.key_ordinal > 0
INNER JOIN sys.columns columna
    ON columna.object_id = indice_columna.object_id
   AND columna.column_id = indice_columna.column_id
WHERE indice.object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
  AND indice.name = N'UX_semanal_carga_bloque_pendiente'
GROUP BY
    indice.name,
    indice.is_unique,
    indice.filter_definition;
GO