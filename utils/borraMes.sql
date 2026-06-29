USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEntidadFederativa INT = 1;  -- CAMBIAR
DECLARE @MesCorte INT = 5;             -- CAMBIAR
DECLARE @AnioCorte INT = 2026;         -- CAMBIAR

-- 0 = prueba con ROLLBACK
-- 1 = borra definitivamente con COMMIT
DECLARE @EjecutarBorrado BIT = 0;

BEGIN TRY
    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#CargasObjetivo') IS NOT NULL
        DROP TABLE #CargasObjetivo;

    CREATE TABLE #CargasObjetivo (
        id_carga BIGINT NOT NULL PRIMARY KEY
    );

    INSERT INTO #CargasObjetivo (id_carga)
    SELECT c.id_carga
    FROM dbo.carga c
    WHERE c.id_entidad_federativa = @IdEntidadFederativa
      AND c.mes_corte = @MesCorte
      AND c.anio_corte = @AnioCorte;

    PRINT '============================================================';
    PRINT 'CARGAS OBJETIVO';
    PRINT '============================================================';

    SELECT
        c.id_carga,
        c.codigo_referencia,
        c.tipo_carga,
        c.estado,
        c.id_entidad_federativa,
        ef.nombre AS entidad_federativa,
        c.mes_corte,
        c.anio_corte,
        c.fecha_validacion,
        c.fecha_confirmacion,
        c.activo
    FROM dbo.carga c
    LEFT JOIN dbo.catalogo_entidad_federativa ef
        ON ef.id_entidad_federativa = c.id_entidad_federativa
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = c.id_carga
    ORDER BY
        c.id_carga;

    IF NOT EXISTS (SELECT 1 FROM #CargasObjetivo)
    BEGIN
        PRINT 'No se encontraron cargas para esa entidad/mes/año.';
        ROLLBACK TRAN;
        RETURN;
    END;

    PRINT '============================================================';
    PRINT 'CONTEO ANTES DE BORRAR';
    PRINT '============================================================';

    SELECT 'carga' AS tabla, COUNT(*) AS total
    FROM dbo.carga c
    INNER JOIN #CargasObjetivo co ON co.id_carga = c.id_carga

    UNION ALL
    SELECT 'carga_bitacora_estado', COUNT(*)
    FROM dbo.carga_bitacora_estado t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carga_tmp_carpeta', COUNT(*)
    FROM dbo.carga_tmp_carpeta t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carga_tmp_delito', COUNT(*)
    FROM dbo.carga_tmp_delito t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carga_tmp_victima', COUNT(*)
    FROM dbo.carga_tmp_victima t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carga_advertencia', COUNT(*)
    FROM dbo.carga_advertencia t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'victima', COUNT(*)
    FROM dbo.victima t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'delito', COUNT(*)
    FROM dbo.delito t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carpeta_investigacion', COUNT(*)
    FROM dbo.carpeta_investigacion t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'victima_historico', COUNT(*)
    FROM dbo.victima_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva

    UNION ALL
    SELECT 'delito_historico', COUNT(*)
    FROM dbo.delito_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva

    UNION ALL
    SELECT 'carpeta_investigacion_historico', COUNT(*)
    FROM dbo.carpeta_investigacion_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva;

    PRINT '============================================================';
    PRINT 'BORRANDO HIJOS / TEMPORALES';
    PRINT '============================================================';

    DELETE t
    FROM dbo.carga_tmp_victima t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga;

    PRINT CONCAT('carga_tmp_victima borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.carga_tmp_delito t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga;

    PRINT CONCAT('carga_tmp_delito borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.carga_tmp_carpeta t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga;

    PRINT CONCAT('carga_tmp_carpeta borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.carga_advertencia t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga;

    PRINT CONCAT('carga_advertencia borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.carga_bitacora_estado t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga;

    PRINT CONCAT('carga_bitacora_estado borradas: ', @@ROWCOUNT);

    -- Auditoría de estados, si existe.
    IF OBJECT_ID('dbo.carga_estado_auditoria', 'U') IS NOT NULL
    BEGIN
        DELETE t
        FROM dbo.carga_estado_auditoria t
        INNER JOIN #CargasObjetivo co
            ON co.id_carga = t.id_carga;

        PRINT CONCAT('carga_estado_auditoria borradas: ', @@ROWCOUNT);
    END;

        PRINT '============================================================';
    PRINT 'BORRANDO HISTORICOS';
    PRINT '============================================================';

    DELETE t
    FROM dbo.victima_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva;

    PRINT CONCAT('victima_historico borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.delito_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva;

    PRINT CONCAT('delito_historico borrados: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.carpeta_investigacion_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva;

    PRINT CONCAT('carpeta_investigacion_historico borradas: ', @@ROWCOUNT);

    PRINT '============================================================';
    PRINT 'BORRANDO TABLAS FINALES';
    PRINT '============================================================';

    DELETE t
    FROM dbo.victima t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga;

    PRINT CONCAT('victima borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.delito t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga;

    PRINT CONCAT('delito borrados: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.carpeta_investigacion t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga;

    PRINT CONCAT('carpeta_investigacion borradas: ', @@ROWCOUNT);

    PRINT '============================================================';
    PRINT 'BORRANDO CARGAS';
    PRINT '============================================================';

    DELETE c
    FROM dbo.carga c
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = c.id_carga;

    PRINT CONCAT('carga borradas: ', @@ROWCOUNT);

    PRINT '============================================================';
    PRINT 'VALIDACION DESPUES DE BORRAR';
    PRINT '============================================================';

    SELECT 'carga' AS tabla, COUNT(*) AS total
    FROM dbo.carga c
    INNER JOIN #CargasObjetivo co ON co.id_carga = c.id_carga

    UNION ALL
    SELECT 'carga_bitacora_estado', COUNT(*)
    FROM dbo.carga_bitacora_estado t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carga_tmp_carpeta', COUNT(*)
    FROM dbo.carga_tmp_carpeta t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carga_tmp_delito', COUNT(*)
    FROM dbo.carga_tmp_delito t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carga_tmp_victima', COUNT(*)
    FROM dbo.carga_tmp_victima t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carga_advertencia', COUNT(*)
    FROM dbo.carga_advertencia t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'victima', COUNT(*)
    FROM dbo.victima t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'delito', COUNT(*)
    FROM dbo.delito t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'carpeta_investigacion', COUNT(*)
    FROM dbo.carpeta_investigacion t
    INNER JOIN #CargasObjetivo co ON co.id_carga = t.id_carga

    UNION ALL
    SELECT 'victima_historico', COUNT(*)
    FROM dbo.victima_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva

    UNION ALL
    SELECT 'delito_historico', COUNT(*)
    FROM dbo.delito_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva

    UNION ALL
    SELECT 'carpeta_investigacion_historico', COUNT(*)
    FROM dbo.carpeta_investigacion_historico t
    INNER JOIN #CargasObjetivo co
        ON co.id_carga = t.id_carga
        OR co.id_carga = t.id_carga_nueva;

    IF @EjecutarBorrado = 1
    BEGIN
        COMMIT TRAN;
        PRINT 'BORRADO APLICADO CON COMMIT.';
    END
    ELSE
    BEGIN
        ROLLBACK TRAN;
        PRINT 'PRUEBA TERMINADA CON ROLLBACK. No se borró nada.';
    END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    SELECT
        ERROR_NUMBER() AS error_number,
        ERROR_MESSAGE() AS error_message,
        ERROR_LINE() AS error_line;
END CATCH;
GO