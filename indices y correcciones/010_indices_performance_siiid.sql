/* ============================================================
   SIIID2 - NORMALIZACION DE INDICES OPERATIVOS

   Ambiente destino:
   - Desarrollo
   - Produccion

   Destructivo:
   - NO elimina datos
   - SI elimina indices redundantes
   - SI crea/recrea indices operativos

   Nota:
   - Ejecutar despues de crear/restaurar estructura base.
   - No depende de datos.
   - No ejecutar junto con scripts de limpieza dev.
   ============================================================ */

USE siiid2;
GO

SET NOCOUNT ON;
GO


/* ============================================================
   NORMALIZACION DE INDICES OPERATIVOS - SIIID2

   Objetivo:
   - Eliminar indices duplicados o solapados.
   - Mantener indices utiles para validacion, diferencias,
     confirmacion, aprobacion administrativa, reportes
     y descarga ZIP.
   ============================================================ */


/* ============================================================
   1. CARGA
   ============================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carga_actualizacion_codigo_estado'
      AND object_id = OBJECT_ID(N'dbo.carga')
)
BEGIN
    DROP INDEX IX_carga_actualizacion_codigo_estado
    ON dbo.carga;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carga_periodo_confirmadas'
      AND object_id = OBJECT_ID(N'dbo.carga')
)
BEGIN
    DROP INDEX IX_carga_periodo_confirmadas
    ON dbo.carga;
END;
GO


/*
    Rehacer el indice de busqueda por codigo.

    Se utiliza para localizar una carga mediante codigo de referencia
    y validar que continúe activa.
*/

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carga_codigo_referencia_activo'
      AND object_id = OBJECT_ID(N'dbo.carga')
)
BEGIN
    DROP INDEX IX_carga_codigo_referencia_activo
    ON dbo.carga;
END;
GO


CREATE NONCLUSTERED INDEX IX_carga_codigo_referencia_activo
ON dbo.carga
(
    codigo_referencia,
    activo
)
INCLUDE
(
    id_carga,
    tipo_carga,
    estado,
    id_entidad_federativa,
    mes_corte,
    anio_corte,
    fecha_validacion,
    fecha_confirmacion,
    fecha_expiracion,
    id_usuario_carga,
    id_usuario_confirmacion
);
GO


/* ============================================================
   2. APROBACION ADMINISTRATIVA
   ============================================================ */

/*
    Indice filtrado para la bandeja administrativa.

    La API obtiene las cargas mediante:

        estado = 'PENDIENTE_APROBACION'
        activo = 1

    Y las ordena mediante:

        fecha_validacion
        id_carga

    Al ser filtrado, solamente almacena las cargas que están
    esperando resolución administrativa.
*/

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.carga')
      AND name = N'IX_carga_pendiente_aprobacion'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_carga_pendiente_aprobacion
    ON dbo.carga
    (
        fecha_validacion,
        id_carga
    )
    INCLUDE
    (
        codigo_referencia,
        tipo_carga,
        id_entidad_federativa,
        mes_corte,
        anio_corte,
        id_usuario_carga,
        total_carpetas_investigacion,
        total_delitos,
        total_victimas
    )
    WHERE estado = N'PENDIENTE_APROBACION'
      AND activo = 1;
END;
GO


/*
    Las siguientes tablas e indices son creados originalmente por:

        20260617_aprobacion_administrativa.sql

    Aquí se verifican para que el script de normalizacion pueda
    restaurarlos si alguno llegara a faltar.
*/


