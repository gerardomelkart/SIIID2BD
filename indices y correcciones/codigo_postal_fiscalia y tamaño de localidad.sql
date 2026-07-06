USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.delito', 'codigo_postal_fiscalia') IS NULL
BEGIN
    ALTER TABLE dbo.delito
    ADD codigo_postal_fiscalia NVARCHAR(50) NULL;
END;
GO

IF COL_LENGTH('dbo.delito_historico', 'codigo_postal_fiscalia') IS NULL
BEGIN
    ALTER TABLE dbo.delito_historico
    ADD codigo_postal_fiscalia NVARCHAR(50) NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_delito_codigo_postal_fiscalia
ON dbo.delito
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted) AND UPDATE(codigo_postal_fiscalia)
    BEGIN
        RETURN;
    END;

    UPDATE de
    SET de.codigo_postal_fiscalia = origen.codigo_postal_fiscalia
    FROM dbo.delito de
    INNER JOIN inserted i
        ON i.id_delito = de.id_delito
    INNER JOIN dbo.carpeta_investigacion ci
        ON ci.id_carpeta_investigacion = de.id_carpeta_investigacion
    CROSS APPLY
    (
        SELECT TOP 1
            NULLIF(LTRIM(RTRIM(tmp.cp)), N'') AS codigo_postal_fiscalia
        FROM dbo.carga_tmp_delito tmp
        WHERE tmp.id_carga = de.id_carga
          AND tmp.id_ci = ci.identificador_carpeta_fiscalia
          AND tmp.id_delito = de.identificador_delito_fiscalia
    ) origen
    WHERE ISNULL(de.codigo_postal_fiscalia, N'') <> ISNULL(origen.codigo_postal_fiscalia, N'');
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_delito_historico_codigo_postal_fiscalia
ON dbo.delito_historico
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dh
    SET dh.codigo_postal_fiscalia = de.codigo_postal_fiscalia
    FROM dbo.delito_historico dh
    INNER JOIN inserted i
        ON i.id_delito = dh.id_delito
       AND ISNULL(i.id_carga_nueva, 0) = ISNULL(dh.id_carga_nueva, 0)
       AND ISNULL(i.tipo_movimiento, N'') = ISNULL(dh.tipo_movimiento, N'')
       AND i.fecha_modificacion = dh.fecha_modificacion
    INNER JOIN dbo.delito de
        ON de.id_delito = i.id_delito
    WHERE ISNULL(dh.codigo_postal_fiscalia, N'') <> ISNULL(de.codigo_postal_fiscalia, N'');
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_carga_actualizacion_codigo_postal_fiscalia
ON dbo.carga
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(estado)
    BEGIN
        RETURN;
    END;

    SELECT DISTINCT
        i.id_carga AS id_carga_actualizacion,
        i.id_usuario_confirmacion,
        actual.id_delito,
        nuevo_cp.id_codigo_postal AS id_codigo_postal_nuevo,
        NULLIF(LTRIM(RTRIM(tmp.cp)), N'') AS codigo_postal_fiscalia_nuevo
    INTO #cambios_cp
    FROM inserted i
    INNER JOIN deleted d
        ON d.id_carga = i.id_carga
    INNER JOIN dbo.carga_tmp_delito tmp
        ON tmp.id_carga = i.id_carga
       AND tmp.activo = 1
    CROSS APPLY
    (
        SELECT TOP 1 de.id_delito
        FROM dbo.delito de
        INNER JOIN dbo.carpeta_investigacion ci
            ON ci.id_carpeta_investigacion = de.id_carpeta_investigacion
           AND ci.activo = 1
        INNER JOIN dbo.carga c
            ON c.id_carga = de.id_carga
        WHERE ci.identificador_carpeta_fiscalia = tmp.id_ci
          AND de.identificador_delito_fiscalia = tmp.id_delito
          AND de.activo = 1
          AND c.id_entidad_federativa = i.id_entidad_federativa
          AND c.mes_corte = i.mes_corte
          AND c.anio_corte = i.anio_corte
          AND c.estado IN (N'CONFIRMADO', N'CONFIRMADO_ACTUALIZACION')
          AND c.activo = 1
        ORDER BY ISNULL(c.fecha_confirmacion, '19000101') DESC, de.id_carga DESC, de.id_delito DESC
    ) actual
    INNER JOIN dbo.delito de_actual
        ON de_actual.id_delito = actual.id_delito
    LEFT JOIN dbo.catalogo_codigo_postal cp_actual
        ON cp_actual.id_codigo_postal = de_actual.id_codigo_postal
    OUTER APPLY
    (
        SELECT TOP 1 ccp.id_codigo_postal
        FROM dbo.catalogo_codigo_postal ccp
        WHERE ccp.codigo_postal = RIGHT(N'00000' + LTRIM(RTRIM(tmp.cp)), 5)
          AND ccp.id_municipio = de_actual.id_municipio
          AND ccp.activo = 1
        ORDER BY ccp.id_codigo_postal
    ) nuevo_cp
    WHERE i.estado = N'CONFIRMADO_ACTUALIZACION'
      AND ISNULL(d.estado, N'') <> N'CONFIRMADO_ACTUALIZACION'
      AND i.activo = 1
      AND ISNULL(COALESCE(NULLIF(LTRIM(RTRIM(de_actual.codigo_postal_fiscalia)), N''), NULLIF(LTRIM(RTRIM(cp_actual.codigo_postal)), N'')), N'')
          <> ISNULL(NULLIF(LTRIM(RTRIM(tmp.cp)), N''), N'');

    INSERT INTO dbo.delito_historico
    (
        id_delito,
        id_carpeta_investigacion,
        identificador_delito_fiscalia,
        delito_fiscalia,
        modalidad_delito_fiscalia,
        id_forma_accion,
        fecha_hechos,
        id_instrumento_comision,
        id_grado_consumacion,
        id_modalidad_delito,
        id_entidad_federativa,
        id_municipio,
        id_localidad_fiscalia,
        localidad_fiscalia_nombre,
        id_colonia_fiscalia,
        colonia_fiscalia_nombre,
        id_codigo_postal,
        codigo_postal_fiscalia,
        coordenada_x,
        coordenada_y,
        domicilio_hechos,
        id_usuario_registro,
        fecha_registro,
        id_carga,
        id_usuario_modificacion,
        id_carga_nueva,
        tipo_movimiento,
        fecha_modificacion,
        activo
    )
    SELECT
        de.id_delito,
        de.id_carpeta_investigacion,
        de.identificador_delito_fiscalia,
        de.delito_fiscalia,
        de.modalidad_delito_fiscalia,
        de.id_forma_accion,
        de.fecha_hechos,
        de.id_instrumento_comision,
        de.id_grado_consumacion,
        de.id_modalidad_delito,
        de.id_entidad_federativa,
        de.id_municipio,
        de.id_localidad_fiscalia,
        de.localidad_fiscalia_nombre,
        de.id_colonia_fiscalia,
        de.colonia_fiscalia_nombre,
        de.id_codigo_postal,
        de.codigo_postal_fiscalia,
        de.coordenada_x,
        de.coordenada_y,
        de.domicilio_hechos,
        de.id_usuario_registro,
        de.fecha_registro,
        de.id_carga,
        cp.id_usuario_confirmacion,
        cp.id_carga_actualizacion,
        N'MODIFICADO',
        SYSDATETIME(),
        de.activo
    FROM #cambios_cp cp
    INNER JOIN dbo.delito de
        ON de.id_delito = cp.id_delito
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.delito_historico dh
        WHERE dh.id_delito = de.id_delito
          AND dh.id_carga_nueva = cp.id_carga_actualizacion
    );

    UPDATE de
    SET de.id_codigo_postal = cp.id_codigo_postal_nuevo,
        de.codigo_postal_fiscalia = cp.codigo_postal_fiscalia_nuevo,
        de.id_carga = cp.id_carga_actualizacion
    FROM dbo.delito de
    INNER JOIN #cambios_cp cp
        ON cp.id_delito = de.id_delito;
