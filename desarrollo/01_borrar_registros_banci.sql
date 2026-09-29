-- SOLO DESARROLLO: elimina TODOS los registros operativos de BANCI, incluidos pendientes.
-- Ejecutar con la API detenida en la conexión de DESARROLLO; no contiene USE.
-- Conserva tablas, catálogos, usuarios, permisos y los demás módulos.
-- Vacía consecutivos NO_BANCI; las nuevas carpetas vuelven a empezar en 000001.
-- No reinicia las columnas IDENTITY internas ni elimina archivos físicos del servidor.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF LOWER(DB_NAME()) NOT IN (N'siiid2',N'siiid2_qa') THROW 52600, 'Seleccione la base SIIID2 de desarrollo o SIIID2_QA en la conexión.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin una transacción abierta.', 1;
DECLARE @Resultado TABLE (tabla SYSNAME NOT NULL, registros_eliminados BIGINT NOT NULL);
BEGIN TRY
 BEGIN TRANSACTION;
 DELETE FROM dbo.banci_historial_cambio WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_historial_cambio', @@ROWCOUNT);
 DELETE FROM dbo.banci_carga_tmp_victima WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_carga_tmp_victima', @@ROWCOUNT);
 DELETE FROM dbo.banci_carga_tmp_delito WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_carga_tmp_delito', @@ROWCOUNT);
 DELETE FROM dbo.banci_carga_tmp_carpeta WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_carga_tmp_carpeta', @@ROWCOUNT);
 DELETE FROM dbo.banci_carga_observacion WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_carga_observacion', @@ROWCOUNT);
 DELETE FROM dbo.banci_carga_archivo WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_carga_archivo', @@ROWCOUNT);
 DELETE FROM dbo.banci_carga_bitacora_estado WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_carga_bitacora_estado', @@ROWCOUNT);
 DELETE FROM dbo.banci_victima WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_victima', @@ROWCOUNT);
 DELETE FROM dbo.banci_delito WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_delito', @@ROWCOUNT);
 DELETE FROM dbo.banci_carpeta_investigacion WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_carpeta_investigacion', @@ROWCOUNT);
 DELETE FROM dbo.banci_actualizacion_v2 WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_actualizacion_v2', @@ROWCOUNT);
 DELETE FROM dbo.banci_carga WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_carga', @@ROWCOUNT);
 DELETE FROM dbo.banci_consecutivo_carpeta WITH (TABLOCKX);
 INSERT INTO @Resultado VALUES (N'banci_consecutivo_carpeta', @@ROWCOUNT);
 COMMIT TRANSACTION;
 SELECT DB_NAME() AS base_de_datos, tabla, registros_eliminados FROM @Resultado;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
