USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @EjecutarLimpieza BIT = 0;
-- 0 = simulación con ROLLBACK
-- 1 = ejecuta limpieza con COMMIT

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT 'CONTEOS ANTES';

    SELECT 'carga' AS tabla, COUNT(*) AS total
    FROM dbo.carga

    UNION ALL
    SELECT 'carga_advertencia', COUNT(*)
    FROM dbo.carga_advertencia

    UNION ALL
    SELECT 'carga_bitacora_estado', COUNT(*)
    FROM dbo.carga_bitacora_estado

    UNION ALL
    SELECT 'carga_tmp_carpeta', COUNT(*)
    FROM dbo.carga_tmp_carpeta

    UNION ALL
    SELECT 'carga_tmp_delito', COUNT(*)
    FROM dbo.carga_tmp_delito

    UNION ALL
    SELECT 'carga_tmp_victima', COUNT(*)
    FROM dbo.carga_tmp_victima

    UNION ALL
    SELECT 'carpeta_investigacion', COUNT(*)
    FROM dbo.carpeta_investigacion

    UNION ALL
    SELECT 'delito', COUNT(*)
    FROM dbo.delito

    UNION ALL
    SELECT 'victima', COUNT(*)
    FROM dbo.victima

    UNION ALL
    SELECT 'carpeta_investigacion_historico', COUNT(*)
    FROM dbo.carpeta_investigacion_historico

    UNION ALL
    SELECT 'delito_historico', COUNT(*)
    FROM dbo.delito_historico

    UNION ALL
    SELECT 'victima_historico', COUNT(*)
    FROM dbo.victima_historico;


    -- Auditoría y flujo administrativo.
    DELETE FROM dbo.carga_bitacora_estado;
    DELETE FROM dbo.carga_advertencia;

    -- Históricos.
    DELETE FROM dbo.victima_historico;
    DELETE FROM dbo.delito_historico;
    DELETE FROM dbo.carpeta_investigacion_historico;

    -- Información final.
    DELETE FROM dbo.victima;
    DELETE FROM dbo.delito;
    DELETE FROM dbo.carpeta_investigacion;

    -- Staging.
    DELETE FROM dbo.carga_tmp_victima;
    DELETE FROM dbo.carga_tmp_delito;
    DELETE FROM dbo.carga_tmp_carpeta;

    -- Cargas.
    DELETE FROM dbo.carga;


    DBCC CHECKIDENT
    (
        N'dbo.carga_bitacora_estado',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga_advertencia',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.victima_historico',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.delito_historico',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carpeta_investigacion_historico',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.victima',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.delito',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carpeta_investigacion',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga_tmp_victima',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga_tmp_delito',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga_tmp_carpeta',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga',
        RESEED,
        0
    );


    PRINT 'CONTEOS DESPUES';

    SELECT 'carga' AS tabla, COUNT(*) AS total
    FROM dbo.carga

    UNION ALL
    SELECT 'carga_advertencia', COUNT(*)
    FROM dbo.carga_advertencia

    UNION ALL
    SELECT 'carga_bitacora_estado', COUNT(*)
    FROM dbo.carga_bitacora_estado

    UNION ALL
    SELECT 'carga_tmp_carpeta', COUNT(*)
    FROM dbo.carga_tmp_carpeta

    UNION ALL
    SELECT 'carga_tmp_delito', COUNT(*)
    FROM dbo.carga_tmp_delito

    UNION ALL
    SELECT 'carga_tmp_victima', COUNT(*)
    FROM dbo.carga_tmp_victima

    UNION ALL
    SELECT 'carpeta_investigacion', COUNT(*)
    FROM dbo.carpeta_investigacion

    UNION ALL
    SELECT 'delito', COUNT(*)
    FROM dbo.delito

    UNION ALL
    SELECT 'victima', COUNT(*)
    FROM dbo.victima

    UNION ALL
    SELECT 'carpeta_investigacion_historico', COUNT(*)
    FROM dbo.carpeta_investigacion_historico

    UNION ALL
    SELECT 'delito_historico', COUNT(*)
    FROM dbo.delito_historico

    UNION ALL
    SELECT 'victima_historico', COUNT(*)
    FROM dbo.victima_historico;


    IF @EjecutarLimpieza = 1
    BEGIN
        COMMIT TRANSACTION;

        PRINT 'LIMPIEZA CONFIRMADA. LOS USUARIOS SE CONSERVARON.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;

        PRINT 'SIMULACION. NO SE BORRO NADA.';
    END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        ERROR_NUMBER() AS numero_error,
        ERROR_MESSAGE() AS mensaje_error,
        ERROR_LINE() AS linea_error;

    THROW;
END CATCH;
GO