END;
GO


USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Objetivos TABLE
    (
        esquema SYSNAME NOT NULL,
        tabla SYSNAME NOT NULL,
        columna SYSNAME NOT NULL,
        PRIMARY KEY (esquema, tabla, columna)
    );

    INSERT INTO @Objetivos (esquema, tabla, columna)
    VALUES
        (N'dbo', N'carga_tmp_delito', N'id_loc_hchos'),
        (N'dbo', N'delito', N'id_localidad_fiscalia'),
        (N'dbo', N'delito_historico', N'id_localidad_fiscalia');

    IF EXISTS
    (
        SELECT 1
        FROM @Objetivos o
        LEFT JOIN sys.schemas s ON s.name = o.esquema
        LEFT JOIN sys.tables t ON t.schema_id = s.schema_id AND t.name = o.tabla
        LEFT JOIN sys.columns c ON c.object_id = t.object_id AND c.name = o.columna
        WHERE c.object_id IS NULL
    )
    BEGIN
        THROW 50001, 'No se encontraron todas las columnas requeridas para ampliar ID_LOC_HCHOS.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM @Objetivos o
        INNER JOIN sys.schemas s ON s.name = o.esquema
        INNER JOIN sys.tables t ON t.schema_id = s.schema_id AND t.name = o.tabla
        INNER JOIN sys.columns c ON c.object_id = t.object_id AND c.name = o.columna
        INNER JOIN sys.types ty ON ty.user_type_id = c.user_type_id
        WHERE ty.name NOT IN (N'varchar', N'nvarchar')
    )
    BEGIN
        THROW 50002, 'Una de las columnas requeridas no es VARCHAR ni NVARCHAR. Se cancela el cambio.', 1;
    END;

    DECLARE @Sql NVARCHAR(MAX) = N'';

    SELECT @Sql = @Sql
        + N'ALTER TABLE ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)
        + N' ALTER COLUMN ' + QUOTENAME(c.name) + N' '
        + CASE WHEN ty.name = N'nvarchar' THEN N'NVARCHAR(250)' ELSE N'VARCHAR(250)' END
        + CASE WHEN c.is_nullable = 1 THEN N' NULL;' ELSE N' NOT NULL;' END
        + CHAR(13) + CHAR(10)
    FROM @Objetivos o
    INNER JOIN sys.schemas s ON s.name = o.esquema
    INNER JOIN sys.tables t ON t.schema_id = s.schema_id AND t.name = o.tabla
    INNER JOIN sys.columns c ON c.object_id = t.object_id AND c.name = o.columna
    INNER JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    WHERE
        c.max_length <> -1
        AND
        CASE
            WHEN ty.name = N'nvarchar' THEN c.max_length / 2
            ELSE c.max_length
        END < 250;

    IF @Sql <> N''
    BEGIN
        EXEC sys.sp_executesql @Sql;
    END;

    COMMIT TRANSACTION;

    SELECT
        s.name AS esquema,
        t.name AS tabla,
        c.name AS columna,
        ty.name AS tipo,
        CASE
            WHEN c.max_length = -1 THEN -1
            WHEN ty.name = N'nvarchar' THEN c.max_length / 2
            ELSE c.max_length
        END AS longitud_caracteres,
        c.is_nullable
    FROM @Objetivos o
    INNER JOIN sys.schemas s ON s.name = o.esquema
    INNER JOIN sys.tables t ON t.schema_id = s.schema_id AND t.name = o.tabla
    INNER JOIN sys.columns c ON c.object_id = t.object_id AND c.name = o.columna
    INNER JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    ORDER BY t.name, c.name;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO