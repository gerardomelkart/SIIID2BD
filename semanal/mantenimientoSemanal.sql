USE siiid2;
GO

CREATE OR ALTER PROCEDURE dbo.usp_mantenimiento_semanal @EjecutarMantenimiento BIT = 0, @ActualizarEstadisticas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @VictimasEliminadas INT = 0;
    DECLARE @DelitosEliminados INT = 0;
    DECLARE @CarpetasEliminadas INT = 0;
    DECLARE @MantenimientoConfirmado BIT = 0;

        IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
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

    IF OBJECT_ID('tempdb..#CargasStagingProtegidas') IS NOT NULL DROP TABLE #CargasStagingProtegidas;

    CREATE TABLE #CargasStagingProtegidas
    (
        id_semanal_carga BIGINT NOT NULL PRIMARY KEY,
        motivo_proteccion NVARCHAR(100) NOT NULL
    );

    INSERT INTO #CargasStagingProtegidas (id_semanal_carga, motivo_proteccion)
    SELECT sc.id_semanal_carga, N'CARGA_PENDIENTE'
    FROM dbo.semanal_carga sc
       WHERE sc.estado IN (N'VALIDADO_PENDIENTE', N'VALIDADO_PENDIENTE_ACTUALIZACION', N'PENDIENTE_APROBACION')
      AND sc.activo = 1;

    INSERT INTO #CargasStagingProtegidas (id_semanal_carga, motivo_proteccion)
    SELECT sc.id_semanal_carga, N'ULTIMO_RECHAZO_ADMIN_VIGENTE'
    FROM dbo.semanal_carga sc
    WHERE sc.estado = N'RECHAZADO_ADMIN'
      AND sc.activo = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.semanal_carga sc2
          WHERE ISNULL(sc2.id_entidad_federativa, 0) = ISNULL(sc.id_entidad_federativa, 0)
            AND sc2.id_usuario_carga = sc.id_usuario_carga
            AND sc2.anio_semana = sc.anio_semana
            AND sc2.numero_semana = sc.numero_semana
            AND ISNULL(sc2.tipo_carga, N'') = ISNULL(sc.tipo_carga, N'')
            AND sc2.activo = 1
            AND sc2.id_semanal_carga > sc.id_semanal_carga
            AND sc2.estado IN (N'VALIDADO_PENDIENTE', N'VALIDADO_PENDIENTE_ACTUALIZACION', N'PENDIENTE_APROBACION', N'RECHAZADO_ADMIN', N'CONFIRMADO', N'CONFIRMADO_ACTUALIZACION')
      );

    PRINT N'============================================================';
    PRINT N'CARGAS SEMANALES CON STAGING PROTEGIDO';
    PRINT N'============================================================';

    SELECT sc.id_semanal_carga, sc.codigo_referencia, sc.id_entidad_federativa, sc.anio_semana, sc.numero_semana, sc.tipo_carga, sc.estado, protegida.motivo_proteccion
    FROM dbo.semanal_carga sc
    INNER JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = sc.id_semanal_carga
    ORDER BY sc.id_entidad_federativa, sc.anio_semana, sc.numero_semana, sc.tipo_carga, sc.id_semanal_carga;

    PRINT N'============================================================';
    PRINT N'RECHAZOS ADMINISTRATIVOS';
    PRINT N'============================================================';

    SELECT sc.id_semanal_carga, sc.codigo_referencia, sc.id_entidad_federativa, sc.anio_semana, sc.numero_semana, sc.tipo_carga, sc.estado, CASE WHEN protegida.id_semanal_carga IS NULL THEN N'ELIMINABLE' ELSE N'PROTEGIDO' END AS estado_staging, protegida.motivo_proteccion
    FROM dbo.semanal_carga sc
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = sc.id_semanal_carga
    WHERE sc.estado = N'RECHAZADO_ADMIN'
    ORDER BY sc.id_entidad_federativa, sc.anio_semana, sc.numero_semana, sc.tipo_carga, sc.id_semanal_carga;

    PRINT N'============================================================';
    PRINT N'CONTEOS ANTES DEL MANTENIMIENTO';
    PRINT N'============================================================';

    SELECT N'semanal_carga_tmp_carpeta' AS tabla, COUNT_BIG(*) AS total, COUNT_BIG(protegida.id_semanal_carga) AS protegidos, COUNT_BIG(*) - COUNT_BIG(protegida.id_semanal_carga) AS eliminables
    FROM dbo.semanal_carga_tmp_carpeta tmp
    INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga

    UNION ALL

    SELECT N'semanal_carga_tmp_delito', COUNT_BIG(*), COUNT_BIG(protegida.id_semanal_carga), COUNT_BIG(*) - COUNT_BIG(protegida.id_semanal_carga)
    FROM dbo.semanal_carga_tmp_delito tmp
    INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga

    UNION ALL

    SELECT N'semanal_carga_tmp_victima', COUNT_BIG(*), COUNT_BIG(protegida.id_semanal_carga), COUNT_BIG(*) - COUNT_BIG(protegida.id_semanal_carga)
    FROM dbo.semanal_carga_tmp_victima tmp
    INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE tmp
        FROM dbo.semanal_carga_tmp_victima tmp
        INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga
        WHERE protegida.id_semanal_carga IS NULL;

        SET @VictimasEliminadas = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.semanal_carga_tmp_delito tmp
        INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga
        WHERE protegida.id_semanal_carga IS NULL;

        SET @DelitosEliminados = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.semanal_carga_tmp_carpeta tmp
        INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
        LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga
        WHERE protegida.id_semanal_carga IS NULL;

        SET @CarpetasEliminadas = @@ROWCOUNT;

        IF @EjecutarMantenimiento = 1
        BEGIN
            COMMIT TRANSACTION;
            SET @MantenimientoConfirmado = 1;
            PRINT N'MANTENIMIENTO SEMANAL CONFIRMADO.';
        END
        ELSE
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT N'SIMULACIÓN SEMANAL TERMINADA. NO SE BORRÓ INFORMACIÓN.';
        END;

        SELECT CASE WHEN @EjecutarMantenimiento = 1 THEN N'EJECUCIÓN REAL' ELSE N'SIMULACIÓN' END AS modo, @CarpetasEliminadas AS tmp_carpetas_eliminadas, @DelitosEliminados AS tmp_delitos_eliminados, @VictimasEliminadas AS tmp_victimas_eliminadas, @CarpetasEliminadas + @DelitosEliminados + @VictimasEliminadas AS total_temporales_eliminados;

        IF @MantenimientoConfirmado = 1 AND @ActualizarEstadisticas = 1
        BEGIN
            UPDATE STATISTICS dbo.semanal_carga;
            UPDATE STATISTICS dbo.semanal_carga_bloque;
            UPDATE STATISTICS dbo.semanal_carga_tmp_carpeta;
            UPDATE STATISTICS dbo.semanal_carga_tmp_delito;
            UPDATE STATISTICS dbo.semanal_carga_tmp_victima;
            UPDATE STATISTICS dbo.semanal_carga_delito_configurado;
            UPDATE STATISTICS dbo.semanal_carpeta_investigacion;
            UPDATE STATISTICS dbo.semanal_carpeta_investigacion_historico;
            UPDATE STATISTICS dbo.semanal_delito;
            UPDATE STATISTICS dbo.semanal_delito_historico;
            UPDATE STATISTICS dbo.semanal_victima;
            UPDATE STATISTICS dbo.semanal_victima_historico;
            PRINT N'ESTADÍSTICAS SEMANALES ACTUALIZADAS.';
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    PRINT N'============================================================';
    PRINT N'CONTEOS DESPUÉS DEL MANTENIMIENTO';
    PRINT N'============================================================';

    SELECT N'semanal_carga_tmp_carpeta' AS tabla, COUNT_BIG(*) AS total, COUNT_BIG(protegida.id_semanal_carga) AS protegidos, COUNT_BIG(*) - COUNT_BIG(protegida.id_semanal_carga) AS eliminables
    FROM dbo.semanal_carga_tmp_carpeta tmp
    INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga

    UNION ALL

    SELECT N'semanal_carga_tmp_delito', COUNT_BIG(*), COUNT_BIG(protegida.id_semanal_carga), COUNT_BIG(*) - COUNT_BIG(protegida.id_semanal_carga)
    FROM dbo.semanal_carga_tmp_delito tmp
    INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga

    UNION ALL

    SELECT N'semanal_carga_tmp_victima', COUNT_BIG(*), COUNT_BIG(protegida.id_semanal_carga), COUNT_BIG(*) - COUNT_BIG(protegida.id_semanal_carga)
    FROM dbo.semanal_carga_tmp_victima tmp
    INNER JOIN dbo.semanal_carga sc ON sc.id_semanal_carga = tmp.id_semanal_carga
    LEFT JOIN #CargasStagingProtegidas protegida ON protegida.id_semanal_carga = tmp.id_semanal_carga;

    DROP TABLE #CargasStagingProtegidas;
END;
GO


EXEC dbo.usp_mantenimiento_semanal @EjecutarMantenimiento = 0, @ActualizarEstadisticas = 0;