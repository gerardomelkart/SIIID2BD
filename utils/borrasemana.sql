USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEntidadFederativa INT = 1; -- CAMBIAR
DECLARE @AnioSemana INT = 2026;       -- CAMBIAR
DECLARE @NumeroSemana INT = 27;       -- CAMBIAR

-- 0 = prueba con ROLLBACK
-- 1 = borra definitivamente con COMMIT
DECLARE @EjecutarBorrado BIT = 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('tempdb..#CargasObjetivo') IS NOT NULL DROP TABLE #CargasObjetivo;

    CREATE TABLE #CargasObjetivo
    (
        id_semanal_carga BIGINT NOT NULL PRIMARY KEY
    );

    INSERT INTO #CargasObjetivo (id_semanal_carga)
    SELECT sc.id_semanal_carga
    FROM dbo.semanal_carga sc
    WHERE sc.id_entidad_federativa = @IdEntidadFederativa
      AND sc.anio_semana = @AnioSemana
      AND sc.numero_semana = @NumeroSemana;

    PRINT N'============================================================';
    PRINT N'CARGAS SEMANALES OBJETIVO';
    PRINT N'============================================================';

    SELECT
        sc.id_semanal_carga,
        sc.codigo_referencia,
        sc.tipo_carga,
        sc.tipo_contenido,
        sc.estado,
        sc.id_entidad_federativa,
        ef.nombre AS entidad_federativa,
        sc.anio_semana,
        sc.numero_semana,
        sc.fecha_inicio_semana,
        sc.fecha_fin_semana,
        sc.fecha_inicio_tramo,
        sc.fecha_fin_tramo,
        sc.mes_corte,
        sc.anio_corte,
        sc.fecha_validacion,
        sc.fecha_confirmacion,
        sc.activo
    FROM dbo.semanal_carga sc
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = sc.id_semanal_carga
    LEFT JOIN dbo.catalogo_entidad_federativa ef ON ef.id_entidad_federativa = sc.id_entidad_federativa
    ORDER BY sc.id_semanal_carga;

    IF NOT EXISTS (SELECT 1 FROM #CargasObjetivo)
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT N'No se encontraron cargas para esa entidad, año y semana.';
        RETURN;
    END;

    PRINT N'============================================================';
    PRINT N'CONTEO ANTES DE BORRAR';
    PRINT N'============================================================';

    SELECT N'semanal_carga' AS tabla, COUNT_BIG(*) AS total
    FROM dbo.semanal_carga t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carga_delito_configurado', COUNT_BIG(*)
    FROM dbo.semanal_carga_delito_configurado t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carga_tmp_carpeta', COUNT_BIG(*)
    FROM dbo.semanal_carga_tmp_carpeta t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carga_tmp_delito', COUNT_BIG(*)
    FROM dbo.semanal_carga_tmp_delito t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carga_tmp_victima', COUNT_BIG(*)
    FROM dbo.semanal_carga_tmp_victima t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carpeta_investigacion', COUNT_BIG(*)
    FROM dbo.semanal_carpeta_investigacion t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_delito', COUNT_BIG(*)
    FROM dbo.semanal_delito t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_victima', COUNT_BIG(*)
    FROM dbo.semanal_victima t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carpeta_investigacion_historico', COUNT_BIG(*)
    FROM dbo.semanal_carpeta_investigacion_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    )

    UNION ALL
    SELECT N'semanal_delito_historico', COUNT_BIG(*)
    FROM dbo.semanal_delito_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    )

    UNION ALL
    SELECT N'semanal_victima_historico', COUNT_BIG(*)
    FROM dbo.semanal_victima_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    );

    PRINT N'============================================================';
    PRINT N'BORRANDO TEMPORALES';
    PRINT N'============================================================';

    DELETE t
    FROM dbo.semanal_carga_tmp_victima t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga;

    PRINT CONCAT(N'semanal_carga_tmp_victima borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.semanal_carga_tmp_delito t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga;

    PRINT CONCAT(N'semanal_carga_tmp_delito borrados: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.semanal_carga_tmp_carpeta t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga;

    PRINT CONCAT(N'semanal_carga_tmp_carpeta borradas: ', @@ROWCOUNT);

    PRINT N'============================================================';
    PRINT N'BORRANDO HISTÓRICOS';
    PRINT N'============================================================';

    DELETE t
    FROM dbo.semanal_victima_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    );

    PRINT CONCAT(N'semanal_victima_historico borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.semanal_delito_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    );

    PRINT CONCAT(N'semanal_delito_historico borrados: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.semanal_carpeta_investigacion_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    );

    PRINT CONCAT(N'semanal_carpeta_investigacion_historico borradas: ', @@ROWCOUNT);

    PRINT N'============================================================';
    PRINT N'BORRANDO TABLAS FINALES';
    PRINT N'============================================================';

    DELETE t
    FROM dbo.semanal_victima t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga;

    PRINT CONCAT(N'semanal_victima borradas: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.semanal_delito t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga;

    PRINT CONCAT(N'semanal_delito borrados: ', @@ROWCOUNT);

    DELETE t
    FROM dbo.semanal_carpeta_investigacion t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga;

    PRINT CONCAT(N'semanal_carpeta_investigacion borradas: ', @@ROWCOUNT);

    PRINT N'============================================================';
    PRINT N'BORRANDO CONFIGURACIÓN DE LAS CARGAS';
    PRINT N'============================================================';

    DELETE t
    FROM dbo.semanal_carga_delito_configurado t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga;

    PRINT CONCAT(N'semanal_carga_delito_configurado borradas: ', @@ROWCOUNT);

    PRINT N'============================================================';
    PRINT N'BORRANDO ENCABEZADOS DE CARGA';
    PRINT N'============================================================';

    DELETE t
    FROM dbo.semanal_carga t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga;

    PRINT CONCAT(N'semanal_carga borradas: ', @@ROWCOUNT);

    PRINT N'============================================================';
    PRINT N'VALIDACIÓN DESPUÉS DE BORRAR';
    PRINT N'============================================================';

    SELECT N'semanal_carga' AS tabla, COUNT_BIG(*) AS total
    FROM dbo.semanal_carga t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carga_delito_configurado', COUNT_BIG(*)
    FROM dbo.semanal_carga_delito_configurado t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carga_tmp_carpeta', COUNT_BIG(*)
    FROM dbo.semanal_carga_tmp_carpeta t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carga_tmp_delito', COUNT_BIG(*)
    FROM dbo.semanal_carga_tmp_delito t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carga_tmp_victima', COUNT_BIG(*)
    FROM dbo.semanal_carga_tmp_victima t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carpeta_investigacion', COUNT_BIG(*)
    FROM dbo.semanal_carpeta_investigacion t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_delito', COUNT_BIG(*)
    FROM dbo.semanal_delito t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_victima', COUNT_BIG(*)
    FROM dbo.semanal_victima t
    INNER JOIN #CargasObjetivo objetivo ON objetivo.id_semanal_carga = t.id_semanal_carga

    UNION ALL
    SELECT N'semanal_carpeta_investigacion_historico', COUNT_BIG(*)
    FROM dbo.semanal_carpeta_investigacion_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    )

    UNION ALL
    SELECT N'semanal_delito_historico', COUNT_BIG(*)
    FROM dbo.semanal_delito_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    )

    UNION ALL
    SELECT N'semanal_victima_historico', COUNT_BIG(*)
    FROM dbo.semanal_victima_historico t
    WHERE EXISTS
    (
        SELECT 1
        FROM #CargasObjetivo objetivo
        WHERE objetivo.id_semanal_carga = t.id_semanal_carga
           OR objetivo.id_semanal_carga = t.id_semanal_carga_nueva
    );

    IF @EjecutarBorrado = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT N'BORRADO SEMANAL APLICADO CON COMMIT.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT N'PRUEBA TERMINADA CON ROLLBACK. No se borró nada.';
    END;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

    SELECT ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message, ERROR_LINE() AS error_line;
END CATCH;
GO