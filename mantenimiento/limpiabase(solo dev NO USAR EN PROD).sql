USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @EjecutarLimpieza bit = 0;
-- 0 = solo muestra conteos y hace ROLLBACK
-- 1 = limpia y hace COMMIT

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT '==============================';
    PRINT 'CONTEOS ANTES DE LIMPIAR';
    PRINT '==============================';

    SELECT 'carga' AS tabla, COUNT(1) AS total FROM carga
    UNION ALL SELECT 'carga_tmp_carpeta', COUNT(1) FROM carga_tmp_carpeta
    UNION ALL SELECT 'carga_tmp_delito', COUNT(1) FROM carga_tmp_delito
    UNION ALL SELECT 'carga_tmp_victima', COUNT(1) FROM carga_tmp_victima
    UNION ALL SELECT 'carpeta_investigacion', COUNT(1) FROM carpeta_investigacion
    UNION ALL SELECT 'delito', COUNT(1) FROM delito
    UNION ALL SELECT 'victima', COUNT(1) FROM victima
    UNION ALL SELECT 'carpeta_investigacion_historico', COUNT(1) FROM carpeta_investigacion_historico
    UNION ALL SELECT 'delito_historico', COUNT(1) FROM delito_historico
    UNION ALL SELECT 'victima_historico', COUNT(1) FROM victima_historico;

    PRINT '==============================';
    PRINT 'LIMPIANDO DATOS OPERATIVOS';
    PRINT '==============================';

    -- 1. Históricos primero, porque pueden referenciar tablas finales.
    DELETE FROM victima_historico;
    DELETE FROM delito_historico;
    DELETE FROM carpeta_investigacion_historico;

    -- 2. Tablas finales en orden hijo -> padre.
    DELETE FROM victima;
    DELETE FROM delito;
    DELETE FROM carpeta_investigacion;

    -- 3. Temporales/staging.
    DELETE FROM carga_tmp_victima;
    DELETE FROM carga_tmp_delito;
    DELETE FROM carga_tmp_carpeta;

    -- 4. Cabecera de carga al final.
    DELETE FROM carga;

    PRINT '==============================';
    PRINT 'RESETEANDO IDENTITIES';
    PRINT '==============================';

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('victima_historico'))
        DBCC CHECKIDENT ('victima_historico', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('delito_historico'))
        DBCC CHECKIDENT ('delito_historico', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('carpeta_investigacion_historico'))
        DBCC CHECKIDENT ('carpeta_investigacion_historico', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('victima'))
        DBCC CHECKIDENT ('victima', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('delito'))
        DBCC CHECKIDENT ('delito', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('carpeta_investigacion'))
        DBCC CHECKIDENT ('carpeta_investigacion', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('carga_tmp_victima'))
        DBCC CHECKIDENT ('carga_tmp_victima', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('carga_tmp_delito'))
        DBCC CHECKIDENT ('carga_tmp_delito', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('carga_tmp_carpeta'))
        DBCC CHECKIDENT ('carga_tmp_carpeta', RESEED, 0);

    IF EXISTS (SELECT 1 FROM sys.identity_columns WHERE object_id = OBJECT_ID('carga'))
        DBCC CHECKIDENT ('carga', RESEED, 0);

    PRINT '==============================';
    PRINT 'CONTEOS DESPUES DE LIMPIAR';
    PRINT '==============================';

    SELECT 'carga' AS tabla, COUNT(1) AS total FROM carga
    UNION ALL SELECT 'carga_tmp_carpeta', COUNT(1) FROM carga_tmp_carpeta
    UNION ALL SELECT 'carga_tmp_delito', COUNT(1) FROM carga_tmp_delito
    UNION ALL SELECT 'carga_tmp_victima', COUNT(1) FROM carga_tmp_victima
    UNION ALL SELECT 'carpeta_investigacion', COUNT(1) FROM carpeta_investigacion
    UNION ALL SELECT 'delito', COUNT(1) FROM delito
    UNION ALL SELECT 'victima', COUNT(1) FROM victima
    UNION ALL SELECT 'carpeta_investigacion_historico', COUNT(1) FROM carpeta_investigacion_historico
    UNION ALL SELECT 'delito_historico', COUNT(1) FROM delito_historico
    UNION ALL SELECT 'victima_historico', COUNT(1) FROM victima_historico;

    IF @EjecutarLimpieza = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'LIMPIEZA CONFIRMADA CON COMMIT.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'SIMULACION TERMINADA. NO SE BORRO NADA. Cambia @EjecutarLimpieza = 1 para ejecutar.';
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        ERROR_NUMBER() AS numero_error,
        ERROR_MESSAGE() AS mensaje_error,
        ERROR_LINE() AS linea_error;

    THROW;
END CATCH;
GO