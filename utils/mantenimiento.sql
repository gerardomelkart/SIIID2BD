USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;


/*
    ============================================================
    CARGAS CUYO STAGING DEBE CONSERVARSE
    ============================================================

    Siempre se conservan:
    - VALIDADO_PENDIENTE
    - VALIDADO_PENDIENTE_ACTUALIZACION
    - PENDIENTE_APROBACION

    RECHAZADO_ADMIN se conserva solamente cuando NO existe
    un intento posterior relevante de la misma carga lógica:

    - misma entidad federativa
    - mismo mes de corte
    - mismo año de corte
    - mismo tipo de carga

    Un intento posterior relevante puede estar en:
    - VALIDADO_PENDIENTE
    - VALIDADO_PENDIENTE_ACTUALIZACION
    - PENDIENTE_APROBACION
    - RECHAZADO_ADMIN
    - CONFIRMADO
    - CONFIRMADO_ACTUALIZACION

    Ejemplos:

    Rechazo 100
    Rechazo 101
    => 100 eliminable
    => 101 protegido

    Rechazo 100
    Pendiente 101
    => 100 eliminable
    => 101 protegido

    Rechazo 100
    Confirmado 101
    => 100 eliminable
    => 101 sigue flujo normal de mantenimiento
*/


IF OBJECT_ID('tempdb..#CargasStagingProtegidas') IS NOT NULL
BEGIN
    DROP TABLE #CargasStagingProtegidas;
END;


CREATE TABLE #CargasStagingProtegidas
(
    id_carga BIGINT NOT NULL PRIMARY KEY,
    motivo_proteccion NVARCHAR(100) NOT NULL
);


/*
    1. Cargas pendientes.

    Se conserva el comportamiento actual:
    su staging todavía es necesario para continuar el flujo.
*/

INSERT INTO #CargasStagingProtegidas
(
    id_carga,
    motivo_proteccion
)
SELECT
    c.id_carga,
    N'CARGA_PENDIENTE'
FROM dbo.carga c
WHERE c.estado IN
(
    N'VALIDADO_PENDIENTE',
    N'VALIDADO_PENDIENTE_ACTUALIZACION',
    N'PENDIENTE_APROBACION'
);


/*
    2. Rechazos administrativos vigentes.

    Se conserva un RECHAZADO_ADMIN únicamente mientras no exista
    un intento posterior relevante de la misma:

    - entidad
    - mes
    - año
    - tipo de carga

    id_carga se usa como desempate y secuencia de intentos:
    un intento posterior tiene un id_carga mayor.
*/

INSERT INTO #CargasStagingProtegidas
(
    id_carga,
    motivo_proteccion
)
SELECT
    c.id_carga,
    N'ULTIMO_RECHAZO_ADMIN_VIGENTE'
FROM dbo.carga c
WHERE c.estado = N'RECHAZADO_ADMIN'
  AND c.activo = 1
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.carga c2
      WHERE ISNULL(c2.id_entidad_federativa, 0)
                = ISNULL(c.id_entidad_federativa, 0)

        AND c2.mes_corte = c.mes_corte
        AND c2.anio_corte = c.anio_corte

        AND ISNULL(c2.tipo_carga, N'')
                = ISNULL(c.tipo_carga, N'')

        AND c2.activo = 1
        AND c2.id_carga > c.id_carga

        AND c2.estado IN
        (
            N'VALIDADO_PENDIENTE',
            N'VALIDADO_PENDIENTE_ACTUALIZACION',
            N'PENDIENTE_APROBACION',
            N'RECHAZADO_ADMIN',
            N'CONFIRMADO',
            N'CONFIRMADO_ACTUALIZACION'
        )
  );


/*
    ============================================================
    DIAGNÓSTICO DE RECHAZOS ADMINISTRATIVOS
    ============================================================

    Antes de borrar, muestra cuáles rechazos quedan protegidos
    y cuáles ya fueron superados por un intento posterior.
*/

PRINT 'ESTADO DE RECHAZOS ADMINISTRATIVOS';

SELECT
    c.id_carga,
    c.codigo_referencia,
    c.id_entidad_federativa,
    c.mes_corte,
    c.anio_corte,
    c.tipo_carga,
    c.estado,
    c.fecha_validacion,
    c.fecha_confirmacion AS fecha_rechazo,
    CASE
        WHEN protegida.id_carga IS NOT NULL
            THEN N'PROTEGIDO'
        ELSE N'ELIMINABLE'
    END AS estado_staging,
    protegida.motivo_proteccion
FROM dbo.carga c
LEFT JOIN #CargasStagingProtegidas protegida
    ON protegida.id_carga = c.id_carga
WHERE c.estado = N'RECHAZADO_ADMIN'
ORDER BY
    c.id_entidad_federativa,
    c.anio_corte,
    c.mes_corte,
    c.tipo_carga,
    c.id_carga;
    

/*
    ============================================================
    CONTEOS ANTES DEL MANTENIMIENTO
    ============================================================
*/

PRINT 'CONTEOS ANTES DEL MANTENIMIENTO';

SELECT
    'carga_tmp_carpeta' AS tabla,
    COUNT(*) AS total,
    COUNT(protegida.id_carga) AS protegidos,
    COUNT(*) - COUNT(protegida.id_carga) AS eliminables
FROM dbo.carga_tmp_carpeta tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga
LEFT JOIN #CargasStagingProtegidas protegida
    ON protegida.id_carga = tmp.id_carga

UNION ALL

SELECT
    'carga_tmp_delito',
    COUNT(*),
    COUNT(protegida.id_carga),
    COUNT(*) - COUNT(protegida.id_carga)
