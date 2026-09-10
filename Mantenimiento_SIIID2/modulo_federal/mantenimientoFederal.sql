USE siiid2;
GO

CREATE OR ALTER PROCEDURE dbo.usp_mantenimiento_federal
    @EjecutarMantenimiento BIT = 0,
    @ActualizarEstadisticas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0 OR (2 & @@OPTIONS) = 2
        THROW 51040, 'Ejecute el mantenimiento sin transacciones abiertas ni IMPLICIT_TRANSACTIONS.', 1;

    IF @EjecutarMantenimiento IS NULL OR @ActualizarEstadisticas IS NULL
        THROW 51041, 'Los parámetros de mantenimiento no admiten NULL.', 1;

    DECLARE @MantenimientoConfirmado BIT = 0;
    DECLARE @VictimasEliminadas INT = 0;
    DECLARE @DelitosEliminados INT = 0;
    DECLARE @CarpetasEliminadas INT = 0;

    IF OBJECT_ID(N'dbo.federal_carga', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_carga_tmp_carpeta', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_carga_tmp_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_carga_tmp_victima', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_carpeta_investigacion', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_carpeta_investigacion_historico', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_delito_historico', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_victima', N'U') IS NULL
       OR OBJECT_ID(N'dbo.federal_victima_historico', N'U') IS NULL
    BEGIN
        THROW 51042, 'No está completa la estructura requerida por el mantenimiento federal.', 1;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Congela las cargas durante la limpieza: evita borrar una carga nueva
        -- que aparezca después de calcular las protecciones.
        SELECT id_federal_carga, id_usuario_carga, codigo_referencia, mes_corte,
            anio_corte, tipo_carga, estado, activo, fecha_validacion, fecha_confirmacion
        INTO #CargasFederalMantenimiento
        FROM dbo.federal_carga WITH (TABLOCKX, HOLDLOCK);

        CREATE UNIQUE CLUSTERED INDEX IX_CargasFederalMantenimiento
            ON #CargasFederalMantenimiento(id_federal_carga);

        CREATE TABLE #CargasFederalProtegidas
        (
            id_federal_carga BIGINT NOT NULL PRIMARY KEY,
            motivo_proteccion NVARCHAR(100) NOT NULL
        );

        INSERT INTO #CargasFederalProtegidas (id_federal_carga, motivo_proteccion)
        SELECT c.id_federal_carga, N'CARGA_PENDIENTE'
        FROM #CargasFederalMantenimiento c
        WHERE c.estado IN (N'VALIDADO_PENDIENTE', N'VALIDADO_PENDIENTE_ACTUALIZACION', N'PENDIENTE_APROBACION');

        INSERT INTO #CargasFederalProtegidas (id_federal_carga, motivo_proteccion)
        SELECT c.id_federal_carga, N'ULTIMO_RECHAZO_ADMIN_VIGENTE'
        FROM #CargasFederalMantenimiento c
        WHERE c.estado = N'RECHAZADO_ADMIN'
          AND c.activo = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM #CargasFederalMantenimiento c2
              WHERE c2.mes_corte = c.mes_corte
                AND c2.anio_corte = c.anio_corte
                AND ISNULL(c2.tipo_carga, N'') = ISNULL(c.tipo_carga, N'')
                AND c2.activo = 1
                AND c2.id_federal_carga > c.id_federal_carga
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
            c.id_federal_carga,
            c.codigo_referencia,
            c.id_usuario_carga,
            c.mes_corte,
            c.anio_corte,
            c.tipo_carga,
            c.estado,
            c.fecha_validacion,
            c.fecha_confirmacion AS fecha_rechazo,
            CASE WHEN protegida.id_federal_carga IS NOT NULL THEN N'PROTEGIDO' ELSE N'ELIMINABLE' END AS estado_staging,
            protegida.motivo_proteccion
        FROM #CargasFederalMantenimiento c
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = c.id_federal_carga
        WHERE c.estado = N'RECHAZADO_ADMIN'
        ORDER BY c.id_usuario_carga, c.anio_corte, c.mes_corte, c.tipo_carga, c.id_federal_carga;

        PRINT 'CONTEOS ANTES DEL MANTENIMIENTO';

        SELECT N'federal_carga_tmp_carpeta' AS tabla, COUNT(*) AS total, COUNT(protegida.id_federal_carga) AS protegidos, COUNT(*) - COUNT(protegida.id_federal_carga) AS eliminables
        FROM dbo.federal_carga_tmp_carpeta tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga
        UNION ALL
        SELECT N'federal_carga_tmp_delito', COUNT(*), COUNT(protegida.id_federal_carga), COUNT(*) - COUNT(protegida.id_federal_carga)
        FROM dbo.federal_carga_tmp_delito tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga
        UNION ALL
        SELECT N'federal_carga_tmp_victima', COUNT(*), COUNT(protegida.id_federal_carga), COUNT(*) - COUNT(protegida.id_federal_carga)
        FROM dbo.federal_carga_tmp_victima tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga;

        DELETE tmp
        FROM dbo.federal_carga_tmp_victima tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga
        WHERE protegida.id_federal_carga IS NULL;

        SET @VictimasEliminadas = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.federal_carga_tmp_delito tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga
        WHERE protegida.id_federal_carga IS NULL;

        SET @DelitosEliminados = @@ROWCOUNT;

        DELETE tmp
        FROM dbo.federal_carga_tmp_carpeta tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga
        WHERE protegida.id_federal_carga IS NULL;

        SET @CarpetasEliminadas = @@ROWCOUNT;

        SELECT N'federal_carga_tmp_carpeta' AS tabla, @CarpetasEliminadas AS registros_afectados
        UNION ALL SELECT N'federal_carga_tmp_delito', @DelitosEliminados
        UNION ALL SELECT N'federal_carga_tmp_victima', @VictimasEliminadas;

        IF @EjecutarMantenimiento = 1
        BEGIN
            COMMIT TRANSACTION;
            SET @MantenimientoConfirmado = 1;
            PRINT 'MANTENIMIENTO FEDERAL CONFIRMADO. Limpieza de staging aplicada correctamente.';
        END
        ELSE
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'SIMULACIÓN FEDERAL TERMINADA. No se eliminó información.';
            RETURN;
        END;

        PRINT 'CONTEOS DESPUÉS DEL MANTENIMIENTO';

        SELECT N'federal_carga_tmp_carpeta' AS tabla, COUNT(*) AS total, COUNT(protegida.id_federal_carga) AS protegidos, COUNT(*) - COUNT(protegida.id_federal_carga) AS eliminables
        FROM dbo.federal_carga_tmp_carpeta tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga
        UNION ALL
        SELECT N'federal_carga_tmp_delito', COUNT(*), COUNT(protegida.id_federal_carga), COUNT(*) - COUNT(protegida.id_federal_carga)
        FROM dbo.federal_carga_tmp_delito tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga
        UNION ALL
        SELECT N'federal_carga_tmp_victima', COUNT(*), COUNT(protegida.id_federal_carga), COUNT(*) - COUNT(protegida.id_federal_carga)
        FROM dbo.federal_carga_tmp_victima tmp
        INNER JOIN #CargasFederalMantenimiento c ON c.id_federal_carga = tmp.id_federal_carga
        LEFT JOIN #CargasFederalProtegidas protegida ON protegida.id_federal_carga = tmp.id_federal_carga;

        IF @MantenimientoConfirmado = 1 AND @ActualizarEstadisticas = 1
        BEGIN
            UPDATE STATISTICS dbo.federal_carga_tmp_carpeta WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_carga_tmp_delito WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_carga_tmp_victima WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_carga WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_carpeta_investigacion WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_delito WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_victima WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_carpeta_investigacion_historico WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_delito_historico WITH FULLSCAN;
            UPDATE STATISTICS dbo.federal_victima_historico WITH FULLSCAN;
            PRINT 'Estadísticas federales actualizadas correctamente.';
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        IF @MantenimientoConfirmado = 1
        BEGIN
            PRINT 'La limpieza federal ya había sido confirmada; el error ocurrió después del COMMIT.';
        END;

        THROW;
    END CATCH;
END;
GO

/*
    Simulación: ejecuta DELETE y ROLLBACK; puede tomar bloqueos temporales.
    No altera registros definitivos, históricos, usuarios ni archivos originales.

    Ejecución manual en simulación:

    EXEC dbo.usp_mantenimiento_federal
        @EjecutarMantenimiento = 0,
        @ActualizarEstadisticas = 0;

    Ejecución que utilizará el job:

    EXEC dbo.usp_mantenimiento_federal
        @EjecutarMantenimiento = 1,
        @ActualizarEstadisticas = 1;
*/
