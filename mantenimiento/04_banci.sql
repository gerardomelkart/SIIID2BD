-- Ejecutar en la base seleccionada. Instala el SP; no ejecuta limpieza.
GO
CREATE OR ALTER PROCEDURE dbo.usp_mantenimiento_banci
    @EjecutarMantenimiento BIT = 0,
    @ActualizarEstadisticas BIT = 1,
    @DiasRetencion INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 OR (2 & @@OPTIONS) = 2
        THROW 51070, 'Ejecute sin transacciones abiertas ni IMPLICIT_TRANSACTIONS.', 1;
    IF @EjecutarMantenimiento IS NULL OR @ActualizarEstadisticas IS NULL
       OR @DiasRetencion IS NULL OR @DiasRetencion < 90 OR @DiasRetencion > 36500
        THROW 51071, 'Parámetros inválidos; retención permitida: 90 a 36500 días.', 1;
    IF OBJECT_ID(N'dbo.banci_carga', N'U') IS NULL
       OR OBJECT_ID(N'dbo.banci_carga_tmp_carpeta', N'U') IS NULL
       OR OBJECT_ID(N'dbo.banci_carga_tmp_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.banci_carga_tmp_victima', N'U') IS NULL
        THROW 51072, 'Falta la estructura de cargas BANCI.', 1;

    DECLARE @Limite DATETIME2(7) = DATEADD(DAY, -@DiasRetencion, SYSDATETIME());
    DECLARE @Victimas INT = 0, @Delitos INT = 0, @Carpetas INT = 0;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- El bloqueo dura hasta COMMIT/ROLLBACK, incluso en simulación.
        SELECT id_banci_carga INTO #Rechazadas
        FROM dbo.banci_carga WITH (TABLOCKX, HOLDLOCK)
        WHERE estado = N'RECHAZADO_VALIDACION'
          AND fecha_carga < @Limite
          AND COALESCE(fecha_confirmacion, fecha_fin_procesamiento, fecha_carga) < @Limite;

        DELETE t FROM dbo.banci_carga_tmp_victima t
        JOIN #Rechazadas c ON c.id_banci_carga = t.id_banci_carga;
        SET @Victimas = @@ROWCOUNT;
        DELETE t FROM dbo.banci_carga_tmp_delito t
        JOIN #Rechazadas c ON c.id_banci_carga = t.id_banci_carga;
        SET @Delitos = @@ROWCOUNT;
        DELETE t FROM dbo.banci_carga_tmp_carpeta t
        JOIN #Rechazadas c ON c.id_banci_carga = t.id_banci_carga;
        SET @Carpetas = @@ROWCOUNT;

        IF @EjecutarMantenimiento = 1 COMMIT TRANSACTION;
        ELSE ROLLBACK TRANSACTION;

        SELECT N'BANCI' AS modulo, @EjecutarMantenimiento AS aplicado,
            N'banci_carga_tmp_carpeta' AS tabla, @Carpetas AS registros_afectados
        UNION ALL SELECT N'BANCI', @EjecutarMantenimiento, N'banci_carga_tmp_delito', @Delitos
        UNION ALL SELECT N'BANCI', @EjecutarMantenimiento, N'banci_carga_tmp_victima', @Victimas;

        -- Sin DELETE en tablas definitivas, históricos, bitácoras, archivos,
        -- observaciones ni banci_actualizacion_v2 (conserva decisiones y JSON).
        IF @EjecutarMantenimiento = 1 AND @ActualizarEstadisticas = 1
        BEGIN
            DECLARE @Sql NVARCHAR(MAX) = N'';
            SELECT @Sql = @Sql + N'UPDATE STATISTICS ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N';' + CHAR(10)
            FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
            WHERE s.name = N'dbo' AND t.name LIKE N'banci[_]%'
              AND t.is_ms_shipped = 0 AND t.is_memory_optimized = 0;
            EXEC sys.sp_executesql @Sql;
        END;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        -- Si fallaron estadísticas, la limpieza puede estar confirmada.
        THROW;
    END CATCH;
END;
GO
