    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_carga_sabanas_anio_estado'
        AND object_id = OBJECT_ID('dbo.carga')
    )
    BEGIN
        CREATE INDEX IX_carga_sabanas_anio_estado
        ON dbo.carga (
            anio_corte,
            activo,
            tipo_carga,
            estado,
            id_carga
        )
        INCLUDE (
            mes_corte,
            id_entidad_federativa,
            fecha_confirmacion,
            fecha_validacion
        );
    END;
    GO

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_delito_sabanas_carga_activo'
        AND object_id = OBJECT_ID('dbo.delito')
    )
    BEGIN
        CREATE INDEX IX_delito_sabanas_carga_activo
        ON dbo.delito (
            id_carga,
            activo,
            id_modalidad_delito,
            id_grado_consumacion,
            id_instrumento_comision,
            id_forma_accion
        )
        INCLUDE (
            id_delito,
            id_entidad_federativa,
            id_municipio
        );
    END;
    GO

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_victima_sabanas_carga_activo_delito'
        AND object_id = OBJECT_ID('dbo.victima')
    )
    BEGIN
        CREATE INDEX IX_victima_sabanas_carga_activo_delito
        ON dbo.victima (
            id_carga,
            activo,
            id_delito
        )
        INCLUDE (
            id_tipo_victima,
            id_sexo,
            edad
        );
    END;
    GO

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_catalogo_delito_sabana_llaves'
        AND object_id = OBJECT_ID('dbo.catalogo_delito_sabana')
    )
    BEGIN
        CREATE INDEX IX_catalogo_delito_sabana_llaves
        ON dbo.catalogo_delito_sabana (
            activo,
            id_modalidad_delito,
            id_grado_consumacion,
            id_instrumento_comision,
            id_forma_accion
        )
        INCLUDE (
            id_delito_sabana,
            delito_sabana,
            subtipo_delito_sabana,
            modalidad_delito_sabana
        );
    END;
    GO

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE name = 'IX_catalogo_municipio_entidad_activo'
        AND object_id = OBJECT_ID('dbo.catalogo_municipio')
    )
    BEGIN
        CREATE INDEX IX_catalogo_municipio_entidad_activo
        ON dbo.catalogo_municipio (
            id_entidad_federativa,
            activo
        )
        INCLUDE (
            id_municipio,
            clave,
            nombre
        );
    END;
    GO