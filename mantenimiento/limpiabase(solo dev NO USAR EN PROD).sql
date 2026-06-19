USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @EjecutarLimpieza BIT = 0;
-- 0 = simulación con ROLLBACK
-- 1 = ejecuta limpieza con COMMIT

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT 'CONTEOS ANTES';

    SELECT 'carga' AS tabla, COUNT(*) AS total
    FROM dbo.carga

    UNION ALL
    SELECT 'carga_advertencia', COUNT(*)
    FROM dbo.carga_advertencia

    UNION ALL
    SELECT 'carga_bitacora_estado', COUNT(*)
    FROM dbo.carga_bitacora_estado

    UNION ALL
    SELECT 'carga_tmp_carpeta', COUNT(*)
    FROM dbo.carga_tmp_carpeta

    UNION ALL
    SELECT 'carga_tmp_delito', COUNT(*)
    FROM dbo.carga_tmp_delito

    UNION ALL
    SELECT 'carga_tmp_victima', COUNT(*)
    FROM dbo.carga_tmp_victima

    UNION ALL
    SELECT 'carpeta_investigacion', COUNT(*)
    FROM dbo.carpeta_investigacion

    UNION ALL
    SELECT 'delito', COUNT(*)
    FROM dbo.delito

    UNION ALL
    SELECT 'victima', COUNT(*)
    FROM dbo.victima

    UNION ALL
    SELECT 'carpeta_investigacion_historico', COUNT(*)
    FROM dbo.carpeta_investigacion_historico

    UNION ALL
    SELECT 'delito_historico', COUNT(*)
    FROM dbo.delito_historico

    UNION ALL
    SELECT 'victima_historico', COUNT(*)
    FROM dbo.victima_historico

    UNION ALL
    SELECT 'habilita_carga_modificacion', COUNT(*)
    FROM dbo.habilita_carga_modificacion

    UNION ALL
    SELECT 'usuario', COUNT(*)
    FROM dbo.usuario;


    -------------------------------------------------------------------------
    -- 1. Auditoría y flujo administrativo
    -------------------------------------------------------------------------

    /*
        Estas tablas dependen de carga y también pueden contener
        referencias hacia usuario.

        Deben limpiarse antes de eliminar cargas o usuarios.
    */

    DELETE FROM dbo.carga_bitacora_estado;
    DELETE FROM dbo.carga_advertencia;


    -------------------------------------------------------------------------
    -- 2. Información histórica
    -------------------------------------------------------------------------

    DELETE FROM dbo.victima_historico;
    DELETE FROM dbo.delito_historico;
    DELETE FROM dbo.carpeta_investigacion_historico;


    -------------------------------------------------------------------------
    -- 3. Información final
    -------------------------------------------------------------------------

    DELETE FROM dbo.victima;
    DELETE FROM dbo.delito;
    DELETE FROM dbo.carpeta_investigacion;


    -------------------------------------------------------------------------
    -- 4. Staging de procesos de carga y actualización
    -------------------------------------------------------------------------

    DELETE FROM dbo.carga_tmp_victima;
    DELETE FROM dbo.carga_tmp_delito;
    DELETE FROM dbo.carga_tmp_carpeta;


    -------------------------------------------------------------------------
    -- 5. Procesos de carga
    -------------------------------------------------------------------------

    DELETE FROM dbo.carga;


    -------------------------------------------------------------------------
    -- 6. Configuración y usuarios
    --    Conservar únicamente el superusuario id 1
    -------------------------------------------------------------------------

    DELETE FROM dbo.habilita_carga_modificacion
    WHERE id_usuario <> 1;

    /*
        Limpiar referencias autorreferenciadas antes de eliminar usuarios.

        Esto evita problemas si un usuario que será eliminado aparece como
        usuario de alta o usuario de modificación de otro registro.
    */

    UPDATE dbo.usuario
    SET id_usuario_alta = NULL
    WHERE id_usuario_alta IS NOT NULL
      AND id_usuario_alta <> 1;

    UPDATE dbo.usuario
    SET id_usuario_modificacion = NULL
    WHERE id_usuario_modificacion IS NOT NULL
      AND id_usuario_modificacion <> 1;

    DELETE FROM dbo.usuario
    WHERE id_usuario <> 1;


    -------------------------------------------------------------------------
    -- 7. Asegurar configuración del superusuario
    -------------------------------------------------------------------------

    UPDATE dbo.usuario
    SET activo = 1
    WHERE id_usuario = 1;

    UPDATE dbo.habilita_carga_modificacion
    SET habilita_carga = 1,
        habilita_modificacion = 1,
        activo = 1
    WHERE id_usuario = 1;


    -------------------------------------------------------------------------
    -- 8. Reiniciar identities operativas
    -------------------------------------------------------------------------

    DBCC CHECKIDENT
    (
        N'dbo.carga_bitacora_estado',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga_advertencia',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.victima_historico',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.delito_historico',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carpeta_investigacion_historico',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.victima',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.delito',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carpeta_investigacion',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga_tmp_victima',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga_tmp_delito',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga_tmp_carpeta',
        RESEED,
        0
    );

    DBCC CHECKIDENT
    (
        N'dbo.carga',
        RESEED,
        0
    );

    /*
        No se reinician los identities de usuario ni de
        habilita_carga_modificacion porque se conserva información.
    */


    PRINT 'CONTEOS DESPUES';

    SELECT 'carga' AS tabla, COUNT(*) AS total
    FROM dbo.carga

    UNION ALL
    SELECT 'carga_advertencia', COUNT(*)
    FROM dbo.carga_advertencia

    UNION ALL
    SELECT 'carga_bitacora_estado', COUNT(*)
    FROM dbo.carga_bitacora_estado

    UNION ALL
    SELECT 'carga_tmp_carpeta', COUNT(*)
    FROM dbo.carga_tmp_carpeta

    UNION ALL
    SELECT 'carga_tmp_delito', COUNT(*)
    FROM dbo.carga_tmp_delito

    UNION ALL
    SELECT 'carga_tmp_victima', COUNT(*)
    FROM dbo.carga_tmp_victima

    UNION ALL
    SELECT 'carpeta_investigacion', COUNT(*)
    FROM dbo.carpeta_investigacion

    UNION ALL
    SELECT 'delito', COUNT(*)
    FROM dbo.delito

    UNION ALL
    SELECT 'victima', COUNT(*)
    FROM dbo.victima

    UNION ALL
    SELECT 'carpeta_investigacion_historico', COUNT(*)
    FROM dbo.carpeta_investigacion_historico

    UNION ALL
    SELECT 'delito_historico', COUNT(*)
    FROM dbo.delito_historico

    UNION ALL
    SELECT 'victima_historico', COUNT(*)
    FROM dbo.victima_historico

    UNION ALL
    SELECT 'habilita_carga_modificacion', COUNT(*)
    FROM dbo.habilita_carga_modificacion

    UNION ALL
    SELECT 'usuario', COUNT(*)
    FROM dbo.usuario;


    IF @EjecutarLimpieza = 1
    BEGIN
        COMMIT TRANSACTION;

        PRINT 'LIMPIEZA DE DESARROLLO CONFIRMADA.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;

        PRINT 'SIMULACION. NO SE BORRO NADA.';
    END;
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