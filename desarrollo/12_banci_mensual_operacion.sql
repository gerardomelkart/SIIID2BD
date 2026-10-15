-- Aplicar después del script 11. No borra datos ni recrea tablas.
-- Habilita la disponibilidad de históricos; su permiso permanece con el valor configurado.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() IN(N'master',N'model',N'msdb',N'tempdb') THROW 52930,'Seleccione la base SIIID2.',1;
IF @@TRANCOUNT<>0 THROW 52930,'Ejecute sin transacción abierta.',1;
IF COL_LENGTH(N'dbo.banci_carga',N'mes_corte') IS NULL THROW 52930,'Ejecute primero el script 11.',1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT;
    EXEC @Lock=sys.sp_getapplock @Resource=N'SIIID2:CONFIGURACION',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
    IF @Lock<0 THROW 52930,'No fue posible bloquear la configuración.',1;
    ALTER TABLE dbo.banci_delito ALTER COLUMN dto NVARCHAR(2000) NULL;
    ALTER TABLE dbo.banci_delito ALTER COLUMN moda_dto NVARCHAR(2000) NULL;
    ALTER TABLE dbo.banci_delito ALTER COLUMN dom_hchos NVARCHAR(MAX) NULL;
    ALTER TABLE dbo.banci_delito ALTER COLUMN id_loc_hchos NVARCHAR(250) NULL;
    ALTER TABLE dbo.banci_delito ALTER COLUMN id_col_hchos NVARCHAR(250) NULL;
    ALTER TABLE dbo.banci_victima ALTER COLUMN curp_vicfem NVARCHAR(250) NULL;
    UPDATE c SET disponible=1 FROM dbo.sistema_configuracion c
    JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo
    WHERE m.clave=N'BANCI' AND c.clave IN(N'PERMITIR_CORTES_ANTERIORES',N'VALIDACIONES_CAMPOS');
    UPDATE dbo.sistema_configuracion_version SET version=version+1,fecha_modificacion=SYSUTCDATETIME() WHERE id=1;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
