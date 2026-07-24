USE master;
GO

IF DB_ID(N'siiid2') IS NULL THROW 50050, 'No existe la base de datos siiid2.', 1;

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'siiid2' AND is_auto_close_on = 1)
BEGIN
    ALTER DATABASE [siiid2] SET AUTO_CLOSE OFF;
END;

IF OBJECT_ID(N'siiid2.dbo.usp_mantenimiento_semanal', N'P') IS NULL THROW 50051, 'No existe dbo.usp_mantenimiento_semanal en siiid2. Ejecute primero semanal/mantenimientoSemanal.sql.', 1;
GO

USE msdb;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @NombreJob SYSNAME = N'SIIID2 - Mantenimiento semanal';
DECLARE @NombreHorario SYSNAME = N'SIIID2 - Semanal - Día 14 03:30';
DECLARE @JobId UNIQUEIDENTIFIER;
DECLARE @ScheduleId INT;
DECLARE @FechaInicio INT = CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112));

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = @NombreJob)
BEGIN
    EXEC dbo.sp_delete_job @job_name = @NombreJob, @delete_history = 1, @delete_unused_schedule = 1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.sysschedules horario
    INNER JOIN dbo.sysjobschedules job_horario ON job_horario.schedule_id = horario.schedule_id
    WHERE horario.name = @NombreHorario
)
BEGIN
    THROW 50052, 'El horario del mantenimiento semanal está asociado a otro Job y no puede reemplazarse automáticamente.', 1;
END;

IF EXISTS (SELECT 1 FROM dbo.sysschedules WHERE name = @NombreHorario)
BEGIN
    EXEC dbo.sp_delete_schedule @schedule_name = @NombreHorario;
END;

EXEC dbo.sp_add_job @job_name = @NombreJob, @enabled = 1, @description = N'Limpia únicamente el staging semanal no protegido y actualiza estadísticas el día 14 de cada mes a las 03:30. Conserva cargas, configuración, datos finales e históricos.', @owner_login_name = N'sa', @job_id = @JobId OUTPUT;

EXEC dbo.sp_add_jobstep @job_id = @JobId, @step_id = 1, @step_name = N'Ejecutar mantenimiento semanal', @subsystem = N'TSQL', @command = N'EXEC dbo.usp_mantenimiento_semanal @EjecutarMantenimiento = 1, @ActualizarEstadisticas = 1;', @database_name = N'siiid2', @on_success_action = 1, @on_fail_action = 2, @retry_attempts = 0, @retry_interval = 0;

EXEC dbo.sp_update_job @job_id = @JobId, @start_step_id = 1;

EXEC dbo.sp_add_jobschedule @job_id = @JobId, @name = @NombreHorario, @enabled = 1, @freq_type = 16, @freq_interval = 14, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = @FechaInicio, @active_end_date = 99991231, @active_start_time = 33000, @active_end_time = 235959, @schedule_id = @ScheduleId OUTPUT;

EXEC dbo.sp_add_jobserver @job_id = @JobId, @server_name = N'(LOCAL)';

IF (SELECT COUNT(*) FROM dbo.sysjobsteps WHERE job_id = @JobId) <> 1 THROW 50053, 'El Job semanal no quedó con exactamente un paso.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.sysjobsteps WHERE job_id = @JobId AND step_id = 1) THROW 50054, 'No quedó creado el paso 1 del Job semanal.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.sysjobservers WHERE job_id = @JobId AND server_id = 0) THROW 50055, 'El Job semanal no quedó asociado al servidor local.', 1;

SELECT job.name AS nombre_job, SUSER_SNAME(job.owner_sid) AS propietario, job.enabled AS habilitado, job.start_step_id, paso.step_id, paso.step_name, paso.subsystem, paso.database_name, paso.command, servidor.server_id, horario.name AS horario, horario.enabled AS horario_habilitado, horario.freq_type, horario.freq_interval, horario.active_start_date, horario.active_start_time
FROM dbo.sysjobs job
INNER JOIN dbo.sysjobsteps paso ON paso.job_id = job.job_id
INNER JOIN dbo.sysjobservers servidor ON servidor.job_id = job.job_id
INNER JOIN dbo.sysjobschedules job_horario ON job_horario.job_id = job.job_id
INNER JOIN dbo.sysschedules horario ON horario.schedule_id = job_horario.schedule_id
WHERE job.job_id = @JobId;
GO