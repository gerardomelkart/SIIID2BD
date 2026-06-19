USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT 'CONTEOS ANTES DEL MANTENIMIENTO';

SELECT
    'carga_tmp_carpeta' AS tabla,
    COUNT(*) AS total,
    SUM
    (
        CASE
            WHEN c.estado IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    ) AS protegidos,
    SUM
    (
        CASE
            WHEN c.estado NOT IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    ) AS eliminables
FROM dbo.carga_tmp_carpeta tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga

UNION ALL

SELECT
    'carga_tmp_delito',
    COUNT(*),
    SUM
    (
        CASE
            WHEN c.estado IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    ),
    SUM
    (
        CASE
            WHEN c.estado NOT IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    )
FROM dbo.carga_tmp_delito tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga

UNION ALL

SELECT
    'carga_tmp_victima',
    COUNT(*),
    SUM
    (
        CASE
            WHEN c.estado IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    ),
    SUM
    (
        CASE
            WHEN c.estado NOT IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    )
FROM dbo.carga_tmp_victima tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga;
GO


DECLARE @VictimasEliminadas INT = 0;
DECLARE @DelitosEliminados INT = 0;
DECLARE @CarpetasEliminadas INT = 0;

BEGIN TRY
    BEGIN TRANSACTION;

    /*
        Se elimina staging únicamente cuando la carga ya no necesita
        una decisión del enlace estatal ni del administrador.

        Se deben conservar:
        - VALIDADO_PENDIENTE
        - VALIDADO_PENDIENTE_ACTUALIZACION
        - PENDIENTE_APROBACION
    */

    DELETE tmp
    FROM dbo.carga_tmp_victima tmp
    INNER JOIN dbo.carga c
        ON c.id_carga = tmp.id_carga
    WHERE c.estado NOT IN
    (
        N'VALIDADO_PENDIENTE',
        N'VALIDADO_PENDIENTE_ACTUALIZACION',
        N'PENDIENTE_APROBACION'
    );

    SET @VictimasEliminadas = @@ROWCOUNT;


    DELETE tmp
    FROM dbo.carga_tmp_delito tmp
    INNER JOIN dbo.carga c
        ON c.id_carga = tmp.id_carga
    WHERE c.estado NOT IN
    (
        N'VALIDADO_PENDIENTE',
        N'VALIDADO_PENDIENTE_ACTUALIZACION',
        N'PENDIENTE_APROBACION'
    );

    SET @DelitosEliminados = @@ROWCOUNT;


    DELETE tmp
    FROM dbo.carga_tmp_carpeta tmp
    INNER JOIN dbo.carga c
        ON c.id_carga = tmp.id_carga
    WHERE c.estado NOT IN
    (
        N'VALIDADO_PENDIENTE',
        N'VALIDADO_PENDIENTE_ACTUALIZACION',
        N'PENDIENTE_APROBACION'
    );

    SET @CarpetasEliminadas = @@ROWCOUNT;


    COMMIT TRANSACTION;

    PRINT 'Limpieza de staging terminada correctamente.';

    SELECT
        'carga_tmp_carpeta' AS tabla,
        @CarpetasEliminadas AS registros_eliminados

    UNION ALL

    SELECT
        'carga_tmp_delito',
        @DelitosEliminados

    UNION ALL

    SELECT
        'carga_tmp_victima',
        @VictimasEliminadas;
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


PRINT 'CONTEOS DESPUES DEL MANTENIMIENTO';

SELECT
    'carga_tmp_carpeta' AS tabla,
    COUNT(*) AS total,
    SUM
    (
        CASE
            WHEN c.estado IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    ) AS protegidos,
    SUM
    (
        CASE
            WHEN c.estado NOT IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    ) AS eliminables
FROM dbo.carga_tmp_carpeta tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga

UNION ALL

SELECT
    'carga_tmp_delito',
    COUNT(*),
    SUM
    (
        CASE
            WHEN c.estado IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    ),
    SUM
    (
        CASE
            WHEN c.estado NOT IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    )
FROM dbo.carga_tmp_delito tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga

UNION ALL

SELECT
    'carga_tmp_victima',
    COUNT(*),
    SUM
    (
        CASE
            WHEN c.estado IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    ),
    SUM
    (
        CASE
            WHEN c.estado NOT IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            THEN 1
            ELSE 0
        END
    )
FROM dbo.carga_tmp_victima tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga;
GO


UPDATE STATISTICS dbo.carga_tmp_carpeta WITH FULLSCAN;
UPDATE STATISTICS dbo.carga_tmp_delito WITH FULLSCAN;
UPDATE STATISTICS dbo.carga_tmp_victima WITH FULLSCAN;

UPDATE STATISTICS dbo.carga WITH FULLSCAN;
UPDATE STATISTICS dbo.carpeta_investigacion WITH FULLSCAN;
UPDATE STATISTICS dbo.delito WITH FULLSCAN;
UPDATE STATISTICS dbo.victima WITH FULLSCAN;

UPDATE STATISTICS dbo.carpeta_investigacion_historico WITH FULLSCAN;
UPDATE STATISTICS dbo.delito_historico WITH FULLSCAN;
UPDATE STATISTICS dbo.victima_historico WITH FULLSCAN;
GO