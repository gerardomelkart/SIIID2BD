/* ============================================================
   Índices de performance SIIID2
   Objetivo:
   - acelerar cargas, actualizaciones, diferencias e informes
   - soportar búsquedas por codigo_referencia
   - soportar búsquedas por entidad / periodo / estado
   - soportar joins contra staging y tablas finales
   ============================================================ */

SET NOCOUNT ON;
GO

/* ============================================================
   TABLA: carga
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_carga_codigo_referencia_activo'
      AND object_id = OBJECT_ID('dbo.carga')
)
BEGIN
    CREATE INDEX IX_carga_codigo_referencia_activo
    ON dbo.carga (
        codigo_referencia,
        tipo_carga
    )
    INCLUDE (
        id_carga,
        id_entidad_federativa,
        estado,
        mes_corte,
        anio_corte,
        fecha_validacion,
        fecha_confirmacion,
        fecha_expiracion,
        id_usuario_carga,
        id_usuario_confirmacion
    )
    WHERE activo = 1;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_carga_periodo_estado_activo'
      AND object_id = OBJECT_ID('dbo.carga')
)
BEGIN
    CREATE INDEX IX_carga_periodo_estado_activo
    ON dbo.carga (
        id_entidad_federativa,
        mes_corte,
        anio_corte,
        estado,
        tipo_carga,
        fecha_confirmacion,
        id_carga
    )
    INCLUDE (
        codigo_referencia,
        fecha_validacion,
        fecha_expiracion,
        id_usuario_carga,
        id_usuario_confirmacion
    )
    WHERE activo = 1;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_carga_periodo_pendiente_activo'
      AND object_id = OBJECT_ID('dbo.carga')
)
BEGIN
    CREATE INDEX IX_carga_periodo_pendiente_activo
    ON dbo.carga (
        id_entidad_federativa,
        mes_corte,
        anio_corte,
        tipo_carga,
        estado,
        fecha_validacion
    )
    INCLUDE (
        id_carga,
        codigo_referencia
    )
    WHERE activo = 1;
END
GO

/* ============================================================
   TABLA: carga_tmp_carpeta
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_tmp_carpeta_carga_idci_activo'
      AND object_id = OBJECT_ID('dbo.carga_tmp_carpeta')
)
BEGIN
    CREATE INDEX IX_tmp_carpeta_carga_idci_activo
    ON dbo.carga_tmp_carpeta (
        id_carga,
        id_ci
    )
    INCLUDE (
        ntra_ci,
        fha_de_ini,
        estado
    )
    WHERE activo = 1;
END
GO

/* ============================================================
   TABLA: carga_tmp_delito
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_tmp_delito_carga_llave_activo'
      AND object_id = OBJECT_ID('dbo.carga_tmp_delito')
)
BEGIN
    CREATE INDEX IX_tmp_delito_carga_llave_activo
    ON dbo.carga_tmp_delito (
        id_carga,
        id_ci,
        id_delito
    )
    INCLUDE (
        clasf_de_dto,
        forma_acc,
        emto_com_dto,
        grdo_cons,
        id_ent_hchos,
        id_mun_hchos,
        cp,
        estado
    )
    WHERE activo = 1;
END
GO

/* ============================================================
   TABLA: carga_tmp_victima
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_tmp_victima_carga_llave_activo'
      AND object_id = OBJECT_ID('dbo.carga_tmp_victima')
)
BEGIN
    CREATE INDEX IX_tmp_victima_carga_llave_activo
    ON dbo.carga_tmp_victima (
        id_carga,
        id_ci,
        id_delito,
        id_vicf
    )
    INCLUDE (
        id_tv,
        id_tpm,
        sexo,
        genero,
        pob,
        disc,
        nacional,
        estado
    )
    WHERE activo = 1;
END
GO

/* ============================================================
   TABLA: carpeta_investigacion
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_carpeta_carga_idci_activo'
      AND object_id = OBJECT_ID('dbo.carpeta_investigacion')
)
BEGIN
    CREATE INDEX IX_carpeta_carga_idci_activo
    ON dbo.carpeta_investigacion (
        id_carga,
        identificador_carpeta_fiscalia
    )
    INCLUDE (
        id_carpeta_investigacion,
        nomenclatura_carpeta_fiscalia,
        fecha_inicio
    )
    WHERE activo = 1;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_carpeta_idci_activo'
      AND object_id = OBJECT_ID('dbo.carpeta_investigacion')
)
BEGIN
    CREATE INDEX IX_carpeta_idci_activo
    ON dbo.carpeta_investigacion (
        identificador_carpeta_fiscalia,
        id_carga
    )
    INCLUDE (
        id_carpeta_investigacion,
        fecha_inicio
    )
    WHERE activo = 1;
END
GO

/* ============================================================
   TABLA: delito
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_delito_carga_carpeta_identificador_activo'
      AND object_id = OBJECT_ID('dbo.delito')
)
BEGIN
    CREATE INDEX IX_delito_carga_carpeta_identificador_activo
    ON dbo.delito (
        id_carga,
        id_carpeta_investigacion,
        identificador_delito_fiscalia
    )
    INCLUDE (
        id_delito,
        id_forma_accion,
        fecha_hechos,
        id_instrumento_comision,
        id_grado_consumacion,
        id_modalidad_delito,
        id_entidad_federativa,
        id_municipio,
        id_codigo_postal
    )
    WHERE activo = 1;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_delito_carpeta_identificador_activo'
      AND object_id = OBJECT_ID('dbo.delito')
)
BEGIN
    CREATE INDEX IX_delito_carpeta_identificador_activo
    ON dbo.delito (
        id_carpeta_investigacion,
        identificador_delito_fiscalia
    )
    INCLUDE (
        id_delito,
        id_carga
    )
    WHERE activo = 1;
END
GO

/* ============================================================
   TABLA: victima
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_victima_carga_delito_identificador_activo'
      AND object_id = OBJECT_ID('dbo.victima')
)
BEGIN
    CREATE INDEX IX_victima_carga_delito_identificador_activo
    ON dbo.victima (
        id_carga,
        id_delito,
        identificador_victima_fiscalia
    )
    INCLUDE (
        id_victima,
        id_tipo_victima,
        id_tipo_victima_moral,
        id_sexo,
        id_genero,
        id_nacionalidad,
        id_pertenece_poblacion_indigena,
        id_presenta_discapacidad,
        fecha_nacimiento,
        edad
    )
    WHERE activo = 1;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_victima_delito_identificador_activo'
      AND object_id = OBJECT_ID('dbo.victima')
)
BEGIN
    CREATE INDEX IX_victima_delito_identificador_activo
    ON dbo.victima (
        id_delito,
        identificador_victima_fiscalia
    )
    INCLUDE (
        id_victima,
        id_carga
    )
    WHERE activo = 1;
END
GO

/* ============================================================
   CATÁLOGOS usados en joins de carga/actualización
   ============================================================ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_catalogo_municipio_entidad_clave_activo'
      AND object_id = OBJECT_ID('dbo.catalogo_municipio')
)
BEGIN
    CREATE INDEX IX_catalogo_municipio_entidad_clave_activo
    ON dbo.catalogo_municipio (
        id_entidad_federativa,
        clave
    )
    INCLUDE (
        id_municipio
    )
    WHERE activo = 1;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_catalogo_codigo_postal_cp_municipio_activo'
      AND object_id = OBJECT_ID('dbo.catalogo_codigo_postal')
)
BEGIN
    CREATE INDEX IX_catalogo_codigo_postal_cp_municipio_activo
    ON dbo.catalogo_codigo_postal (
        codigo_postal,
        id_municipio
    )
    INCLUDE (
        id_codigo_postal
    )
    WHERE activo = 1;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_catalogo_modalidad_delito_clave4_activo'
      AND object_id = OBJECT_ID('dbo.catalogo_modalidad_delito')
)
BEGIN
    CREATE INDEX IX_catalogo_modalidad_delito_clave4_activo
    ON dbo.catalogo_modalidad_delito (
        clave4
    )
    INCLUDE (
        id_modalidad_delito
    )
    WHERE activo = 1;
END
GO

/* ============================================================
   Estadísticas
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