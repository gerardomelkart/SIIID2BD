-- BANCI 09: los catálogos existentes determinan las claves permitidas.
-- Ejecutar primero en QA, seleccionando la base correspondiente en SSMS.
-- Quita CHECK heredados que contradicen las FK y amplía CP como el staging.
-- Requiere el ajuste 07 de POB/DISC. API con normalización de esos campos vigente.
-- Conserva registros, cargas pendientes, catálogos y procedimientos instalados.
-- La API mantiene la validación de claves activas; la FK valida su existencia.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0
    THROW 52900, 'Ejecute el ajuste sin una transacción abierta.', 1;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 52901, 'Seleccione la base SIIID2 correspondiente.', 1;

DECLARE @Relaciones TABLE
(
    tabla SYSNAME NOT NULL,
    columna SYSNAME NOT NULL,
    catalogo SYSNAME NOT NULL,
    columna_catalogo SYSNAME NOT NULL DEFAULT N'clave',
    fk SYSNAME NOT NULL,
    restriccion SYSNAME NULL
);

-- Son nombres del esquema, no listas de valores del catálogo.
INSERT INTO @Relaciones (tabla, columna, catalogo, fk, restriccion)
VALUES
    (N'banci_delito', N'forma_acc', N'catalogo_forma_accion', N'FK_banci_delito_forma_accion', N'CK_banci_delito_forma_accion'),
    (N'banci_delito', N'emto_com_dto', N'catalogo_instrumento_comision', N'FK_banci_delito_instrumento', N'CK_banci_delito_instrumento'),
    (N'banci_delito', N'grdo_cons', N'catalogo_grado_consumacion', N'FK_banci_delito_grado', N'CK_banci_delito_grado'),
    (N'banci_victima', N'sexo', N'catalogo_sexo', N'FK_banci_victima_sexo', N'CK_banci_victima_sexo'),
    (N'banci_victima', N'genero', N'catalogo_genero', N'FK_banci_victima_genero', N'CK_banci_victima_genero'),
    (N'banci_victima', N'localizado_o_no_localizado', N'banci_catalogo_localizacion', N'FK_banci_victima_localizacion', N'CK_banci_victima_localizacion'),
    (N'banci_victima', N'con_o_sin_vida', N'banci_catalogo_condicion_vida', N'FK_banci_victima_condicion_vida', N'CK_banci_victima_condicion_vida'),
    (N'banci_victima', N'voluntaria', N'banci_catalogo_voluntaria', N'FK_banci_victima_voluntaria', N'CK_banci_victima_voluntaria'),
    (N'banci_victima', N'fue_delito', N'banci_catalogo_fue_delito', N'FK_banci_victima_fue_delito', N'CK_banci_victima_fue_delito'),
    (N'banci_victima', N'id_tv', N'catalogo_tipo_victima', N'FK_banci_victima_tipo_victima', NULL),
    (N'banci_victima', N'id_tpm', N'catalogo_tipo_victima_moral', N'FK_banci_victima_tipo_persona_moral', NULL),
    (N'banci_victima', N'nacional', N'catalogo_nacionalidad', N'FK_banci_victima_nacionalidad', NULL),
    (N'banci_victima', N'pob', N'catalogo_pertenece_poblacion_indigena', N'FK_banci_victima_pob_catalogo', N'CK_banci_victima_pob'),
    (N'banci_victima', N'disc', N'catalogo_presenta_discapacidad', N'FK_banci_victima_disc_catalogo', N'CK_banci_victima_disc');

INSERT INTO @Relaciones (tabla, columna, catalogo, columna_catalogo, fk, restriccion)
VALUES
    (N'banci_carga', N'id_entidad_federativa', N'catalogo_entidad_federativa', N'id_entidad_federativa', N'FK_banci_carga_entidad', NULL),
    (N'banci_carpeta_investigacion', N'id_entidad_federativa', N'catalogo_entidad_federativa', N'id_entidad_federativa', N'FK_banci_carpeta_entidad', NULL),
    (N'banci_delito', N'id_ent_hchos', N'catalogo_entidad_federativa', N'id_entidad_federativa', N'FK_banci_delito_entidad_hechos', NULL);

