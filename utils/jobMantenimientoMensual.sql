USE master;
GO

IF DB_ID(N'siiid2') IS NULL
BEGIN
    THROW 50040, 'No existe la base de datos siiid2.', 1;
END;
GO

IF OBJECT_ID(N'siiid2.dbo.usp_mantenimiento_mensual', N'P') IS NULL
BEGIN
    THROW 50041, 'No existe dbo.usp_mantenimiento_mensual en la base siiid2. Ejecute primero procedimientoMantenimientoMensual.sql.', 1;
END;
GO

USE msdb;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @NombreJob SYSNAME = N'SIIID2 - Mantenimiento mensual';
DECLARE @NombreHorario SYSNAME = N'SIIID2 - Mensual - Día 14 03:00';
DECLARE @JobId UNIQUEIDENTIFIER;
DECLARE @ScheduleId INT;
DECLARE @FechaInicio INT = CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112));

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.sysjobs
        WHERE name = @NombreJob
    )
    BEGIN
        EXEC dbo.sp_delete_job
            @job_name = @NombreJob,
            @delete_history = 1,
            @delete_unused_schedule = 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.sysschedules horario
        INNER JOIN dbo.sysjobschedules job_horario ON job_horario.schedule_id = horario.schedule_id
        WHERE horario.name = @NombreHorario
    )
    BEGIN
        THROW 50042, 'El horario del mantenimiento mensual está asociado a otro Job y no puede reemplazarse automáticamente.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.sysschedules
        WHERE name = @NombreHorario
    )
    BEGIN
        EXEC dbo.sp_delete_schedule @schedule_name = @NombreHorario;
    END;

    EXEC dbo.sp_add_job
        @job_name = @NombreJob,
        @enabled = 1,
        @description = N'Limpia el staging mensual no protegido y actualiza las estadísticas de SIIID2 el día 14 de cada mes a las 03:00.',
        @start_step_id = 1,
        @job_id = @JobId OUTPUT;

    EXEC dbo.sp_add_jobstep
        @job_id = @JobId,
        @step_id = 1,
        @step_name = N'Ejecutar mantenimiento mensual',
        @subsystem = N'TSQL',
        @command = N'EXEC dbo.usp_mantenimiento_mensual @EjecutarMantenimiento = 1, @ActualizarEstadisticas = 1;',
        @database_name = N'siiid2',
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 0,
        @retry_interval = 0;

    EXEC dbo.sp_add_jobschedule
        @job_id = @JobId,
        @name = @NombreHorario,
        @enabled = 1,
        @freq_type = 16,
        @freq_interval = 14,
        @freq_subday_type = 1,
        @freq_subday_interval = 0,
        @freq_relative_interval = 0,
        @freq_recurrence_factor = 1,
        @active_start_date = @FechaInicio,
        @active_end_date = 99991231,
        @active_start_time = 30000,
        @active_end_time = 235959,
        @schedule_id = @ScheduleId OUTPUT;

    EXEC dbo.sp_add_jobserver @job_id = @JobId;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;

SELECT
    job.name AS nombre_job,
    job.enabled AS job_habilitado,
    paso.step_id,
    paso.step_name AS nombre_paso,
    paso.database_name AS base_ejecucion,
    paso.command AS comando,
    horario.name AS nombre_horario,
    horario.enabled AS horario_habilitado,
    horario.freq_type,
    horario.freq_interval,
    horario.freq_recurrence_factor,
    horario.active_start_date,
    horario.active_start_time
FROM dbo.sysjobs job
INNER JOIN dbo.sysjobsteps paso ON paso.job_id = job.job_id
INNER JOIN dbo.sysjobschedules job_horario ON job_horario.job_id = job.job_id
INNER JOIN dbo.sysschedules horario ON horario.schedule_id = job_horario.schedule_id
WHERE job.job_id = @JobId;
GO