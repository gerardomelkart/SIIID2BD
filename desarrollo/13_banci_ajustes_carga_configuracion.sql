-- Aplicar después del 12. Reubica la opción pendiente; no modifica registros operativos.
-- El cruce corresponde a actualizaciones del Consolidado. No se habilita hasta completar su flujo.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() IN(N'master',N'model',N'msdb',N'tempdb') THROW 52931,'Seleccione la base SIIID2.',1;
IF @@TRANCOUNT<>0 THROW 52931,'Ejecute sin transacción abierta.',1;
IF COL_LENGTH(N'dbo.banci_carga',N'mes_corte') IS NULL THROW 52931,'Instale primero BANCI mensual.',1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT, @Mensual TINYINT, @Banci TINYINT;
    EXEC @Lock=sys.sp_getapplock @Resource=N'SIIID2:CONFIGURACION',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
    IF @Lock<0 THROW 52931,'La configuración está siendo modificada.',1;
    SELECT @Mensual=id_modulo FROM dbo.catalogo_modulo WHERE clave=N'MENSUAL';
    SELECT @Banci=id_modulo FROM dbo.catalogo_modulo WHERE clave=N'BANCI';
    IF @Mensual IS NULL OR @Banci IS NULL THROW 52931,'Faltan los módulos Consolidado o BANCI.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.sistema_configuracion WHERE id_modulo=@Mensual AND clave=N'CRUCE_ACTUALIZACION_CONSOLIDADO')
        INSERT dbo.sistema_configuracion(id_modulo,clave,descripcion,habilitado,disponible)
        VALUES(@Mensual,N'CRUCE_ACTUALIZACION_CONSOLIDADO',N'Exigir actualización BANCI al modificar desapariciones en el Consolidado: pendiente de implementación',0,0);
    DELETE FROM dbo.sistema_configuracion WHERE id_modulo=@Banci AND clave=N'CRUCE_ACTUALIZACION_CONSOLIDADO';
    UPDATE dbo.sistema_configuracion_version SET version=version+1,fecha_modificacion=SYSUTCDATETIME() WHERE id=1;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
SELECT m.clave AS modulo,c.clave,c.descripcion,c.habilitado,c.disponible
FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo
WHERE c.clave=N'CRUCE_ACTUALIZACION_CONSOLIDADO';
