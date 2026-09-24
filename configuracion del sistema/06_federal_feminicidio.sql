USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'siiid2' THROW 52600, 'Base incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_validacion_configuracion', N'U') IS NULL THROW 52600, 'Requiere configuración 01 a 05.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT;
    EXEC @Lock = sys.sp_getapplock @Resource=N'SIIID2:CONFIGURACION', @LockMode=N'Exclusive', @LockOwner=N'Transaction', @LockTimeout=10000;
    IF @Lock < 0 THROW 52601, 'Configuración ocupada. Reintente.', 1;
    DECLARE @IdModulo TINYINT = (SELECT id_modulo FROM dbo.catalogo_modulo WHERE clave = N'FEDERAL');
    IF @IdModulo IS NULL THROW 52605, 'Falta el módulo Federal.', 1;
    IF OBJECT_ID(N'dbo.federal_carga_tmp_victima', N'U') IS NULL THROW 52600, 'Falta federal_carga_tmp_victima.', 1;
    IF COL_LENGTH(N'dbo.federal_carga_tmp_victima', N'nombre_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_carga_tmp_victima ADD nombre_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_carga_tmp_victima', N'primer_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_carga_tmp_victima ADD primer_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_carga_tmp_victima', N'segundo_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_carga_tmp_victima ADD segundo_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_carga_tmp_victima', N'curp_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_carga_tmp_victima ADD curp_vicfem NVARCHAR(250) NULL;');
    IF OBJECT_ID(N'dbo.federal_victima', N'U') IS NULL THROW 52600, 'Falta federal_victima.', 1;
    IF COL_LENGTH(N'dbo.federal_victima', N'nombre_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima ADD nombre_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima', N'primer_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima ADD primer_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima', N'segundo_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima ADD segundo_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima', N'curp_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima ADD curp_vicfem NVARCHAR(250) NULL;');
    IF OBJECT_ID(N'dbo.federal_victima_historico', N'U') IS NULL THROW 52600, 'Falta federal_victima_historico.', 1;
    IF COL_LENGTH(N'dbo.federal_victima_historico', N'nombre_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima_historico ADD nombre_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima_historico', N'primer_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima_historico ADD primer_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima_historico', N'segundo_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima_historico ADD segundo_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima_historico', N'curp_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima_historico ADD curp_vicfem NVARCHAR(250) NULL;');
    INSERT dbo.sistema_configuracion (id_modulo, clave, descripcion, habilitado, disponible)
    SELECT @IdModulo, v.clave, v.descripcion, 0, 1 FROM (VALUES
        (N'FEMINICIDIO_DATOS_ADICIONALES', N'Campos y reglas adicionales de víctimas de feminicidio'),
        (N'RENAPO', N'Consulta externa de CURP de víctimas de feminicidio en RENAPO')
    ) v(clave, descripcion)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion c WHERE c.id_modulo = @IdModulo AND c.clave = v.clave);
    IF @@ROWCOUNT > 0 UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