BEGIN TRY
    BEGIN TRANSACTION;

    -- No retirar un CHECK sin verificar que la FK existente protege esa misma columna.
    IF EXISTS
    (
        SELECT 1
        FROM @Relaciones r
        WHERE OBJECT_ID(N'dbo.' + r.tabla, N'U') IS NULL
           OR OBJECT_ID(N'dbo.' + r.catalogo, N'U') IS NULL
           OR COL_LENGTH(N'dbo.' + r.tabla, r.columna) IS NULL
           OR COL_LENGTH(N'dbo.' + r.catalogo, r.columna_catalogo) IS NULL
           OR (EXISTS (SELECT 1 FROM sys.foreign_keys f WHERE f.name = r.fk)
               AND NOT EXISTS
        (
            SELECT 1
            FROM sys.foreign_keys f
            JOIN sys.foreign_key_columns fc ON fc.constraint_object_id = f.object_id
            WHERE f.name = r.fk
              AND f.parent_object_id = OBJECT_ID(N'dbo.' + r.tabla, N'U')
              AND f.referenced_object_id = OBJECT_ID(N'dbo.' + r.catalogo, N'U')
              AND COL_NAME(fc.parent_object_id, fc.parent_column_id) = r.columna
              AND COL_NAME(fc.referenced_object_id, fc.referenced_column_id) = r.columna_catalogo
              AND (SELECT COUNT(*) FROM sys.foreign_key_columns c WHERE c.constraint_object_id = f.object_id) = 1
        ))
    )
        THROW 52902, 'Falta una tabla/columna de catálogo o una FK existente apunta a otro destino. Revise la estructura.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.banci_delito', N'U')
          AND name = N'cp' AND system_type_id = TYPE_ID(N'nvarchar') AND is_nullable = 1
    )
        THROW 52903, 'La columna banci_delito.cp no tiene el tipo/nulabilidad esperados.', 1;

    DECLARE @Tabla SYSNAME, @Columna SYSNAME, @Catalogo SYSNAME, @ColumnaCatalogo SYSNAME,
            @Fk SYSNAME, @Check SYSNAME, @Sql NVARCHAR(MAX);
    DECLARE relaciones CURSOR LOCAL FAST_FORWARD FOR
        SELECT tabla, columna, catalogo, columna_catalogo, fk, restriccion FROM @Relaciones ORDER BY tabla, columna;
    OPEN relaciones;
    FETCH NEXT FROM relaciones INTO @Tabla, @Columna, @Catalogo, @ColumnaCatalogo, @Fk, @Check;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.' + @Tabla) AND name = @Fk)
        BEGIN
            SET @Sql = N'ALTER TABLE dbo.' + QUOTENAME(@Tabla)
                + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@Fk)
                + N' FOREIGN KEY (' + QUOTENAME(@Columna) + N') REFERENCES dbo.'
                + QUOTENAME(@Catalogo) + N' (' + QUOTENAME(@ColumnaCatalogo) + N');';
            EXEC sys.sp_executesql @Sql;
        END;

        -- WITH CHECK verifica también los datos existentes y deja la FK habilitada y confiable.
        SET @Sql = N'ALTER TABLE dbo.' + QUOTENAME(@Tabla)
            + N' WITH CHECK CHECK CONSTRAINT ' + QUOTENAME(@Fk) + N';';
        EXEC sys.sp_executesql @Sql;

        IF EXISTS
        (
            SELECT 1 FROM sys.check_constraints
            WHERE parent_object_id = OBJECT_ID(N'dbo.' + @Tabla, N'U') AND name = @Check
        )
        BEGIN
            SET @Sql = N'ALTER TABLE dbo.' + QUOTENAME(@Tabla)
                + N' DROP CONSTRAINT ' + QUOTENAME(@Check) + N';';
            EXEC sys.sp_executesql @Sql;
        END;
        FETCH NEXT FROM relaciones INTO @Tabla, @Columna, @Catalogo, @ColumnaCatalogo, @Fk, @Check;
    END;
    CLOSE relaciones;
    DEALLOCATE relaciones;

    -- La geografía municipal se relaciona por entidad + clave, como en Consolidado.
    IF NOT EXISTS
    (
        SELECT 1 FROM sys.foreign_keys f
        WHERE f.name = N'FK_banci_delito_municipio_hechos'
          AND f.parent_object_id = OBJECT_ID(N'dbo.banci_delito')
          AND f.referenced_object_id = OBJECT_ID(N'dbo.catalogo_municipio')
          AND (SELECT COUNT(*) FROM sys.foreign_key_columns c WHERE c.constraint_object_id = f.object_id) = 2
          AND EXISTS (SELECT 1 FROM sys.foreign_key_columns c WHERE c.constraint_object_id = f.object_id
              AND COL_NAME(c.parent_object_id, c.parent_column_id) = N'id_ent_hchos'
              AND COL_NAME(c.referenced_object_id, c.referenced_column_id) = N'id_entidad_federativa')
          AND EXISTS (SELECT 1 FROM sys.foreign_key_columns c WHERE c.constraint_object_id = f.object_id
              AND COL_NAME(c.parent_object_id, c.parent_column_id) = N'id_mun_hchos'
              AND COL_NAME(c.referenced_object_id, c.referenced_column_id) = N'clave')
    )
        THROW 52904, 'La FK de municipio no corresponde a entidad + clave del catálogo compartido.', 1;
    ALTER TABLE dbo.banci_delito WITH CHECK CHECK CONSTRAINT FK_banci_delito_municipio_hechos;

    -- No reducir la columna si ya es más amplia o NVARCHAR(MAX).
    IF EXISTS
    (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.banci_delito', N'U')
          AND name = N'cp' AND max_length > 0 AND max_length < 200
    )
        ALTER TABLE dbo.banci_delito ALTER COLUMN cp NVARCHAR(100) NULL;

    COMMIT TRANSACTION;

    SELECT DB_NAME() AS base_actual, r.tabla, r.columna, r.catalogo,
           f.name AS llave_foranea, f.is_disabled, f.is_not_trusted
    FROM @Relaciones r
    JOIN sys.foreign_keys f ON f.parent_object_id = OBJECT_ID(N'dbo.' + r.tabla) AND f.name = r.fk
    ORDER BY r.tabla, r.columna;
    SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = N'dbo' AND TABLE_NAME = N'banci_delito' AND COLUMN_NAME = N'cp';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
