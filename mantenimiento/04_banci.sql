-- No ejecuta mantenimiento; instala la versión mensual conservando su firma.
CREATE OR ALTER PROCEDURE dbo.usp_mantenimiento_banci
 @EjecutarMantenimiento BIT=0, @ActualizarEstadisticas BIT=1, @DiasRetencion INT=90
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2 THROW 51070,'Ejecute sin transacciones abiertas ni IMPLICIT_TRANSACTIONS.',1;
 IF @EjecutarMantenimiento IS NULL OR @ActualizarEstadisticas IS NULL OR @DiasRetencion IS NULL OR @DiasRetencion NOT BETWEEN 90 AND 36500
    THROW 51071,'Parámetros de mantenimiento inválidos.',1;
 DECLARE @Limite DATETIME2(7)=DATEADD(DAY,-@DiasRetencion,SYSUTCDATETIME());
 BEGIN TRY
 BEGIN TRANSACTION;
 SELECT id_banci_carga INTO #Rechazadas FROM dbo.banci_carga WITH(UPDLOCK,HOLDLOCK)
 WHERE estado IN(N'RECHAZADO_VALIDACION',N'RECHAZADO_ADMIN',N'RECHAZADO_USUARIO') AND fecha_validacion<@Limite;
 DELETE t FROM dbo.banci_carga_tmp_victima t JOIN #Rechazadas c ON c.id_banci_carga=t.id_banci_carga;
 DELETE t FROM dbo.banci_carga_tmp_delito t JOIN #Rechazadas c ON c.id_banci_carga=t.id_banci_carga;
 DELETE t FROM dbo.banci_carga_tmp_carpeta t JOIN #Rechazadas c ON c.id_banci_carga=t.id_banci_carga;
 IF @EjecutarMantenimiento=1 COMMIT; ELSE ROLLBACK;
 IF @EjecutarMantenimiento=1 AND @ActualizarEstadisticas=1
 BEGIN
  UPDATE STATISTICS dbo.banci_carga;
  UPDATE STATISTICS dbo.banci_carga_tmp_carpeta;
  UPDATE STATISTICS dbo.banci_carga_tmp_delito;
  UPDATE STATISTICS dbo.banci_carga_tmp_victima;
 END;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