FROM dbo.carga_tmp_delito tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga
LEFT JOIN #CargasStagingProtegidas protegida
    ON protegida.id_carga = tmp.id_carga

UNION ALL

SELECT
    'carga_tmp_victima',
    COUNT(*),
    COUNT(protegida.id_carga),
    COUNT(*) - COUNT(protegida.id_carga)
FROM dbo.carga_tmp_victima tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga
LEFT JOIN #CargasStagingProtegidas protegida
    ON protegida.id_carga = tmp.id_carga;


/*
    ============================================================
    EJECUCIÓN DEL MANTENIMIENTO
    ============================================================

    IMPORTANTE:

    Primera prueba:
        @EjecutarMantenimiento = 0

    Cuando los diagnósticos sean correctos:
        @EjecutarMantenimiento = 1
*/

DECLARE @EjecutarMantenimiento BIT = 1;
-- 0 = simulación con ROLLBACK
-- 1 = ejecuta mantenimiento con COMMIT

DECLARE @VictimasEliminadas INT = 0;
DECLARE @DelitosEliminados INT = 0;
DECLARE @CarpetasEliminadas INT = 0;


BEGIN TRY

    BEGIN TRANSACTION;


    /*
        Primero víctimas por dependencia lógica.
    */

    DELETE tmp
    FROM dbo.carga_tmp_victima tmp
    INNER JOIN dbo.carga c
        ON c.id_carga = tmp.id_carga
    LEFT JOIN #CargasStagingProtegidas protegida
        ON protegida.id_carga = tmp.id_carga
    WHERE protegida.id_carga IS NULL;

    SET @VictimasEliminadas = @@ROWCOUNT;


    /*
        Después delitos.
    */

    DELETE tmp
    FROM dbo.carga_tmp_delito tmp
    INNER JOIN dbo.carga c
        ON c.id_carga = tmp.id_carga
    LEFT JOIN #CargasStagingProtegidas protegida
        ON protegida.id_carga = tmp.id_carga
    WHERE protegida.id_carga IS NULL;

    SET @DelitosEliminados = @@ROWCOUNT;


    /*
        Finalmente carpetas.
    */

    DELETE tmp
    FROM dbo.carga_tmp_carpeta tmp
    INNER JOIN dbo.carga c
        ON c.id_carga = tmp.id_carga
    LEFT JOIN #CargasStagingProtegidas protegida
        ON protegida.id_carga = tmp.id_carga
    WHERE protegida.id_carga IS NULL;

    SET @CarpetasEliminadas = @@ROWCOUNT;


    IF @EjecutarMantenimiento = 1
    BEGIN
        COMMIT TRANSACTION;

        PRINT 'MANTENIMIENTO CONFIRMADO. Limpieza de staging aplicada correctamente.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;

        PRINT 'SIMULACION. NO SE BORRO NADA.';
    END;


    /*
        Aunque se ejecute en simulación, estos valores indican
        cuántos registros habría eliminado el mantenimiento.
    */

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
    BEGIN
        ROLLBACK TRANSACTION;
    END;


    SELECT
        ERROR_NUMBER() AS numero_error,
        ERROR_MESSAGE() AS mensaje_error,
        ERROR_LINE() AS linea_error;

    THROW;

END CATCH;


/*
    ============================================================
    CONTEOS DESPUÉS DEL MANTENIMIENTO
    ============================================================

    En simulación serán iguales a los conteos iniciales porque
    la transacción se revierte.

    Con COMMIT mostrarán solamente el staging conservado.
*/

PRINT 'CONTEOS DESPUES DEL MANTENIMIENTO';

SELECT
    'carga_tmp_carpeta' AS tabla,
    COUNT(*) AS total,
    COUNT(protegida.id_carga) AS protegidos,
    COUNT(*) - COUNT(protegida.id_carga) AS eliminables
FROM dbo.carga_tmp_carpeta tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga
LEFT JOIN #CargasStagingProtegidas protegida
    ON protegida.id_carga = tmp.id_carga

UNION ALL

SELECT
    'carga_tmp_delito',
    COUNT(*),
    COUNT(protegida.id_carga),
    COUNT(*) - COUNT(protegida.id_carga)
FROM dbo.carga_tmp_delito tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga
LEFT JOIN #CargasStagingProtegidas protegida
    ON protegida.id_carga = tmp.id_carga

UNION ALL

SELECT
    'carga_tmp_victima',
    COUNT(*),
    COUNT(protegida.id_carga),
    COUNT(*) - COUNT(protegida.id_carga)
FROM dbo.carga_tmp_victima tmp
INNER JOIN dbo.carga c
    ON c.id_carga = tmp.id_carga
LEFT JOIN #CargasStagingProtegidas protegida
    ON protegida.id_carga = tmp.id_carga;


/*
    Tabla auxiliar temporal.
*/

DROP TABLE #CargasStagingProtegidas;

GO


/*
    ============================================================
    ACTUALIZACIÓN OPCIONAL DE ESTADÍSTICAS
    ============================================================

    OJO:
    UPDATE STATISTICS WITH FULLSCAN puede tardar en tablas grandes.

    Ejecutar fuera de horario operativo si la base ya tiene
    volumen real.
*/


DECLARE @ActualizarEstadisticas BIT = 1;
-- 0 = no actualiza estadísticas
-- 1 = actualiza estadísticas con FULLSCAN


IF @ActualizarEstadisticas = 1
BEGIN

    PRINT 'Actualizando estadísticas con FULLSCAN...';


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


    PRINT 'Estadísticas actualizadas correctamente.';

END
ELSE
BEGIN

    PRINT 'No se actualizaron estadísticas. @ActualizarEstadisticas = 0.';

END;

GO