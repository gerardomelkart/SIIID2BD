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
   - Eliminar índices duplicados/solapados.
   - Mantener índices útiles para validación, diferencias,
     confirmación, reportes y descarga ZIP.
   ============================================================ */


/* ============================================================
   1. CARGA
   ============================================================ */

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carga_actualizacion_codigo_estado' AND object_id = OBJECT_ID('dbo.carga'))
BEGIN
    DROP INDEX IX_carga_actualizacion_codigo_estado ON dbo.carga;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carga_periodo_confirmadas' AND object_id = OBJECT_ID('dbo.carga'))
BEGIN
    DROP INDEX IX_carga_periodo_confirmadas ON dbo.carga;
END
GO

-- Rehacer índice de búsqueda por código, porque el actual está nombrado como activo,
-- pero en tu inventario la llave aparece como codigo_referencia, tipo_carga.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carga_codigo_referencia_activo' AND object_id = OBJECT_ID('dbo.carga'))
BEGIN
    DROP INDEX IX_carga_codigo_referencia_activo ON dbo.carga;
END
GO

CREATE NONCLUSTERED INDEX IX_carga_codigo_referencia_activo
ON dbo.carga (
    codigo_referencia,
    activo
)
INCLUDE (
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
   2. TMP / STAGING
   ============================================================ */

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carga_tmp_carpeta_diferencias' AND object_id = OBJECT_ID('dbo.carga_tmp_carpeta'))
BEGIN
    DROP INDEX IX_carga_tmp_carpeta_diferencias ON dbo.carga_tmp_carpeta;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tmp_carpeta_carga_idci_activo' AND object_id = OBJECT_ID('dbo.carga_tmp_carpeta'))
BEGIN
    DROP INDEX IX_tmp_carpeta_carga_idci_activo ON dbo.carga_tmp_carpeta;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carga_tmp_delito_diferencias' AND object_id = OBJECT_ID('dbo.carga_tmp_delito'))
BEGIN
    DROP INDEX IX_carga_tmp_delito_diferencias ON dbo.carga_tmp_delito;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tmp_delito_carga_llave_activo' AND object_id = OBJECT_ID('dbo.carga_tmp_delito'))
BEGIN
    DROP INDEX IX_tmp_delito_carga_llave_activo ON dbo.carga_tmp_delito;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carga_tmp_victima_diferencias' AND object_id = OBJECT_ID('dbo.carga_tmp_victima'))
BEGIN
    DROP INDEX IX_carga_tmp_victima_diferencias ON dbo.carga_tmp_victima;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_tmp_victima_carga_llave_activo' AND object_id = OBJECT_ID('dbo.carga_tmp_victima'))
BEGIN
    DROP INDEX IX_tmp_victima_carga_llave_activo ON dbo.carga_tmp_victima;
END
GO


/* ============================================================
   3. CARPETA_INVESTIGACION
   ============================================================ */

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carpeta_carga_idci_activo' AND object_id = OBJECT_ID('dbo.carpeta_investigacion'))
BEGIN
    DROP INDEX IX_carpeta_carga_idci_activo ON dbo.carpeta_investigacion;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carpeta_idci_activo' AND object_id = OBJECT_ID('dbo.carpeta_investigacion'))
BEGIN
    DROP INDEX IX_carpeta_idci_activo ON dbo.carpeta_investigacion;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_carpeta_investigacion_diferencias' AND object_id = OBJECT_ID('dbo.carpeta_investigacion'))
BEGIN
    DROP INDEX IX_carpeta_investigacion_diferencias ON dbo.carpeta_investigacion;
END
GO

-- Nos quedamos con:
-- IX_carpeta_carga_activo_identificador
-- IX_carpeta_identificador_activo_carga


/* ============================================================
   4. DELITO
   ============================================================ */

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_delito_carga_carpeta_identificador_activo' AND object_id = OBJECT_ID('dbo.delito'))
BEGIN
    DROP INDEX IX_delito_carga_carpeta_identificador_activo ON dbo.delito;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_delito_diferencias' AND object_id = OBJECT_ID('dbo.delito'))
BEGIN
    DROP INDEX IX_delito_diferencias ON dbo.delito;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_delito_id_activo_carga' AND object_id = OBJECT_ID('dbo.delito'))
BEGIN
    DROP INDEX IX_delito_id_activo_carga ON dbo.delito;
END
GO

-- Rehacer índice inverso para que el nombre sí corresponda con la llave.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_delito_carpeta_identificador_activo' AND object_id = OBJECT_ID('dbo.delito'))
BEGIN
    DROP INDEX IX_delito_carpeta_identificador_activo ON dbo.delito;
END
GO

CREATE NONCLUSTERED INDEX IX_delito_carpeta_identificador_activo
ON dbo.delito (
    id_carpeta_investigacion,
    identificador_delito_fiscalia,
    activo,
    id_carga
)
INCLUDE (
    id_delito
);
GO

-- Nos quedamos además con:
-- IX_delito_carga_activo_carpeta_identificador


/* ============================================================
   5. VICTIMA
   ============================================================ */

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_victima_carga_delito_identificador_activo' AND object_id = OBJECT_ID('dbo.victima'))
BEGIN
    DROP INDEX IX_victima_carga_delito_identificador_activo ON dbo.victima;
END
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_victima_diferencias' AND object_id = OBJECT_ID('dbo.victima'))
BEGIN
    DROP INDEX IX_victima_diferencias ON dbo.victima;
END
GO

-- Rehacer índice inverso para que el nombre sí corresponda con la llave.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_victima_delito_identificador_activo' AND object_id = OBJECT_ID('dbo.victima'))
BEGIN
    DROP INDEX IX_victima_delito_identificador_activo ON dbo.victima;
END
GO

CREATE NONCLUSTERED INDEX IX_victima_delito_identificador_activo
ON dbo.victima (
    id_delito,
    identificador_victima_fiscalia,
    activo,
    id_carga
)
INCLUDE (
    id_victima
);
GO

-- Nos quedamos además con:
-- IX_victima_carga_activo_delito_identificador


/* ============================================================
   6. ACTUALIZAR ESTADISTICAS
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
GO