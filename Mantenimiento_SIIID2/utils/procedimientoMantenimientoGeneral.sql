USE siiid2;
GO

IF OBJECT_ID(N'dbo.mantenimiento_ejecucion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.mantenimiento_ejecucion
    (
        id_mantenimiento_ejecucion BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_mantenimiento_ejecucion PRIMARY KEY,
        id_ejecucion UNIQUEIDENTIFIER NOT NULL,
        modulo NVARCHAR(20) NOT NULL,
        fecha_inicio DATETIME2(0) NULL,
        fecha_fin DATETIME2(0) NULL,
        ejecutar_mantenimiento BIT NOT NULL,
        actualizar_estadisticas BIT NOT NULL,
        estado NVARCHAR(20) NOT NULL,
        error_numero INT NULL,
        mensaje NVARCHAR(4000) NULL,
        login_ejecucion NVARCHAR(128) NOT NULL,
        CONSTRAINT UQ_mantenimiento_ejecucion_modulo UNIQUE (id_ejecucion, modulo)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_mantenimiento_general
    @EjecutarMantenimiento BIT = 0,
    @ActualizarEstadisticas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT <> 0 OR (2 & @@OPTIONS) = 2
        THROW 51050, 'Ejecute el mantenimiento general sin transacciones abiertas ni IMPLICIT_TRANSACTIONS.', 1;

    IF @EjecutarMantenimiento IS NULL OR @ActualizarEstadisticas IS NULL
        THROW 51051, 'Los parámetros de mantenimiento no admiten NULL.', 1;

    IF OBJECT_ID(N'dbo.usp_mantenimiento_mensual', N'P') IS NULL
       OR OBJECT_ID(N'dbo.usp_mantenimiento_semanal', N'P') IS NULL
       OR OBJECT_ID(N'dbo.usp_mantenimiento_federal', N'P') IS NULL
        THROW 51052, 'Instale los tres procedimientos de mantenimiento antes de ejecutar el general.', 1;

    DECLARE @IdEjecucion UNIQUEIDENTIFIER = NEWID();
    DECLARE @ResultadoBloqueo INT;
    DECLARE @Modulo NVARCHAR(20);
    DECLARE @Paso INT = 1;

    EXEC @ResultadoBloqueo = sys.sp_getapplock
        @Resource = N'SIIID2_MANTENIMIENTO_GENERAL',
        @LockMode = N'Exclusive',
        @LockOwner = N'Session',
        @LockTimeout = 0;

    IF @ResultadoBloqueo < 0
        THROW 51053, 'Ya hay otro mantenimiento general en ejecución o no se pudo adquirir el bloqueo.', 1;

    BEGIN TRY
        INSERT INTO dbo.mantenimiento_ejecucion
            (id_ejecucion, modulo, ejecutar_mantenimiento, actualizar_estadisticas, estado, login_ejecucion)
        SELECT @IdEjecucion, modulo, @EjecutarMantenimiento, @ActualizarEstadisticas, N'PENDIENTE', ORIGINAL_LOGIN()
        FROM (VALUES (N'MENSUAL'), (N'SEMANAL'), (N'FEDERAL')) modulos(modulo);

        -- Cada SP administra su transacción. No envolver los tres en una sola:
        -- el modo de simulación de los SP existentes hace ROLLBACK.
        WHILE @Paso <= 3
        BEGIN
            SET @Modulo = CASE @Paso WHEN 1 THEN N'MENSUAL' WHEN 2 THEN N'SEMANAL' ELSE N'FEDERAL' END;

            UPDATE dbo.mantenimiento_ejecucion
            SET estado = N'EN_PROCESO', fecha_inicio = SYSDATETIME()
            WHERE id_ejecucion = @IdEjecucion AND modulo = @Modulo;

            PRINT N'INICIANDO MANTENIMIENTO ' + @Modulo;

            IF @Paso = 1
                EXEC dbo.usp_mantenimiento_mensual @EjecutarMantenimiento = @EjecutarMantenimiento, @ActualizarEstadisticas = @ActualizarEstadisticas;
            ELSE IF @Paso = 2
                EXEC dbo.usp_mantenimiento_semanal @EjecutarMantenimiento = @EjecutarMantenimiento, @ActualizarEstadisticas = @ActualizarEstadisticas;
            ELSE
                EXEC dbo.usp_mantenimiento_federal @EjecutarMantenimiento = @EjecutarMantenimiento, @ActualizarEstadisticas = @ActualizarEstadisticas;

            UPDATE dbo.mantenimiento_ejecucion
            SET estado = CASE WHEN @EjecutarMantenimiento = 1 THEN N'CORRECTO' ELSE N'SIMULADO' END,
                fecha_fin = SYSDATETIME(),
                mensaje = CASE WHEN @EjecutarMantenimiento = 1 THEN N'Mantenimiento terminado.' ELSE N'Simulación terminada; limpieza revertida.' END
            WHERE id_ejecucion = @IdEjecucion AND modulo = @Modulo;

            SET @Paso += 1;
        END;

        EXEC sys.sp_releaseapplock @Resource = N'SIIID2_MANTENIMIENTO_GENERAL', @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        UPDATE dbo.mantenimiento_ejecucion
        SET estado = N'ERROR', fecha_fin = SYSDATETIME(), error_numero = ERROR_NUMBER(),
            mensaje = LEFT(CONCAT(ERROR_MESSAGE(), N' Si el fallo ocurrió al actualizar estadísticas, la limpieza del módulo puede estar confirmada. Los módulos anteriores conservan su resultado.'), 4000)
        WHERE id_ejecucion = @IdEjecucion AND modulo = @Modulo;

        UPDATE dbo.mantenimiento_ejecucion
        SET estado = N'OMITIDO', fecha_fin = SYSDATETIME(), mensaje = N'No ejecutado por error en un módulo anterior.'
        WHERE id_ejecucion = @IdEjecucion AND estado = N'PENDIENTE';

        EXEC sys.sp_releaseapplock @Resource = N'SIIID2_MANTENIMIENTO_GENERAL', @LockOwner = N'Session';
        THROW;
    END CATCH;

    SELECT id_ejecucion, modulo, fecha_inicio, fecha_fin, estado, error_numero, mensaje
    FROM dbo.mantenimiento_ejecucion
    WHERE id_ejecucion = @IdEjecucion
    ORDER BY CASE modulo WHEN N'MENSUAL' THEN 1 WHEN N'SEMANAL' THEN 2 ELSE 3 END;
END;
GO