IF OBJECT_ID(N'dbo.carga_advertencia', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.carga_advertencia')
         AND name = N'IX_carga_advertencia_carga'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_carga_advertencia_carga
    ON dbo.carga_advertencia
    (
        id_carga,
        activo
    );
END;
GO


IF OBJECT_ID(N'dbo.carga_advertencia', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.carga_advertencia')
         AND name = N'IX_carga_advertencia_codigo'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_carga_advertencia_codigo
    ON dbo.carga_advertencia
    (
        codigo
    );
END;
GO


IF OBJECT_ID(N'dbo.carga_bitacora_estado', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.carga_bitacora_estado')
         AND name = N'IX_carga_bitacora_estado_carga_fecha'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_carga_bitacora_estado_carga_fecha
    ON dbo.carga_bitacora_estado
    (
        id_carga,
        fecha,
        id_carga_bitacora_estado
    );
END;
GO


IF OBJECT_ID(N'dbo.carga_bitacora_estado', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.carga_bitacora_estado')
         AND name = N'IX_carga_bitacora_estado_nuevo'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_carga_bitacora_estado_nuevo
    ON dbo.carga_bitacora_estado
    (
        estado_nuevo,
        fecha
    );
END;
GO


/* ============================================================
   3. TMP / STAGING
   ============================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carga_tmp_carpeta_diferencias'
      AND object_id = OBJECT_ID(N'dbo.carga_tmp_carpeta')
)
BEGIN
    DROP INDEX IX_carga_tmp_carpeta_diferencias
    ON dbo.carga_tmp_carpeta;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_tmp_carpeta_carga_idci_activo'
      AND object_id = OBJECT_ID(N'dbo.carga_tmp_carpeta')
)
BEGIN
    DROP INDEX IX_tmp_carpeta_carga_idci_activo
    ON dbo.carga_tmp_carpeta;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carga_tmp_delito_diferencias'
      AND object_id = OBJECT_ID(N'dbo.carga_tmp_delito')
)
BEGIN
    DROP INDEX IX_carga_tmp_delito_diferencias
    ON dbo.carga_tmp_delito;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_tmp_delito_carga_llave_activo'
      AND object_id = OBJECT_ID(N'dbo.carga_tmp_delito')
)
BEGIN
    DROP INDEX IX_tmp_delito_carga_llave_activo
    ON dbo.carga_tmp_delito;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carga_tmp_victima_diferencias'
      AND object_id = OBJECT_ID(N'dbo.carga_tmp_victima')
)
BEGIN
    DROP INDEX IX_carga_tmp_victima_diferencias
    ON dbo.carga_tmp_victima;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_tmp_victima_carga_llave_activo'
      AND object_id = OBJECT_ID(N'dbo.carga_tmp_victima')
)
BEGIN
    DROP INDEX IX_tmp_victima_carga_llave_activo
    ON dbo.carga_tmp_victima;
END;
GO


/*
    Se conservan los indices principales de staging creados por
    la estructura base:

    - IX_tmp_carpeta_carga_activo_idci
    - IX_tmp_delito_carga_activo_llave
    - IX_tmp_victima_carga_activo_llave
*/


/* ============================================================
   4. CARPETA_INVESTIGACION
   ============================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carpeta_carga_idci_activo'
      AND object_id = OBJECT_ID(N'dbo.carpeta_investigacion')
)
BEGIN
    DROP INDEX IX_carpeta_carga_idci_activo
    ON dbo.carpeta_investigacion;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carpeta_idci_activo'
      AND object_id = OBJECT_ID(N'dbo.carpeta_investigacion')
)
BEGIN
    DROP INDEX IX_carpeta_idci_activo
    ON dbo.carpeta_investigacion;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_carpeta_investigacion_diferencias'
      AND object_id = OBJECT_ID(N'dbo.carpeta_investigacion')
)
BEGIN
    DROP INDEX IX_carpeta_investigacion_diferencias
    ON dbo.carpeta_investigacion;
END;
GO


/*
    Se conservan:

    - IX_carpeta_carga_activo_identificador
    - IX_carpeta_identificador_activo_carga
*/


/* ============================================================
   5. DELITO
   ============================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_delito_carga_carpeta_identificador_activo'
      AND object_id = OBJECT_ID(N'dbo.delito')
)
BEGIN
    DROP INDEX IX_delito_carga_carpeta_identificador_activo
    ON dbo.delito;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_delito_diferencias'
      AND object_id = OBJECT_ID(N'dbo.delito')
)
BEGIN
    DROP INDEX IX_delito_diferencias
    ON dbo.delito;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_delito_id_activo_carga'
      AND object_id = OBJECT_ID(N'dbo.delito')
)
BEGIN
    DROP INDEX IX_delito_id_activo_carga
    ON dbo.delito;
END;
GO


/*
    Rehacer el indice inverso para que el nombre corresponda
    correctamente con las columnas utilizadas.
*/

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_delito_carpeta_identificador_activo'
      AND object_id = OBJECT_ID(N'dbo.delito')
)
BEGIN
    DROP INDEX IX_delito_carpeta_identificador_activo
    ON dbo.delito;
END;
GO


CREATE NONCLUSTERED INDEX IX_delito_carpeta_identificador_activo
ON dbo.delito
(
    id_carpeta_investigacion,
    identificador_delito_fiscalia,
    activo,
    id_carga
)
INCLUDE
(
    id_delito
);
GO


/*
    Se conserva además:

    - IX_delito_carga_activo_carpeta_identificador
*/


/* ============================================================
   6. VICTIMA
   ============================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_victima_carga_delito_identificador_activo'
      AND object_id = OBJECT_ID(N'dbo.victima')
)
BEGIN
    DROP INDEX IX_victima_carga_delito_identificador_activo
    ON dbo.victima;
END;
GO


IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_victima_diferencias'
      AND object_id = OBJECT_ID(N'dbo.victima')
)
BEGIN
    DROP INDEX IX_victima_diferencias
    ON dbo.victima;
END;
GO


/*
    Rehacer el indice inverso para que el nombre corresponda
    correctamente con las columnas utilizadas.
*/

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_victima_delito_identificador_activo'
      AND object_id = OBJECT_ID(N'dbo.victima')
)
BEGIN
    DROP INDEX IX_victima_delito_identificador_activo
    ON dbo.victima;
END;
GO


CREATE NONCLUSTERED INDEX IX_victima_delito_identificador_activo
ON dbo.victima
(
    id_delito,
    identificador_victima_fiscalia,
    activo,
    id_carga
)
INCLUDE
(
    id_victima
);
GO


/*
    Se conserva además:

    - IX_victima_carga_activo_delito_identificador
*/


/* ============================================================
   7. ACTUALIZAR ESTADISTICAS
   ============================================================ */

UPDATE STATISTICS dbo.carga;
UPDATE STATISTICS dbo.carga_tmp_carpeta;
UPDATE STATISTICS dbo.carga_tmp_delito;
UPDATE STATISTICS dbo.carga_tmp_victima;

UPDATE STATISTICS dbo.carpeta_investigacion;
UPDATE STATISTICS dbo.delito;
UPDATE STATISTICS dbo.victima;

UPDATE STATISTICS dbo.catalogo_municipio;
UPDATE STATISTICS dbo.catalogo_codigo_postal;
UPDATE STATISTICS dbo.catalogo_modalidad_delito;


IF OBJECT_ID(N'dbo.carga_advertencia', N'U') IS NOT NULL
BEGIN
    UPDATE STATISTICS dbo.carga_advertencia;
END;


IF OBJECT_ID(N'dbo.carga_bitacora_estado', N'U') IS NOT NULL
BEGIN
    UPDATE STATISTICS dbo.carga_bitacora_estado;
END;
GO


PRINT 'Normalizacion de indices y estadisticas terminada correctamente.';
GO
