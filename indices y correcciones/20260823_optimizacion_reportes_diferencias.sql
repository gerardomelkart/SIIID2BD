USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    Script idempotente y no destructivo.

    Afecta únicamente índices de:
    - dbo.semanal_carga
    - dbo.semanal_carga_bloque

    No inserta, actualiza ni elimina datos.
*/

IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
         AND name = N'IX_semanal_carga_reporte_cargas'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_semanal_carga_reporte_cargas
    ON dbo.semanal_carga
    (
        id_entidad_federativa,
        id_usuario_carga,
        id_delito,
        anio_corte,
        mes_corte,
        fecha_inicio_semana,
        fecha_fin_semana,
        id_semanal_carga
    )
    INCLUDE
    (
        codigo_referencia,
        tipo_carga,
        estado,
        fecha_carga,
        fecha_validacion,
        fecha_confirmacion
    )
    WHERE activo = 1
      AND id_entidad_federativa IS NOT NULL
      AND id_delito IS NOT NULL;
END;
GO

IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
         AND name = N'IX_semanal_carga_bloque_carga_activo_reporte'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_semanal_carga_bloque_carga_activo_reporte
    ON dbo.semanal_carga_bloque
    (
        id_semanal_carga,
        activo
    )
    INCLUDE
    (
        id_entidad_federativa,
        fecha_inicio_semana,
        fecha_fin_semana,
        fecha_inicio_tramo,
        fecha_fin_tramo,
        anio_corte,
        mes_corte,
        reemplaza_informacion
    );
END;
GO

PRINT N'Índices para reporte de cargas y diferencias preliminares verificados correctamente.';
GO
