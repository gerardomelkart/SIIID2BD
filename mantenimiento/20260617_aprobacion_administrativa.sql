USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -------------------------------------------------------------------------
    -- 1. Columnas que deben quedar como NVARCHAR(50) NOT NULL
    -------------------------------------------------------------------------

    DECLARE @Objetivos TABLE
    (
        esquema SYSNAME NOT NULL,
        tabla SYSNAME NOT NULL,
        columna SYSNAME NOT NULL,
        longitud_caracteres INT NOT NULL,
        PRIMARY KEY (esquema, tabla, columna)
    );

    INSERT INTO @Objetivos
    (
        esquema,
        tabla,
        columna,
        longitud_caracteres
    )
    VALUES
        ('dbo', 'carga',             'estado', 50),
        ('dbo', 'carga_tmp_carpeta', 'estado', 50),
        ('dbo', 'carga_tmp_delito',  'estado', 50),
        ('dbo', 'carga_tmp_victima', 'estado', 50);


    /*
        Solo se procesan columnas que:
        - midan menos de 50;
        - no sean NVARCHAR;
        - o permitan NULL.

        Si alguna ya es NVARCHAR(50) NOT NULL, se deja intacta y no se
        eliminan innecesariamente sus índices.
    */
    CREATE TABLE #ColumnasCambiar
    (
        object_id INT NOT NULL,
        column_id INT NOT NULL,
        esquema SYSNAME NOT NULL,
        tabla SYSNAME NOT NULL,
        columna SYSNAME NOT NULL,
        longitud_caracteres INT NOT NULL,
        PRIMARY KEY (object_id, column_id)
    );

    INSERT INTO #ColumnasCambiar
    (
        object_id,
        column_id,
        esquema,
        tabla,
        columna,
        longitud_caracteres
    )
    SELECT
        t.object_id,
        c.column_id,
        o.esquema,
        o.tabla,
        o.columna,
        o.longitud_caracteres
    FROM @Objetivos o
    INNER JOIN sys.schemas s
        ON s.name = o.esquema
    INNER JOIN sys.tables t
        ON t.schema_id = s.schema_id
       AND t.name = o.tabla
    INNER JOIN sys.columns c
        ON c.object_id = t.object_id
       AND c.name = o.columna
    INNER JOIN sys.types ty
        ON ty.user_type_id = c.user_type_id
    WHERE NOT
    (
        ty.name = 'nvarchar'
        AND
        (
            c.max_length = -1
            OR c.max_length >= o.longitud_caracteres * 2
        )
        AND c.is_nullable = 0
    );


    -------------------------------------------------------------------------
    -- 2. Validación preventiva
    -------------------------------------------------------------------------

    /*
        No esperamos PK ni restricciones UNIQUE sobre estado.
        Si existieran, es mejor detenerse que reconstruirlas incorrectamente.
    */
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes i
        INNER JOIN sys.index_columns ic
            ON ic.object_id = i.object_id
           AND ic.index_id = i.index_id
        INNER JOIN #ColumnasCambiar cc
            ON cc.object_id = ic.object_id
           AND cc.column_id = ic.column_id
        WHERE i.is_primary_key = 1
           OR i.is_unique_constraint = 1
    )
    BEGIN
        THROW 50001,
              'Existe una llave primaria o restricción UNIQUE dependiente de una columna estado.',
              1;
    END;


    -------------------------------------------------------------------------
    -- 3. Guardar definición de índices dependientes
    -------------------------------------------------------------------------

    CREATE TABLE #Indices
    (
        id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        sentencia_eliminar NVARCHAR(MAX) NOT NULL,
        sentencia_crear NVARCHAR(MAX) NOT NULL
    );

    INSERT INTO #Indices
    (
        sentencia_eliminar,
        sentencia_crear
    )
    SELECT
        N'DROP INDEX ' +
        QUOTENAME(i.name) +
        N' ON ' +
        QUOTENAME(s.name) +
        N'.' +
        QUOTENAME(t.name) +
        N';',

        N'CREATE ' +
        CASE WHEN i.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END +
        i.type_desc +
        N' INDEX ' +
        QUOTENAME(i.name) +
        N' ON ' +
        QUOTENAME(s.name) +
        N'.' +
        QUOTENAME(t.name) +
        N' (' +
        claves.columnas +
        N')' +

        CASE
            WHEN incluidos.columnas IS NOT NULL
            THEN N' INCLUDE (' + incluidos.columnas + N')'
            ELSE N''
        END +

        CASE
            WHEN i.has_filter = 1
            THEN N' WHERE ' + i.filter_definition
            ELSE N''
        END +

        N' WITH (' +
        N'PAD_INDEX = ' +
            CASE WHEN i.is_padded = 1 THEN N'ON' ELSE N'OFF' END +

        CASE
            WHEN i.fill_factor > 0
            THEN N', FILLFACTOR = ' + CONVERT(NVARCHAR(3), i.fill_factor)
            ELSE N''
        END +

        CASE
            WHEN i.is_unique = 1
            THEN N', IGNORE_DUP_KEY = ' +
                CASE WHEN i.ignore_dup_key = 1 THEN N'ON' ELSE N'OFF' END
            ELSE N''
        END +

        N', ALLOW_ROW_LOCKS = ' +
            CASE WHEN i.allow_row_locks = 1 THEN N'ON' ELSE N'OFF' END +

        N', ALLOW_PAGE_LOCKS = ' +
            CASE WHEN i.allow_page_locks = 1 THEN N'ON' ELSE N'OFF' END +

        N')' +

        CASE
            WHEN ds.type = 'FG'
            THEN N' ON ' + QUOTENAME(ds.name)
            ELSE N''
        END +

        N';'
    FROM sys.indexes i
    INNER JOIN sys.tables t
        ON t.object_id = i.object_id
    INNER JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    LEFT JOIN sys.data_spaces ds
        ON ds.data_space_id = i.data_space_id

    CROSS APPLY
    (
        SELECT
            STRING_AGG
            (
                CAST
                (
                    QUOTENAME(c.name) +
                    CASE
                        WHEN ic.is_descending_key = 1 THEN N' DESC'
                        ELSE N' ASC'
                    END
                    AS NVARCHAR(MAX)
                ),
                N', '
            ) WITHIN GROUP (ORDER BY ic.key_ordinal) AS columnas
        FROM sys.index_columns ic
        INNER JOIN sys.columns c
            ON c.object_id = ic.object_id
           AND c.column_id = ic.column_id
        WHERE ic.object_id = i.object_id
          AND ic.index_id = i.index_id
          AND ic.key_ordinal > 0
    ) claves

    OUTER APPLY
    (
        SELECT
            STRING_AGG
            (
                CAST(QUOTENAME(c.name) AS NVARCHAR(MAX)),
                N', '
            ) WITHIN GROUP (ORDER BY ic.index_column_id) AS columnas
        FROM sys.index_columns ic
        INNER JOIN sys.columns c
            ON c.object_id = ic.object_id
           AND c.column_id = ic.column_id
        WHERE ic.object_id = i.object_id
          AND ic.index_id = i.index_id
          AND ic.is_included_column = 1
    ) incluidos

    WHERE i.index_id > 0
      AND i.is_hypothetical = 0
      AND i.type IN (1, 2)
      AND i.is_primary_key = 0
      AND i.is_unique_constraint = 0
      AND EXISTS
      (
          SELECT 1
          FROM #ColumnasCambiar cc
          WHERE cc.object_id = i.object_id
            AND
            (
                EXISTS
                (
                    SELECT 1
                    FROM sys.index_columns ic2
                    WHERE ic2.object_id = i.object_id
                      AND ic2.index_id = i.index_id
                      AND ic2.column_id = cc.column_id
                )
                OR
                (
                    i.has_filter = 1
                    AND LOWER
                    (
                        REPLACE
                        (
                            REPLACE(i.filter_definition, '[', ''),
                            ']',
                            ''
                        )
                    ) LIKE N'%' + LOWER(cc.columna) + N'%'
                )
            )
      );


    -------------------------------------------------------------------------
    -- 4. Guardar estadísticas independientes
    -------------------------------------------------------------------------

    CREATE TABLE #Estadisticas
    (
        id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        sentencia_eliminar NVARCHAR(MAX) NOT NULL,
        sentencia_crear NVARCHAR(MAX) NULL
    );

    INSERT INTO #Estadisticas
    (
        sentencia_eliminar,
        sentencia_crear
    )
    SELECT
        N'DROP STATISTICS ' +
        QUOTENAME(sc.name) +
        N'.' +
        QUOTENAME(t.name) +
        N'.' +
        QUOTENAME(st.name) +
        N';',

        CASE
            /*
                Las estadísticas automáticas no necesitan recrearse:
                SQL Server las generará nuevamente cuando sean necesarias.
            */
            WHEN st.auto_created = 1 THEN NULL
            ELSE
                N'CREATE STATISTICS ' +
                QUOTENAME(st.name) +
                N' ON ' +
                QUOTENAME(sc.name) +
                N'.' +
                QUOTENAME(t.name) +
                N' (' +
                columnas.columnas +
                N')' +

                CASE
                    WHEN st.has_filter = 1
                    THEN N' WHERE ' + st.filter_definition
                    ELSE N''
                END +

                CASE
                    WHEN st.no_recompute = 1
                    THEN N' WITH NORECOMPUTE'
                    ELSE N''
                END +

                N';'
        END
    FROM sys.stats st
    INNER JOIN sys.tables t
        ON t.object_id = st.object_id
    INNER JOIN sys.schemas sc
        ON sc.schema_id = t.schema_id
    LEFT JOIN sys.indexes ix
        ON ix.object_id = st.object_id
       AND ix.index_id = st.stats_id

    CROSS APPLY
    (
        SELECT
            STRING_AGG
            (
                CAST(QUOTENAME(c.name) AS NVARCHAR(MAX)),
                N', '
            ) WITHIN GROUP (ORDER BY stc.stats_column_id) AS columnas
        FROM sys.stats_columns stc
        INNER JOIN sys.columns c
            ON c.object_id = stc.object_id
           AND c.column_id = stc.column_id
        WHERE stc.object_id = st.object_id
          AND stc.stats_id = st.stats_id
    ) columnas

    WHERE ix.index_id IS NULL
      AND EXISTS
      (
          SELECT 1
          FROM sys.stats_columns stc2
          INNER JOIN #ColumnasCambiar cc
              ON cc.object_id = stc2.object_id
             AND cc.column_id = stc2.column_id
          WHERE stc2.object_id = st.object_id
            AND stc2.stats_id = st.stats_id
      );


    -------------------------------------------------------------------------
    -- 5. Guardar restricciones DEFAULT
    -------------------------------------------------------------------------

    CREATE TABLE #Defaults
    (
        id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        sentencia_eliminar NVARCHAR(MAX) NOT NULL,
        sentencia_crear NVARCHAR(MAX) NOT NULL
    );

    INSERT INTO #Defaults
    (
        sentencia_eliminar,
        sentencia_crear
    )
    SELECT
        N'ALTER TABLE ' +
        QUOTENAME(cc.esquema) +
        N'.' +
        QUOTENAME(cc.tabla) +
        N' DROP CONSTRAINT ' +
        QUOTENAME(dc.name) +
        N';',

        N'ALTER TABLE ' +
        QUOTENAME(cc.esquema) +
        N'.' +
        QUOTENAME(cc.tabla) +
        N' ADD CONSTRAINT ' +
        QUOTENAME(dc.name) +
        N' DEFAULT ' +
        dc.definition +
        N' FOR ' +
        QUOTENAME(cc.columna) +
        N';'
    FROM sys.default_constraints dc
    INNER JOIN #ColumnasCambiar cc
        ON cc.object_id = dc.parent_object_id
       AND cc.column_id = dc.parent_column_id;


    -------------------------------------------------------------------------
    -- 6. Eliminar temporalmente dependencias
    -------------------------------------------------------------------------

    DECLARE @Sql NVARCHAR(MAX);

    DECLARE cursor_indices_eliminar CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT sentencia_eliminar
        FROM #Indices
        ORDER BY id;

    OPEN cursor_indices_eliminar;

    FETCH NEXT FROM cursor_indices_eliminar INTO @Sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM cursor_indices_eliminar INTO @Sql;
    END;

    CLOSE cursor_indices_eliminar;
    DEALLOCATE cursor_indices_eliminar;


    DECLARE cursor_estadisticas_eliminar CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT sentencia_eliminar
        FROM #Estadisticas
        ORDER BY id;

    OPEN cursor_estadisticas_eliminar;

    FETCH NEXT FROM cursor_estadisticas_eliminar INTO @Sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM cursor_estadisticas_eliminar INTO @Sql;
    END;

    CLOSE cursor_estadisticas_eliminar;
    DEALLOCATE cursor_estadisticas_eliminar;


    DECLARE cursor_defaults_eliminar CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT sentencia_eliminar
        FROM #Defaults
        ORDER BY id;

    OPEN cursor_defaults_eliminar;

    FETCH NEXT FROM cursor_defaults_eliminar INTO @Sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM cursor_defaults_eliminar INTO @Sql;
    END;

    CLOSE cursor_defaults_eliminar;
    DEALLOCATE cursor_defaults_eliminar;


    -------------------------------------------------------------------------
    -- 7. Ampliar las cuatro columnas
    -------------------------------------------------------------------------

    DECLARE cursor_columnas CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT
            N'ALTER TABLE ' +
            QUOTENAME(esquema) +
            N'.' +
            QUOTENAME(tabla) +
            N' ALTER COLUMN ' +
            QUOTENAME(columna) +
            N' NVARCHAR(' +
            CONVERT(NVARCHAR(10), longitud_caracteres) +
            N') NOT NULL;'
        FROM #ColumnasCambiar
        ORDER BY tabla;

    OPEN cursor_columnas;

    FETCH NEXT FROM cursor_columnas INTO @Sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM cursor_columnas INTO @Sql;
    END;

    CLOSE cursor_columnas;
    DEALLOCATE cursor_columnas;


    -------------------------------------------------------------------------
    -- 8. Restaurar DEFAULTS
    -------------------------------------------------------------------------

    DECLARE cursor_defaults_crear CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT sentencia_crear
        FROM #Defaults
        ORDER BY id;

    OPEN cursor_defaults_crear;

    FETCH NEXT FROM cursor_defaults_crear INTO @Sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM cursor_defaults_crear INTO @Sql;
    END;

    CLOSE cursor_defaults_crear;
    DEALLOCATE cursor_defaults_crear;


    -------------------------------------------------------------------------
    -- 9. Restaurar estadísticas manuales
    -------------------------------------------------------------------------

    DECLARE cursor_estadisticas_crear CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT sentencia_crear
        FROM #Estadisticas
        WHERE sentencia_crear IS NOT NULL
        ORDER BY id;

    OPEN cursor_estadisticas_crear;

    FETCH NEXT FROM cursor_estadisticas_crear INTO @Sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM cursor_estadisticas_crear INTO @Sql;
    END;

    CLOSE cursor_estadisticas_crear;
    DEALLOCATE cursor_estadisticas_crear;


    -------------------------------------------------------------------------
    -- 10. Restaurar índices con su definición real
    -------------------------------------------------------------------------

    DECLARE cursor_indices_crear CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT sentencia_crear
        FROM #Indices
        ORDER BY id;

    OPEN cursor_indices_crear;

    FETCH NEXT FROM cursor_indices_crear INTO @Sql;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM cursor_indices_crear INTO @Sql;
    END;

    CLOSE cursor_indices_crear;
    DEALLOCATE cursor_indices_crear;


    -------------------------------------------------------------------------
    -- 11. Crear almacenamiento de advertencias
    -------------------------------------------------------------------------

    IF OBJECT_ID('dbo.carga_advertencia', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.carga_advertencia
        (
            id_carga_advertencia BIGINT IDENTITY(1,1) NOT NULL,
            id_carga BIGINT NOT NULL,

            codigo NVARCHAR(150) NOT NULL,
            archivo NVARCHAR(50) NOT NULL,
            numero_fila INT NULL,
            columna NVARCHAR(150) NULL,
            campo NVARCHAR(150) NULL,
            valor NVARCHAR(1000) NULL,
            descripcion_resumen NVARCHAR(500) NOT NULL,
            mensaje NVARCHAR(2000) NOT NULL,

            aceptada_usuario BIT NOT NULL
                CONSTRAINT DF_carga_advertencia_aceptada_usuario
                DEFAULT (0),

            id_usuario_aceptacion INT NULL,
            fecha_aceptacion DATETIME2(0) NULL,

            activo BIT NOT NULL
                CONSTRAINT DF_carga_advertencia_activo
                DEFAULT (1),

            CONSTRAINT PK_carga_advertencia
                PRIMARY KEY (id_carga_advertencia),

            CONSTRAINT FK_carga_advertencia_carga
                FOREIGN KEY (id_carga)
                REFERENCES dbo.carga(id_carga),

            CONSTRAINT FK_carga_advertencia_usuario_aceptacion
                FOREIGN KEY (id_usuario_aceptacion)
                REFERENCES dbo.usuario(id_usuario)
        );
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.carga_advertencia')
          AND name = 'IX_carga_advertencia_carga'
    )
    BEGIN
        CREATE INDEX IX_carga_advertencia_carga
            ON dbo.carga_advertencia
            (
                id_carga,
                activo
            );
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.carga_advertencia')
          AND name = 'IX_carga_advertencia_codigo'
    )
    BEGIN
        CREATE INDEX IX_carga_advertencia_codigo
            ON dbo.carga_advertencia(codigo);
    END;


    -------------------------------------------------------------------------
    -- 12. Crear bitácora de cambios de estado
    -------------------------------------------------------------------------

    IF OBJECT_ID('dbo.carga_bitacora_estado', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.carga_bitacora_estado
        (
            id_carga_bitacora_estado BIGINT IDENTITY(1,1) NOT NULL,
            id_carga BIGINT NOT NULL,

            estado_anterior NVARCHAR(50) NULL,
            estado_nuevo NVARCHAR(50) NOT NULL,

            id_usuario INT NULL,

            fecha DATETIME2(0) NOT NULL
                CONSTRAINT DF_carga_bitacora_estado_fecha
                DEFAULT (SYSDATETIME()),

            comentario NVARCHAR(2000) NULL,

            activo BIT NOT NULL
                CONSTRAINT DF_carga_bitacora_estado_activo
                DEFAULT (1),

            CONSTRAINT PK_carga_bitacora_estado
                PRIMARY KEY (id_carga_bitacora_estado),

            CONSTRAINT FK_carga_bitacora_estado_carga
                FOREIGN KEY (id_carga)
                REFERENCES dbo.carga(id_carga),

            CONSTRAINT FK_carga_bitacora_estado_usuario
                FOREIGN KEY (id_usuario)
                REFERENCES dbo.usuario(id_usuario)
        );
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.carga_bitacora_estado')
          AND name = 'IX_carga_bitacora_estado_carga_fecha'
    )
    BEGIN
        CREATE INDEX IX_carga_bitacora_estado_carga_fecha
            ON dbo.carga_bitacora_estado
            (
                id_carga,
                fecha,
                id_carga_bitacora_estado
            );
    END;


    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.carga_bitacora_estado')
          AND name = 'IX_carga_bitacora_estado_nuevo'
    )
    BEGIN
        CREATE INDEX IX_carga_bitacora_estado_nuevo
            ON dbo.carga_bitacora_estado
            (
                estado_nuevo,
                fecha
            );
    END;


    COMMIT TRANSACTION;

    PRINT 'Columnas estado ampliadas y estructura administrativa creada correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO