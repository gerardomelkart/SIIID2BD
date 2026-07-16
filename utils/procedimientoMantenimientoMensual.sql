USE siiid2;
GO

CREATE OR ALTER PROCEDURE dbo.usp_mantenimiento_mensual
    @EjecutarMantenimiento BIT = 0,
    @ActualizarEstadisticas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @MantenimientoConfirmado BIT = 0;
    DECLARE @VictimasEliminadas INT = 0;
    DECLARE @DelitosEliminados INT = 0;
    DECLARE @CarpetasEliminadas INT = 0;

    IF OBJECT_ID(N'dbo.carga', N'U') IS NULL
       OR OBJECT_ID(N'dbo.carga_tmp_carpeta', N'U') IS NULL
       OR OBJECT_ID(N'dbo.carga_tmp_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.carga_tmp_victima', N'U') IS NULL
       OR OBJECT_ID(N'dbo.carpeta_investigacion', N'U') IS NULL
       OR OBJECT_ID(N'dbo.carpeta_investigacion_historico', N'U') IS NULL
       OR OBJECT_ID(N'dbo.delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.delito_historico', N'U') IS NULL
       OR OBJECT_ID(N'dbo.victima', N'U') IS NULL
       OR OBJECT_ID(N'dbo.victima_historico', N'U') IS NULL
    BEGIN
        THROW 50030, 'No está completa la estructura requerida por el mantenimiento mensual.', 1;
    END;

    CREATE TABLE #CargasStagingProtegidas
    (
        id_carga BIGINT NOT NULL PRIMARY KEY,
        motivo_proteccion NVARCHAR(100) NOT NULL
    );

    INSERT INTO #CargasStagingProtegidas (id_carga, motivo_proteccion)
    SELECT c.id_carga, N'CARGA_PENDIENTE'
    FROM dbo.carga c
    WHERE c.estado IN (N'VALIDADO_PENDIENTE', N'VALIDADO_PENDIENTE_ACTUALIZACION', N'PENDIENTE_APROBACION');

    INSERT INTO #CargasStagingProtegidas (id_carga, motivo_proteccion)
    SELECT c.id_carga, N'ULTIMO_RECHAZO_ADMIN_VIGENTE'
    FROM dbo.carga c
    WHERE c.estado = N'RECHAZADO_ADMIN'
      AND c.activo = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.carga c2
          WHERE ISNULL(c2.id_entidad_federativa, 0) = ISNULL(c.id_entidad_federativa, 0)
            AND c2.mes_corte = c.mes_corte
            AND c2.anio_corte = c.anio_corte
            AND ISNULL(c2.tipo_carga, N'') = ISNULL(c.tipo_carga, N'')
            AND c2.activo = 1
            AND c2.id_carga > c.id_carga
            AND c2.estado IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION',
                N'RECHAZADO_ADMIN',
                N'CONFIRMADO',
                N'CONFIRMADO_ACTUALIZACION'
            )
      );

    PRINT 'ESTADO DE RECHAZOS ADMINISTRATIVOS';

    SELECT
        c.id_carga,
        c.codigo_referencia,
        c.id_entidad_federativa,
        c.mes_corte,
        c.anio_corte,
        c.tipo_carga,
        c.estado,
        c.fecha_validacion,
        c.fecha_confirmacion AS fecha_rechazo,
        CASE WHEN protegida.id_carga IS NOT NULL THEN N'PROTEGIDO' ELSE N'ELIMINABLE' END AS estado_staging,
        protegida.motivo_proteccion
    FROM dbo.carga c
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = c.id_carga
    WHERE c.estado = N'RECHAZADO_ADMIN'
    ORDER BY c.id_entidad_federativa, c.anio_corte, c.mes_corte, c.tipo_carga, c.id_carga;

    PRINT 'CONTEOS ANTES DEL MANTENIMIENTO';

    SELECT N'carga_tmp_carpeta' AS tabla, COUNT(*) AS total, COUNT(protegida.id_carga) AS protegidos, COUNT(*) - COUNT(protegida.id_carga) AS eliminables
    FROM dbo.carga_tmp_carpeta tmp
    INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga
    UNION ALL
    SELECT N'carga_tmp_delito', COUNT(*), COUNT(protegida.id_carga), COUNT(*) - COUNT(protegida.id_carga)
    FROM dbo.carga_tmp_delito tmp
    INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga
    UNION ALL
    SELECT N'carga_tmp_victima', COUNT(*), COUNT(protegida.id_carga), COUNT(*) - COUNT(protegida.id_carga)
    FROM dbo.carga_tmp_victima tmp
    INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE tmp
        FROM dbo.carga_tmp_victima tmp
        INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga
        WHERE protegida.id_carga IS NULL;

        SET @VictimasEliminadas = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.carga_tmp_delito tmp
        INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga
        WHERE protegida.id_carga IS NULL;

        SET @DelitosEliminados = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.carga_tmp_carpeta tmp
        INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga
        WHERE protegida.id_carga IS NULL;

        SET @CarpetasEliminadas = @@ROWCOUNT;

        SELECT N'carga_tmp_carpeta' AS tabla, @CarpetasEliminadas AS registros_afectados
        UNION ALL SELECT N'carga_tmp_delito', @DelitosEliminados
        UNION ALL SELECT N'carga_tmp_victima', @VictimasEliminadas;

        IF @EjecutarMantenimiento = 1
        BEGIN
            COMMIT TRANSACTION;
            SET @MantenimientoConfirmado = 1;
            PRINT 'MANTENIMIENTO MENSUAL CONFIRMADO. Limpieza de staging aplicada correctamente.';
        END
        ELSE
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'SIMULACIÓN MENSUAL TERMINADA. No se eliminó información.';
        END;

        PRINT 'CONTEOS DESPUÉS DEL MANTENIMIENTO';

        SELECT N'carga_tmp_carpeta' AS tabla, COUNT(*) AS total, COUNT(protegida.id_carga) AS protegidos, COUNT(*) - COUNT(protegida.id_carga) AS eliminables
        FROM dbo.carga_tmp_carpeta tmp
        INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga
        UNION ALL
        SELECT N'carga_tmp_delito', COUNT(*), COUNT(protegida.id_carga), COUNT(*) - COUNT(protegida.id_carga)
        FROM dbo.carga_tmp_delito tmp
        INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga
        UNION ALL
        SELECT N'carga_tmp_victima', COUNT(*), COUNT(protegida.id_carga), COUNT(*) - COUNT(protegida.id_carga)
        FROM dbo.carga_tmp_victima tmp
        INNER JOIN dbo.carga c ON c.id_carga = tmp.id_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_carga = tmp.id_carga;

        IF @MantenimientoConfirmado = 1 AND @ActualizarEstadisticas = 1
        BEGIN
            UPDATE STATISTICS dbo.carga_tmp_carpeta WITH FULLSCAN;
            UPDATE STATISTICS dbo.carga_tmp_delito WITH FULLSCAN;
            UPDATE STATISTICS dbo.carga_tmp_victima WITH FULLSCAN;
            UPDATE STATISTICS dbo.carga WITH FULLSCAN;
            UPDATE STATISTICS dbo.carpeta_investigacion WITH FULLSCAN;
            UPDATE STATISTICS dbo.delito WITH FULLSCAN;
            UPDATE STATISTICS dbo.victima WITH FULLSCAN;
            UPDATE STATISTICS dbo.carpeta_investigacion_historico WITH FULLSCAN;
            UPDATE STATISTICS dbo.delito_historico WITH FULLSCAN;
            UPDATE STATISTICS dbo.victima_historico WITH FULLSCAN;
            PRINT 'Estadísticas mensuales actualizadas correctamente.';
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        IF @MantenimientoConfirmado = 1
        BEGIN
            PRINT 'La limpieza mensual ya había sido confirmada; el error ocurrió después del COMMIT.';
        END;

        THROW;
    END CATCH;
END;
GO

/*
    Ejecución manual en simulación:

    EXEC dbo.usp_mantenimiento_mensual
        @EjecutarMantenimiento = 0,
        @ActualizarEstadisticas = 0;

    Ejecución que utilizará el job:

    EXEC dbo.usp_mantenimiento_mensual
        @EjecutarMantenimiento = 1,
        @ActualizarEstadisticas = 1;
*/