USE siiid2;
GO

CREATE OR ALTER PROCEDURE dbo.usp_mantenimiento_semanal
    @EjecutarMantenimiento BIT = 0,
    @ActualizarEstadisticas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MantenimientoConfirmado BIT = 0;
    DECLARE @IdDelitoExtorsion INT;
    DECLARE @TmpVictimasEliminadas INT = 0;
    DECLARE @TmpDelitosEliminados INT = 0;
    DECLARE @TmpCarpetasEliminadas INT = 0;
    DECLARE @VictimasHistoricoEliminadas INT = 0;
    DECLARE @VictimasEliminadas INT = 0;
    DECLARE @DelitosHistoricoEliminados INT = 0;
    DECLARE @DelitosEliminados INT = 0;
    DECLARE @CarpetasHistoricoEliminadas INT = 0;
    DECLARE @CarpetasEliminadas INT = 0;
    DECLARE @ConfiguracionesEliminadas INT = 0;
    DECLARE @CargasEliminadas INT = 0;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga_delito_configurado', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga_tmp_carpeta', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga_tmp_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga_tmp_victima', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carpeta_investigacion', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carpeta_investigacion_historico', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_delito_historico', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_victima', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_victima_historico', N'U') IS NULL
    BEGIN
        THROW 50020, 'No está completa la estructura requerida por el mantenimiento semanal.', 1;
    END;

    IF (SELECT COUNT(*) FROM dbo.catalogo_delito WHERE clave2 = N'4.04') <> 1
    BEGIN
        THROW 50021, 'No se encontró una única definición del delito Extorsión con clave 4.04.', 1;
    END;

    SET @IdDelitoExtorsion = (SELECT id_delito FROM dbo.catalogo_delito WHERE clave2 = N'4.04');

    CREATE TABLE #CargasSemanalObjetivo
    (
        id_semanal_carga BIGINT NOT NULL PRIMARY KEY
    );

    CREATE TABLE #DelitosEliminar
    (
        id_semanal_delito BIGINT NOT NULL PRIMARY KEY
    );

    CREATE TABLE #VictimasEliminar
    (
        id_semanal_victima BIGINT NOT NULL PRIMARY KEY
    );

    CREATE TABLE #CarpetasEvaluar
    (
        id_semanal_carpeta_investigacion BIGINT NOT NULL PRIMARY KEY
    );

    CREATE TABLE #CarpetasEliminar
    (
        id_semanal_carpeta_investigacion BIGINT NOT NULL PRIMARY KEY
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO #CargasSemanalObjetivo (id_semanal_carga)
        SELECT sc.id_semanal_carga
        FROM dbo.semanal_carga sc
        WHERE NOT
        (
            sc.activo = 1
            AND sc.estado IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
        )
          AND EXISTS
          (
              SELECT 1
              FROM dbo.carga cm
              WHERE ISNULL(cm.id_entidad_federativa, 0) = ISNULL(sc.id_entidad_federativa, 0)
                AND cm.mes_corte = sc.mes_corte
                AND cm.anio_corte = sc.anio_corte
                AND cm.estado IN (N'CONFIRMADO', N'CONFIRMADO_ACTUALIZACION')
                AND cm.activo = 1
          );

        PRINT 'CARGAS SEMANALES ELEGIBLES PARA MANTENIMIENTO';

        SELECT sc.id_semanal_carga, sc.codigo_referencia, sc.id_entidad_federativa, sc.anio_corte, sc.mes_corte, sc.numero_semana, sc.tipo_carga, sc.tipo_contenido, sc.estado, sc.fecha_confirmacion, sc.activo
        FROM dbo.semanal_carga sc
        INNER JOIN #CargasSemanalObjetivo objetivo ON objetivo.id_semanal_carga = sc.id_semanal_carga
        ORDER BY sc.anio_corte, sc.mes_corte, sc.id_entidad_federativa, sc.numero_semana, sc.id_semanal_carga;

        IF NOT EXISTS (SELECT 1 FROM #CargasSemanalObjetivo)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'No existen cargas semanales elegibles. No se modificó información.';
            RETURN;
        END;

        INSERT INTO #DelitosEliminar (id_semanal_delito)
        SELECT d.id_semanal_delito
        FROM dbo.semanal_delito d
        INNER JOIN #CargasSemanalObjetivo objetivo ON objetivo.id_semanal_carga = d.id_semanal_carga
        WHERE d.id_catalogo_delito <> @IdDelitoExtorsion;

        INSERT INTO #VictimasEliminar (id_semanal_victima)
        SELECT v.id_semanal_victima
        FROM dbo.semanal_victima v
        INNER JOIN #DelitosEliminar delito ON delito.id_semanal_delito = v.id_semanal_delito;

        INSERT INTO #CarpetasEvaluar (id_semanal_carpeta_investigacion)
        SELECT DISTINCT ci.id_semanal_carpeta_investigacion
        FROM dbo.semanal_carpeta_investigacion ci
        WHERE EXISTS
        (
            SELECT 1
            FROM #CargasSemanalObjetivo objetivo
            WHERE objetivo.id_semanal_carga = ci.id_semanal_carga
        )
           OR EXISTS
        (
            SELECT 1
            FROM dbo.semanal_delito d
            INNER JOIN #DelitosEliminar delito ON delito.id_semanal_delito = d.id_semanal_delito
            WHERE d.id_semanal_carpeta_investigacion = ci.id_semanal_carpeta_investigacion
        );

        INSERT INTO #CarpetasEliminar (id_semanal_carpeta_investigacion)
        SELECT evaluar.id_semanal_carpeta_investigacion
        FROM #CarpetasEvaluar evaluar
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.semanal_delito d
            WHERE d.id_semanal_carpeta_investigacion = evaluar.id_semanal_carpeta_investigacion
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM #DelitosEliminar delito
                  WHERE delito.id_semanal_delito = d.id_semanal_delito
              )
        );

        PRINT 'RESUMEN PREVIO';

        SELECT
            (SELECT COUNT(*) FROM #CargasSemanalObjetivo) AS cargas_elegibles,
            (SELECT COUNT(*) FROM #CarpetasEliminar) AS carpetas_por_eliminar,
            (SELECT COUNT(*) FROM #DelitosEliminar) AS delitos_por_eliminar,
            (SELECT COUNT(*) FROM #VictimasEliminar) AS victimas_por_eliminar,
            (
                SELECT COUNT(*)
                FROM dbo.semanal_delito d
                INNER JOIN #CargasSemanalObjetivo objetivo ON objetivo.id_semanal_carga = d.id_semanal_carga
                WHERE d.id_catalogo_delito = @IdDelitoExtorsion
            ) AS delitos_extorsion_conservados;

        DELETE historico
        FROM dbo.semanal_victima_historico historico
        WHERE EXISTS
        (
            SELECT 1
            FROM #VictimasEliminar victima
            WHERE victima.id_semanal_victima = historico.id_semanal_victima
        )
           OR EXISTS
        (
            SELECT 1
            FROM #DelitosEliminar delito
            WHERE delito.id_semanal_delito = historico.id_semanal_delito
        );

        SET @VictimasHistoricoEliminadas = @@ROWCOUNT;

        DELETE victima
        FROM dbo.semanal_victima victima
        INNER JOIN #VictimasEliminar objetivo ON objetivo.id_semanal_victima = victima.id_semanal_victima;

        SET @VictimasEliminadas = @@ROWCOUNT;

        DELETE historico
        FROM dbo.semanal_delito_historico historico
        WHERE EXISTS
        (
            SELECT 1
            FROM #DelitosEliminar delito
            WHERE delito.id_semanal_delito = historico.id_semanal_delito
        )
           OR EXISTS
        (
            SELECT 1
            FROM #CarpetasEliminar carpeta
            WHERE carpeta.id_semanal_carpeta_investigacion = historico.id_semanal_carpeta_investigacion
        );

        SET @DelitosHistoricoEliminados = @@ROWCOUNT;

        DELETE delito
        FROM dbo.semanal_delito delito
        INNER JOIN #DelitosEliminar objetivo ON objetivo.id_semanal_delito = delito.id_semanal_delito;

        SET @DelitosEliminados = @@ROWCOUNT;

        DELETE historico
        FROM dbo.semanal_carpeta_investigacion_historico historico
        INNER JOIN #CarpetasEliminar objetivo ON objetivo.id_semanal_carpeta_investigacion = historico.id_semanal_carpeta_investigacion;

        SET @CarpetasHistoricoEliminadas = @@ROWCOUNT;

        DELETE carpeta
        FROM dbo.semanal_carpeta_investigacion carpeta
        INNER JOIN #CarpetasEliminar objetivo ON objetivo.id_semanal_carpeta_investigacion = carpeta.id_semanal_carpeta_investigacion;

        SET @CarpetasEliminadas = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.semanal_carga_tmp_victima tmp
        INNER JOIN #CargasSemanalObjetivo objetivo ON objetivo.id_semanal_carga = tmp.id_semanal_carga;

        SET @TmpVictimasEliminadas = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.semanal_carga_tmp_delito tmp
        INNER JOIN #CargasSemanalObjetivo objetivo ON objetivo.id_semanal_carga = tmp.id_semanal_carga;

        SET @TmpDelitosEliminados = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.semanal_carga_tmp_carpeta tmp
        INNER JOIN #CargasSemanalObjetivo objetivo ON objetivo.id_semanal_carga = tmp.id_semanal_carga;

        SET @TmpCarpetasEliminadas = @@ROWCOUNT;

        DELETE configuracion
        FROM dbo.semanal_carga_delito_configurado configuracion
        INNER JOIN #CargasSemanalObjetivo objetivo ON objetivo.id_semanal_carga = configuracion.id_semanal_carga
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.semanal_delito d
            WHERE d.id_semanal_carga = configuracion.id_semanal_carga
              AND d.id_catalogo_delito = configuracion.id_delito
        )
          AND NOT EXISTS
        (
            SELECT 1
            FROM dbo.semanal_delito_historico historico
            WHERE historico.id_semanal_carga = configuracion.id_semanal_carga
              AND historico.id_catalogo_delito = configuracion.id_delito
        );

        SET @ConfiguracionesEliminadas = @@ROWCOUNT;

        DELETE carga
        FROM dbo.semanal_carga carga
        INNER JOIN #CargasSemanalObjetivo objetivo ON objetivo.id_semanal_carga = carga.id_semanal_carga
        WHERE NOT EXISTS (SELECT 1 FROM dbo.semanal_carga_delito_configurado t WHERE t.id_semanal_carga = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_carga_tmp_carpeta t WHERE t.id_semanal_carga = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_carga_tmp_delito t WHERE t.id_semanal_carga = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_carga_tmp_victima t WHERE t.id_semanal_carga = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_carpeta_investigacion t WHERE t.id_semanal_carga = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_delito t WHERE t.id_semanal_carga = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_victima t WHERE t.id_semanal_carga = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_carpeta_investigacion_historico t WHERE t.id_semanal_carga = carga.id_semanal_carga OR t.id_semanal_carga_nueva = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_delito_historico t WHERE t.id_semanal_carga = carga.id_semanal_carga OR t.id_semanal_carga_nueva = carga.id_semanal_carga)
          AND NOT EXISTS (SELECT 1 FROM dbo.semanal_victima_historico t WHERE t.id_semanal_carga = carga.id_semanal_carga OR t.id_semanal_carga_nueva = carga.id_semanal_carga);

        SET @CargasEliminadas = @@ROWCOUNT;

        SELECT N'semanal_carga_tmp_victima' AS tabla, @TmpVictimasEliminadas AS registros_afectados
        UNION ALL SELECT N'semanal_carga_tmp_delito', @TmpDelitosEliminados
        UNION ALL SELECT N'semanal_carga_tmp_carpeta', @TmpCarpetasEliminadas
        UNION ALL SELECT N'semanal_victima_historico', @VictimasHistoricoEliminadas
        UNION ALL SELECT N'semanal_victima', @VictimasEliminadas
        UNION ALL SELECT N'semanal_delito_historico', @DelitosHistoricoEliminados
        UNION ALL SELECT N'semanal_delito', @DelitosEliminados
        UNION ALL SELECT N'semanal_carpeta_investigacion_historico', @CarpetasHistoricoEliminadas
        UNION ALL SELECT N'semanal_carpeta_investigacion', @CarpetasEliminadas
        UNION ALL SELECT N'semanal_carga_delito_configurado', @ConfiguracionesEliminadas
        UNION ALL SELECT N'semanal_carga', @CargasEliminadas;

        IF @EjecutarMantenimiento = 1
        BEGIN
            COMMIT TRANSACTION;
            SET @MantenimientoConfirmado = 1;
            PRINT 'MANTENIMIENTO SEMANAL CONFIRMADO. Los datos no requeridos fueron eliminados.';
        END
        ELSE
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'SIMULACIÓN SEMANAL TERMINADA. No se eliminó información.';
        END;

        IF @MantenimientoConfirmado = 1 AND @ActualizarEstadisticas = 1
        BEGIN
            UPDATE STATISTICS dbo.semanal_carga WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_carga_delito_configurado WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_carga_tmp_carpeta WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_carga_tmp_delito WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_carga_tmp_victima WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_carpeta_investigacion WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_carpeta_investigacion_historico WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_delito WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_delito_historico WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_victima WITH FULLSCAN;
            UPDATE STATISTICS dbo.semanal_victima_historico WITH FULLSCAN;
            PRINT 'Estadísticas semanales actualizadas correctamente.';
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        IF @MantenimientoConfirmado = 1
        BEGIN
            PRINT 'El borrado semanal ya había sido confirmado; el error ocurrió después del COMMIT.';
        END;

        THROW;
    END CATCH;
END;
GO

/*
    Ejecución manual en simulación:

    EXEC dbo.usp_mantenimiento_semanal
        @EjecutarMantenimiento = 0,
        @ActualizarEstadisticas = 0;

    Ejecución que utilizará el job:

    EXEC dbo.usp_mantenimiento_semanal
        @EjecutarMantenimiento = 1,
        @ActualizarEstadisticas = 1;
*/