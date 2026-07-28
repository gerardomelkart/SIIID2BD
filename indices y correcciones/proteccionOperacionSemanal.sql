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
BEGIN
    THROW 50070, 'No existe dbo.semanal_carga.', 1;
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
    GROUP BY id_entidad_federativa, anio_semana, numero_semana
    HAVING COUNT(*) > 1
)
BEGIN
    SELECT id_entidad_federativa, anio_semana, numero_semana, COUNT(*) AS operaciones_pendientes
    FROM dbo.semanal_carga
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      )
    GROUP BY id_entidad_federativa, anio_semana, numero_semana
    HAVING COUNT(*) > 1;

    THROW 50071, 'Existen operaciones pendientes duplicadas. Deben resolverse antes de crear el índice.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
      AND name = N'UX_semanal_carga_operacion_pendiente'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_operacion_pendiente
    ON dbo.semanal_carga
    (
        id_entidad_federativa,
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
END;

SELECT name, is_unique, has_filter, is_disabled, filter_definition
FROM sys.indexes
WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
  AND name = N'UX_semanal_carga_operacion_pendiente';
GO