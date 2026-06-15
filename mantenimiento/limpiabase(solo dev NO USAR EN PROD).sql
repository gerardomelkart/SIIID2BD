USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @EjecutarLimpieza bit = 0;
-- 0 = simulación con ROLLBACK
-- 1 = ejecuta limpieza con COMMIT

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT 'CONTEOS ANTES';

    SELECT 'carga' tabla, COUNT(*) total FROM carga
    UNION ALL SELECT 'carga_tmp_carpeta', COUNT(*) FROM carga_tmp_carpeta
    UNION ALL SELECT 'carga_tmp_delito', COUNT(*) FROM carga_tmp_delito
    UNION ALL SELECT 'carga_tmp_victima', COUNT(*) FROM carga_tmp_victima
    UNION ALL SELECT 'carpeta_investigacion', COUNT(*) FROM carpeta_investigacion
    UNION ALL SELECT 'delito', COUNT(*) FROM delito
    UNION ALL SELECT 'victima', COUNT(*) FROM victima
    UNION ALL SELECT 'carpeta_investigacion_historico', COUNT(*) FROM carpeta_investigacion_historico
    UNION ALL SELECT 'delito_historico', COUNT(*) FROM delito_historico
    UNION ALL SELECT 'victima_historico', COUNT(*) FROM victima_historico
    UNION ALL SELECT 'habilita_carga_modificacion', COUNT(*) FROM habilita_carga_modificacion
    UNION ALL SELECT 'usuario', COUNT(*) FROM usuario;

    -- 1. Tablas que dependen de usuario/carga.
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

    -- 2. Configuración por usuario: conservar solo superusuario id 1.
    DELETE FROM habilita_carga_modificacion
    WHERE id_usuario <> 1;

    DELETE FROM usuario
    WHERE id_usuario <> 1;

    -- 3. Asegurar que superusuario quede activo.
    UPDATE usuario
    SET activo = 1
    WHERE id_usuario = 1;

    UPDATE habilita_carga_modificacion
    SET habilita_carga = 1,
        habilita_modificacion = 1,
        activo = 1
    WHERE id_usuario = 1;

    -- 4. Resetear identities operativas.
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

    -- No reseed de usuario si conservas id_usuario = 1.

    PRINT 'CONTEOS DESPUES';

    SELECT 'carga' tabla, COUNT(*) total FROM carga
    UNION ALL SELECT 'carga_tmp_carpeta', COUNT(*) FROM carga_tmp_carpeta
    UNION ALL SELECT 'carga_tmp_delito', COUNT(*) FROM carga_tmp_delito
    UNION ALL SELECT 'carga_tmp_victima', COUNT(*) FROM carga_tmp_victima
    UNION ALL SELECT 'carpeta_investigacion', COUNT(*) FROM carpeta_investigacion
    UNION ALL SELECT 'delito', COUNT(*) FROM delito
    UNION ALL SELECT 'victima', COUNT(*) FROM victima
    UNION ALL SELECT 'carpeta_investigacion_historico', COUNT(*) FROM carpeta_investigacion_historico
    UNION ALL SELECT 'delito_historico', COUNT(*) FROM delito_historico
    UNION ALL SELECT 'victima_historico', COUNT(*) FROM victima_historico
    UNION ALL SELECT 'habilita_carga_modificacion', COUNT(*) FROM habilita_carga_modificacion
    UNION ALL SELECT 'usuario', COUNT(*) FROM usuario;

    IF @EjecutarLimpieza = 1
    BEGIN
        COMMIT;
        PRINT 'LIMPIEZA CONFIRMADA.';
    END
    ELSE
    BEGIN
        ROLLBACK;
        PRINT 'SIMULACION. NO SE BORRO NADA.';
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;

    SELECT
        ERROR_NUMBER() AS numero_error,
        ERROR_MESSAGE() AS mensaje_error,
        ERROR_LINE() AS linea_error;

    THROW;
END CATCH;
GO