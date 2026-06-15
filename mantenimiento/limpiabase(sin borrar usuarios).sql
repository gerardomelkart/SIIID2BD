USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @EjecutarLimpieza bit = 0;
-- 0 = simulación con ROLLBACK
-- 1 = ejecuta limpieza con COMMIT

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT 'carga' tabla, COUNT(*) total FROM carga
    UNION ALL SELECT 'carga_tmp_carpeta', COUNT(*) FROM carga_tmp_carpeta
    UNION ALL SELECT 'carga_tmp_delito', COUNT(*) FROM carga_tmp_delito
    UNION ALL SELECT 'carga_tmp_victima', COUNT(*) FROM carga_tmp_victima
    UNION ALL SELECT 'carpeta_investigacion', COUNT(*) FROM carpeta_investigacion
    UNION ALL SELECT 'delito', COUNT(*) FROM delito
    UNION ALL SELECT 'victima', COUNT(*) FROM victima
    UNION ALL SELECT 'carpeta_investigacion_historico', COUNT(*) FROM carpeta_investigacion_historico
    UNION ALL SELECT 'delito_historico', COUNT(*) FROM delito_historico
    UNION ALL SELECT 'victima_historico', COUNT(*) FROM victima_historico;

    DELETE FROM victima_historico;
    DELETE FROM delito_historico;
    DELETE FROM carpeta_investigacion_historico;

    DELETE FROM victima;
    DELETE FROM delito;
    DELETE FROM carpeta_investigacion;

    DELETE FROM carga_tmp_victima;
    DELETE FROM carga_tmp_delito;
    DELETE FROM carga_tmp_carpeta;

    DELETE FROM carga;

    DBCC CHECKIDENT ('victima_historico', RESEED, 0);
    DBCC CHECKIDENT ('delito_historico', RESEED, 0);
    DBCC CHECKIDENT ('carpeta_investigacion_historico', RESEED, 0);

    DBCC CHECKIDENT ('victima', RESEED, 0);
    DBCC CHECKIDENT ('delito', RESEED, 0);
    DBCC CHECKIDENT ('carpeta_investigacion', RESEED, 0);

    DBCC CHECKIDENT ('carga_tmp_victima', RESEED, 0);
    DBCC CHECKIDENT ('carga_tmp_delito', RESEED, 0);
    DBCC CHECKIDENT ('carga_tmp_carpeta', RESEED, 0);

    DBCC CHECKIDENT ('carga', RESEED, 0);

    SELECT 'carga' tabla, COUNT(*) total FROM carga
    UNION ALL SELECT 'carga_tmp_carpeta', COUNT(*) FROM carga_tmp_carpeta
    UNION ALL SELECT 'carga_tmp_delito', COUNT(*) FROM carga_tmp_delito
    UNION ALL SELECT 'carga_tmp_victima', COUNT(*) FROM carga_tmp_victima
    UNION ALL SELECT 'carpeta_investigacion', COUNT(*) FROM carpeta_investigacion
    UNION ALL SELECT 'delito', COUNT(*) FROM delito
    UNION ALL SELECT 'victima', COUNT(*) FROM victima
    UNION ALL SELECT 'carpeta_investigacion_historico', COUNT(*) FROM carpeta_investigacion_historico
    UNION ALL SELECT 'delito_historico', COUNT(*) FROM delito_historico
    UNION ALL SELECT 'victima_historico', COUNT(*) FROM victima_historico;

    IF @EjecutarLimpieza = 1
        COMMIT;
    ELSE
        ROLLBACK;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH;
GO