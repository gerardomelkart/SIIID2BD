-- REFERENCIA TECNICA: base y ajustes en secuencia; no ejecutar sobre una BD publicada.
-- No sustituye una exportación del esquema real. Revisar dependencias indicadas en README.

-- Fuente: indices y correcciones/010_indices_performance_siiid.sql
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


GO

-- Fuente: indices y correcciones/20260617_aprobacion_administrativa.sql
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

GO

-- Fuente: indices y correcciones/20260623_orden_sabanas_legacy.sql
-- Orden legacy de sábanas derivado de 'sabanas viejas.zip'
-- Fuente: archivos estatales/municipales viejos comparados contra SABANAS_nuevas.zip.
IF OBJECT_ID('dbo.catalogo_sabana_orden_legacy', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.catalogo_sabana_orden_legacy (
        id_orden_legacy INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_catalogo_sabana_orden_legacy PRIMARY KEY,
        bien_juridico NVARCHAR(300) NOT NULL,
        delito_sabana NVARCHAR(300) NOT NULL,
        subtipo_delito_sabana NVARCHAR(300) NOT NULL,
        modalidad_delito_sabana NVARCHAR(300) NOT NULL,
        orden_general INT NULL,
        orden_municipal_victimas INT NULL,
        activo BIT NOT NULL CONSTRAINT df_catalogo_sabana_orden_legacy_activo DEFAULT (1)
    );

    CREATE UNIQUE INDEX ux_catalogo_sabana_orden_legacy
    ON dbo.catalogo_sabana_orden_legacy (bien_juridico, delito_sabana, subtipo_delito_sabana, modalidad_delito_sabana);
END;
GO

MERGE dbo.catalogo_sabana_orden_legacy AS destino
USING (
    SELECT N'El patrimonio' AS bien_juridico, N'Abuso de confianza' AS delito_sabana, N'Abuso de confianza' AS subtipo_delito_sabana, N'Abuso de confianza' AS modalidad_delito_sabana, 82 AS orden_general, 1 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Daño a la propiedad' AS delito_sabana, N'Daño a la propiedad' AS subtipo_delito_sabana, N'Daño a la propiedad' AS modalidad_delito_sabana, 87 AS orden_general, 2 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Despojo' AS delito_sabana, N'Despojo' AS subtipo_delito_sabana, N'Despojo' AS modalidad_delito_sabana, 88 AS orden_general, 3 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Extorsión por otros medios' AS subtipo_delito_sabana, N'Extorsión por otros medios' AS modalidad_delito_sabana, 85 AS orden_general, 4 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Extorsión presencial' AS subtipo_delito_sabana, N'Extorsión presencial' AS modalidad_delito_sabana, 83 AS orden_general, 5 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Tentativa de extorsión por otros medios' AS subtipo_delito_sabana, N'Tentativa de extorsión por otros medios' AS modalidad_delito_sabana, 86 AS orden_general, 6 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Tentativa de extorsión presencial' AS subtipo_delito_sabana, N'Tentativa de extorsión presencial' AS modalidad_delito_sabana, 84 AS orden_general, 94 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Fraude' AS delito_sabana, N'Fraude' AS subtipo_delito_sabana, N'Fraude' AS modalidad_delito_sabana, 81 AS orden_general, 7 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Otros delitos contra el patrimonio' AS delito_sabana, N'Otros delitos contra el patrimonio' AS subtipo_delito_sabana, N'Otros delitos contra el patrimonio' AS modalidad_delito_sabana, 44 AS orden_general, 8 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Otros robos' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 79 AS orden_general, 9 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Otros robos' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 80 AS orden_general, 10 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a casa habitación' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 45 AS orden_general, 11 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a casa habitación' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 46 AS orden_general, 12 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a institución bancaria' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 67 AS orden_general, 87 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a institución bancaria' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 68 AS orden_general, 102 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a negocio' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 69 AS orden_general, 13 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a negocio' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 70 AS orden_general, 14 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en espacio abierto al público' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 59 AS orden_general, 15 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en espacio abierto al público' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 60 AS orden_general, 16 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en vía pública' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 57 AS orden_general, 17 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en vía pública' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 58 AS orden_general, 18 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transportista' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 55 AS orden_general, 77 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transportista' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 56 AS orden_general, 83 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de autopartes' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 53 AS orden_general, 105 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de autopartes' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 54 AS orden_general, 19 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de ganado' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 71 AS orden_general, 99 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de ganado' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 72 AS orden_general, 20 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Cables, tubos y otros objetos destinados a servicios públicos' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 77 AS orden_general, 95 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Cables, tubos y otros objetos destinados a servicios públicos' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 78 AS orden_general, 92 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Herramienta industrial o agrícola' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 73 AS orden_general, 111 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Herramienta industrial o agrícola' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 74 AS orden_general, 106 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Tractores y/o montacargas' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 75 AS orden_general, 107 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Tractores y/o montacargas' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 76 AS orden_general, 21 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Coche de 4 ruedas' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 47 AS orden_general, 22 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Coche de 4 ruedas' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 48 AS orden_general, 23 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Embarcaciones' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 51 AS orden_general, 112 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Embarcaciones' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 52 AS orden_general, 96 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Motocicleta' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 49 AS orden_general, 24 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Motocicleta' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 50 AS orden_general, 25 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte individual' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 65 AS orden_general, 26 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte individual' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 66 AS orden_general, 27 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público colectivo' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 63 AS orden_general, 100 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público colectivo' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 64 AS orden_general, 28 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público individual' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 61 AS orden_general, 29 AS orden_municipal_victimas
    UNION ALL
    SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público individual' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 62 AS orden_general, 30 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La familia' AS bien_juridico, N'Incumplimiento de obligaciones de asistencia familiar' AS delito_sabana, N'Incumplimiento de obligaciones de asistencia familiar' AS subtipo_delito_sabana, N'Incumplimiento de obligaciones de asistencia familiar' AS modalidad_delito_sabana, 92 AS orden_general, 31 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La familia' AS bien_juridico, N'Otros delitos contra la familia' AS delito_sabana, N'Otros delitos contra la familia' AS subtipo_delito_sabana, N'Otros delitos contra la familia' AS modalidad_delito_sabana, 89 AS orden_general, 32 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La familia' AS bien_juridico, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS delito_sabana, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS subtipo_delito_sabana, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS modalidad_delito_sabana, 91 AS orden_general, 33 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La familia' AS bien_juridico, N'Violencia familiar' AS delito_sabana, N'Violencia familiar' AS subtipo_delito_sabana, N'Violencia familiar' AS modalidad_delito_sabana, 90 AS orden_general, 34 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Abuso sexual' AS delito_sabana, N'Abuso sexual' AS subtipo_delito_sabana, N'Abuso sexual' AS modalidad_delito_sabana, 36 AS orden_general, 35 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Acoso sexual' AS delito_sabana, N'Acoso sexual' AS subtipo_delito_sabana, N'Acoso sexual' AS modalidad_delito_sabana, 38 AS orden_general, 78 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Hostigamiento sexual' AS delito_sabana, N'Hostigamiento sexual' AS subtipo_delito_sabana, N'Hostigamiento sexual' AS modalidad_delito_sabana, 39 AS orden_general, 36 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Incesto' AS delito_sabana, N'Incesto' AS subtipo_delito_sabana, N'Incesto' AS modalidad_delito_sabana, 40 AS orden_general, 108 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS delito_sabana, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS modalidad_delito_sabana, 37 AS orden_general, 37 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación' AS delito_sabana, N'Violación equiparada' AS subtipo_delito_sabana, N'Violación equiparada' AS modalidad_delito_sabana, 42 AS orden_general, 38 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación' AS delito_sabana, N'Violación simple' AS subtipo_delito_sabana, N'Violación simple' AS modalidad_delito_sabana, 41 AS orden_general, 39 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación a la intimidad sexual' AS delito_sabana, N'Violación a la intimidad sexual' AS subtipo_delito_sabana, N'Violación a la intimidad sexual' AS modalidad_delito_sabana, 43 AS orden_general, 79 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La sociedad' AS bien_juridico, N'Corrupción de menores' AS delito_sabana, N'Corrupción de menores' AS subtipo_delito_sabana, N'Corrupción de menores' AS modalidad_delito_sabana, 93 AS orden_general, 40 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La sociedad' AS bien_juridico, N'Discriminación' AS delito_sabana, N'Discriminación' AS subtipo_delito_sabana, N'Discriminación' AS modalidad_delito_sabana, 100 AS orden_general, 80 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La sociedad' AS bien_juridico, N'Otros delitos contra la sociedad' AS delito_sabana, N'Otros delitos contra la sociedad' AS subtipo_delito_sabana, N'Otros delitos contra la sociedad' AS modalidad_delito_sabana, 94 AS orden_general, 81 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La sociedad' AS bien_juridico, N'Pornografía infantil' AS delito_sabana, N'Pornografía infantil' AS subtipo_delito_sabana, N'Pornografía infantil' AS modalidad_delito_sabana, 99 AS orden_general, 41 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de explotación sexual' AS subtipo_delito_sabana, N'Trata de personas con fines de explotación sexual' AS modalidad_delito_sabana, 95 AS orden_general, 42 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de trabajo o servicios forzados' AS subtipo_delito_sabana, N'Trata de personas con fines de trabajo o servicios forzados' AS modalidad_delito_sabana, 96 AS orden_general, 88 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de tráfico de órganos' AS subtipo_delito_sabana, N'Trata de personas con fines de tráfico de órganos' AS modalidad_delito_sabana, 97 AS orden_general, 113 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con otros fines' AS subtipo_delito_sabana, N'Trata de personas con otros fines' AS modalidad_delito_sabana, 98 AS orden_general, 89 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Aborto' AS delito_sabana, N'Aborto' AS subtipo_delito_sabana, N'Aborto' AS modalidad_delito_sabana, 26 AS orden_general, 43 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 21 AS orden_general, 84 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 22 AS orden_general, 90 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 23 AS orden_general, 75 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 24 AS orden_general, 97 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Tentativa de feminicidio' AS subtipo_delito_sabana, N'Tentativa de feminicidio' AS modalidad_delito_sabana, 25 AS orden_general, 44 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 6 AS orden_general, 104 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 7 AS orden_general, 101 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 8 AS orden_general, 45 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'En accidente de tránsito' AS modalidad_delito_sabana, 9 AS orden_general, 46 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 10 AS orden_general, 47 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 1 AS orden_general, 48 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 2 AS orden_general, 49 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 3 AS orden_general, 50 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 4 AS orden_general, 85 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Tentativa de homicidio doloso' AS subtipo_delito_sabana, N'Tentativa de homicidio doloso' AS modalidad_delito_sabana, 5 AS orden_general, 74 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 16 AS orden_general, 51 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 17 AS orden_general, 52 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 18 AS orden_general, 53 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'En accidente de tránsito' AS modalidad_delito_sabana, 19 AS orden_general, 54 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 20 AS orden_general, 55 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 12 AS orden_general, 56 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 13 AS orden_general, 57 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 14 AS orden_general, 58 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 15 AS orden_general, 59 AS orden_municipal_victimas
    UNION ALL
    SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Otros delitos que atentan contra la vida y la integridad corporal' AS delito_sabana, N'Otros delitos que atentan contra la vida y la integridad corporal' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la vida y la integridad corporal' AS modalidad_delito_sabana, 11 AS orden_general, 60 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Otros delitos que atentan contra la libertad personal' AS delito_sabana, N'Otros delitos que atentan contra la libertad personal' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la libertad personal' AS modalidad_delito_sabana, 27 AS orden_general, 76 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Privación ilegal de la libertad' AS delito_sabana, N'Privación ilegal de la libertad' AS subtipo_delito_sabana, N'Privación ilegal de la libertad' AS modalidad_delito_sabana, 34 AS orden_general, 61 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Rapto' AS delito_sabana, N'Rapto' AS subtipo_delito_sabana, N'Rapto' AS modalidad_delito_sabana, 33 AS orden_general, 110 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Retención o sustracción de menores e incapaces' AS delito_sabana, N'Retención o sustracción de menores e incapaces' AS subtipo_delito_sabana, N'Retención o sustracción de menores e incapaces' AS modalidad_delito_sabana, 35 AS orden_general, 62 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro con calidad de rehén' AS subtipo_delito_sabana, N'Secuestro con calidad de rehén' AS modalidad_delito_sabana, 29 AS orden_general, 109 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro exprés' AS subtipo_delito_sabana, N'Secuestro exprés' AS modalidad_delito_sabana, 31 AS orden_general, 98 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro extorsivo' AS subtipo_delito_sabana, N'Secuestro extorsivo' AS modalidad_delito_sabana, 28 AS orden_general, 103 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro para causar daño' AS subtipo_delito_sabana, N'Secuestro para causar daño' AS modalidad_delito_sabana, 30 AS orden_general, 91 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Libertad personal' AS bien_juridico, N'Tráfico de menores' AS delito_sabana, N'Tráfico de menores' AS subtipo_delito_sabana, N'Tráfico de menores' AS modalidad_delito_sabana, 32 AS orden_general, 114 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Allanamiento de morada' AS delito_sabana, N'Allanamiento de morada' AS subtipo_delito_sabana, N'Allanamiento de morada' AS modalidad_delito_sabana, 105 AS orden_general, 63 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Amenazas' AS delito_sabana, N'Amenazas' AS subtipo_delito_sabana, N'Amenazas' AS modalidad_delito_sabana, 104 AS orden_general, 64 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Contra el medio ambiente' AS delito_sabana, N'Contra el medio ambiente' AS subtipo_delito_sabana, N'Contra el medio ambiente' AS modalidad_delito_sabana, 109 AS orden_general, 65 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Delitos cometidos por servidores públicos' AS delito_sabana, N'Delitos cometidos por servidores públicos' AS subtipo_delito_sabana, N'Delitos cometidos por servidores públicos' AS modalidad_delito_sabana, 110 AS orden_general, 66 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Delitos contra la administración de justicia' AS delito_sabana, N'Delitos contra la administración de justicia' AS subtipo_delito_sabana, N'Delitos contra la administración de justicia' AS modalidad_delito_sabana, 112 AS orden_general, 82 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Electorales' AS delito_sabana, N'Electorales' AS subtipo_delito_sabana, N'Electorales' AS modalidad_delito_sabana, 111 AS orden_general, 67 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Evasión de presos' AS delito_sabana, N'Evasión de presos' AS subtipo_delito_sabana, N'Evasión de presos' AS modalidad_delito_sabana, 106 AS orden_general, 86 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Falsedad' AS delito_sabana, N'Falsedad' AS subtipo_delito_sabana, N'Falsedad' AS modalidad_delito_sabana, 107 AS orden_general, 68 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Falsificación' AS delito_sabana, N'Falsificación' AS subtipo_delito_sabana, N'Falsificación' AS modalidad_delito_sabana, 108 AS orden_general, 69 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Narcomenudeo' AS delito_sabana, N'Narcomenudeo con fines de venta' AS subtipo_delito_sabana, N'Narcomenudeo con fines de venta' AS modalidad_delito_sabana, 103 AS orden_general, 93 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Narcomenudeo' AS delito_sabana, N'Narcomenudeo posesión simple' AS subtipo_delito_sabana, N'Narcomenudeo posesión simple' AS modalidad_delito_sabana, 101 AS orden_general, 70 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Otros delitos del Fuero Común' AS delito_sabana, N'Otros delitos del Fuero Común' AS subtipo_delito_sabana, N'Otros delitos del Fuero Común' AS modalidad_delito_sabana, 102 AS orden_general, 71 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Suplantación y usurpación de identidad' AS delito_sabana, N'Suplantación y usurpación de identidad' AS subtipo_delito_sabana, N'Suplantación y usurpación de identidad' AS modalidad_delito_sabana, 113 AS orden_general, 72 AS orden_municipal_victimas
    UNION ALL
    SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Tortura' AS delito_sabana, N'Tortura' AS subtipo_delito_sabana, N'Tortura' AS modalidad_delito_sabana, 114 AS orden_general, 73 AS orden_municipal_victimas
) AS origen
ON destino.bien_juridico = origen.bien_juridico
AND destino.delito_sabana = origen.delito_sabana
AND destino.subtipo_delito_sabana = origen.subtipo_delito_sabana
AND destino.modalidad_delito_sabana = origen.modalidad_delito_sabana
WHEN MATCHED THEN
    UPDATE SET
        orden_general = origen.orden_general,
        orden_municipal_victimas = origen.orden_municipal_victimas,
        activo = 1
WHEN NOT MATCHED THEN
    INSERT (bien_juridico, delito_sabana, subtipo_delito_sabana, modalidad_delito_sabana, orden_general, orden_municipal_victimas, activo)
    VALUES (origen.bien_juridico, origen.delito_sabana, origen.subtipo_delito_sabana, origen.modalidad_delito_sabana, origen.orden_general, origen.orden_municipal_victimas, 1);
GO

GO

-- Fuente: indices y correcciones/20260805_edad_999.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.victima', N'edad') IS NULL
    THROW 50080, 'No existe dbo.victima.edad.', 1;

IF COL_LENGTH(N'dbo.victima_historico', N'edad') IS NULL
    THROW 50081, 'No existe dbo.victima_historico.edad.', 1;

IF COL_LENGTH(N'dbo.semanal_victima', N'edad') IS NULL
    THROW 50082, 'No existe dbo.semanal_victima.edad.', 1;

IF COL_LENGTH(N'dbo.semanal_victima_historico', N'edad') IS NULL
    THROW 50083, 'No existe dbo.semanal_victima_historico.edad.', 1;
GO

DECLARE @RecrearIndiceVictimaCarga BIT =
    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.victima')
          AND name = N'IX_victima_carga_activo_delito_identificador'
    ) THEN 1 ELSE 0 END;

DECLARE @RecrearIndiceVictimaSabanas BIT =
    CASE WHEN EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.victima')
          AND name = N'IX_victima_sabanas_carga_activo_delito'
    ) THEN 1 ELSE 0 END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF @RecrearIndiceVictimaCarga = 1
        DROP INDEX IX_victima_carga_activo_delito_identificador ON dbo.victima;

    IF @RecrearIndiceVictimaSabanas = 1
        DROP INDEX IX_victima_sabanas_carga_activo_delito ON dbo.victima;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.victima') AND name = N'edad' AND system_type_id <> TYPE_ID(N'smallint'))
        ALTER TABLE dbo.victima ALTER COLUMN edad SMALLINT NULL;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.victima_historico') AND name = N'edad' AND system_type_id <> TYPE_ID(N'smallint'))
        ALTER TABLE dbo.victima_historico ALTER COLUMN edad SMALLINT NULL;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.semanal_victima') AND name = N'edad' AND system_type_id <> TYPE_ID(N'smallint'))
        ALTER TABLE dbo.semanal_victima ALTER COLUMN edad SMALLINT NULL;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.semanal_victima_historico') AND name = N'edad' AND system_type_id <> TYPE_ID(N'smallint'))
        ALTER TABLE dbo.semanal_victima_historico ALTER COLUMN edad SMALLINT NULL;

    IF @RecrearIndiceVictimaCarga = 1
    BEGIN
        CREATE INDEX IX_victima_carga_activo_delito_identificador
        ON dbo.victima (
            id_carga,
            activo,
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
        );
    END;

    IF @RecrearIndiceVictimaSabanas = 1
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

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    OBJECT_SCHEMA_NAME(c.object_id) AS esquema,
    OBJECT_NAME(c.object_id) AS tabla,
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.victima'),
    OBJECT_ID(N'dbo.victima_historico'),
    OBJECT_ID(N'dbo.semanal_victima'),
    OBJECT_ID(N'dbo.semanal_victima_historico')
)
  AND c.name = N'edad'
ORDER BY tabla;
GO

GO

-- Fuente: indices y correcciones/20260806_notificaciones_rechazos.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.carga', N'U') IS NULL
    THROW 50090, 'No existe dbo.carga.', 1;

IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    THROW 50091, 'No existe dbo.semanal_carga.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH(N'dbo.carga', N'rechazo_visto') IS NULL
    BEGIN
        ALTER TABLE dbo.carga
        ADD rechazo_visto BIT NOT NULL CONSTRAINT DF_carga_rechazo_visto DEFAULT (1) WITH VALUES;
    END;

    IF COL_LENGTH(N'dbo.carga', N'fecha_rechazo_visto') IS NULL
    BEGIN
        ALTER TABLE dbo.carga
        ADD fecha_rechazo_visto DATETIME2(0) NULL;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga', N'rechazo_visto') IS NULL
    BEGIN
        ALTER TABLE dbo.semanal_carga
        ADD rechazo_visto BIT NOT NULL CONSTRAINT DF_semanal_carga_rechazo_visto DEFAULT (1) WITH VALUES;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga', N'fecha_rechazo_visto') IS NULL
    BEGIN
        ALTER TABLE dbo.semanal_carga
        ADD fecha_rechazo_visto DATETIME2(0) NULL;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    OBJECT_NAME(c.object_id) AS tabla,
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id IN (OBJECT_ID(N'dbo.carga'), OBJECT_ID(N'dbo.semanal_carga'))
  AND c.name IN (N'rechazo_visto', N'fecha_rechazo_visto')
ORDER BY tabla, columna;
GO

GO

-- Fuente: indices y correcciones/20260810_usuario_rfc_curp_opcionales.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF OBJECT_ID(N'dbo.usuario', N'U') IS NULL
    THROW 50100, 'No existe dbo.usuario.', 1;

IF COL_LENGTH(N'dbo.usuario', N'rfc') IS NULL
    THROW 50101, 'No existe dbo.usuario.rfc.', 1;

IF COL_LENGTH(N'dbo.usuario', N'curp') IS NULL
    THROW 50102, 'No existe dbo.usuario.curp.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'uk_usuario_rfc'
    )
        ALTER TABLE dbo.usuario DROP CONSTRAINT [uk_usuario_rfc];

    IF EXISTS (
        SELECT 1
        FROM sys.key_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'uk_usuario_curp'
    )
        ALTER TABLE dbo.usuario DROP CONSTRAINT [uk_usuario_curp];

    IF EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'rfc'
          AND is_nullable = 0
    )
        ALTER TABLE dbo.usuario ALTER COLUMN rfc NVARCHAR(13) NULL;

    IF EXISTS (
        SELECT 1
        FROM sys.columns
        WHERE object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'curp'
          AND is_nullable = 0
    )
        ALTER TABLE dbo.usuario ALTER COLUMN curp NVARCHAR(18) NULL;

    UPDATE dbo.usuario
    SET rfc = NULL
    WHERE rfc IS NOT NULL
      AND LTRIM(RTRIM(rfc)) = N'';

    UPDATE dbo.usuario
    SET curp = NULL
    WHERE curp IS NOT NULL
      AND LTRIM(RTRIM(curp)) = N'';

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'ux_usuario_rfc_no_nulo'
    )
        CREATE UNIQUE INDEX [ux_usuario_rfc_no_nulo]
        ON dbo.usuario (rfc)
        WHERE rfc IS NOT NULL;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.usuario')
          AND name = N'ux_usuario_curp_no_nulo'
    )
        CREATE UNIQUE INDEX [ux_usuario_curp_no_nulo]
        ON dbo.usuario (curp)
        WHERE curp IS NOT NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.max_length / 2 AS longitud,
    c.is_nullable
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(N'dbo.usuario')
  AND c.name IN (N'rfc', N'curp')
ORDER BY c.name;

SELECT
    i.name AS indice,
    i.is_unique,
    i.has_filter,
    i.filter_definition
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID(N'dbo.usuario')
  AND i.name IN (
      N'ux_usuario_rfc_no_nulo',
      N'ux_usuario_curp_no_nulo'
  )
ORDER BY i.name;
GO

GO

-- Fuente: indices y correcciones/20260811_extorsion_denuncia_anonima_semanal.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_carpeta', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carpeta_investigacion', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carpeta_investigacion_historico', N'U') IS NULL
    BEGIN
        THROW 50010, 'No se encontró la estructura completa del módulo semanal.', 1;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga_tmp_carpeta', N'denuncia_anonima') IS NULL ALTER TABLE dbo.semanal_carga_tmp_carpeta ADD denuncia_anonima NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carga_tmp_carpeta', N'denuncia_anonima_089') IS NULL ALTER TABLE dbo.semanal_carga_tmp_carpeta ADD denuncia_anonima_089 NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carga_tmp_carpeta', N'denuncia_anonima_otro_medio') IS NULL ALTER TABLE dbo.semanal_carga_tmp_carpeta ADD denuncia_anonima_otro_medio NVARCHAR(500) NULL;

    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion', N'denuncia_anonima') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion ADD denuncia_anonima NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion', N'denuncia_anonima_089') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion ADD denuncia_anonima_089 NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion', N'denuncia_anonima_otro_medio') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion ADD denuncia_anonima_otro_medio NVARCHAR(500) NULL;

    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion_historico', N'denuncia_anonima') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion_historico ADD denuncia_anonima NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion_historico', N'denuncia_anonima_089') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion_historico ADD denuncia_anonima_089 NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion_historico', N'denuncia_anonima_otro_medio') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion_historico ADD denuncia_anonima_otro_medio NVARCHAR(500) NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    OBJECT_NAME(c.object_id) AS tabla,
    c.name AS columna,
    t.name AS tipo,
    c.max_length,
    c.is_nullable
FROM sys.columns c
INNER JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.semanal_carga_tmp_carpeta'),
    OBJECT_ID(N'dbo.semanal_carpeta_investigacion'),
    OBJECT_ID(N'dbo.semanal_carpeta_investigacion_historico')
)
AND c.name IN (N'denuncia_anonima', N'denuncia_anonima_089', N'denuncia_anonima_otro_medio')
ORDER BY tabla, c.column_id;
GO

GO

-- Fuente: indices y correcciones/20260811_separar_carga_semanal_por_delito.sql
USE siiid2;
GO

IF COL_LENGTH(N'dbo.semanal_carga', N'id_delito') IS NULL
BEGIN
    ALTER TABLE dbo.semanal_carga ADD id_delito INT NULL;
END;
GO

SELECT COL_LENGTH(N'dbo.semanal_carga', N'id_delito') AS columna_creada;
GO


USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 50010, 'No existe la tabla dbo.semanal_carga.', 1;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga', N'id_delito') IS NULL
    BEGIN
        ALTER TABLE dbo.semanal_carga ADD id_delito INT NULL;
    END;

    ;WITH DelitosPorCarga AS
    (
        SELECT
            origen.id_semanal_carga,
            MIN(origen.id_delito) AS id_delito,
            COUNT(*) AS cantidad_delitos
        FROM
        (
            SELECT DISTINCT
                d.id_semanal_carga,
                d.id_catalogo_delito AS id_delito
            FROM dbo.semanal_delito d
            WHERE d.id_catalogo_delito IS NOT NULL

            UNION

            SELECT DISTINCT
                tmp.id_semanal_carga,
                sd.id_delito
            FROM dbo.semanal_carga_tmp_delito tmp
            INNER JOIN dbo.catalogo_modalidad_delito md ON md.clave4 = LTRIM(RTRIM(tmp.clasf_de_dto))
            INNER JOIN dbo.catalogo_subtipo_delito sd ON sd.id_subtipo_delito = md.id_subtipo_delito
            WHERE tmp.incluido = 1
              AND tmp.activo = 1
        ) origen
        GROUP BY origen.id_semanal_carga
    )
    UPDATE sc
    SET id_delito = delitos.id_delito
    FROM dbo.semanal_carga sc
    INNER JOIN DelitosPorCarga delitos ON delitos.id_semanal_carga = sc.id_semanal_carga
    WHERE sc.id_delito IS NULL
      AND delitos.cantidad_delitos = 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_semanal_carga_catalogo_delito'
          AND parent_object_id = OBJECT_ID(N'dbo.semanal_carga')
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga WITH CHECK
        ADD CONSTRAINT FK_semanal_carga_catalogo_delito
        FOREIGN KEY (id_delito) REFERENCES dbo.catalogo_delito(id_delito);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
          AND name = N'IX_semanal_carga_identidad_delito'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_semanal_carga_identidad_delito
        ON dbo.semanal_carga
        (
            id_entidad_federativa,
            id_usuario_carga,
            id_delito,
            estado,
            activo
        )
        INCLUDE
        (
            id_semanal_carga,
            codigo_referencia,
            fecha_validacion,
            fecha_confirmacion
        );
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    sc.id_semanal_carga,
    sc.codigo_referencia,
    sc.tipo_carga,
    sc.estado,
    sc.id_delito,
    cd.delito
FROM dbo.semanal_carga sc
LEFT JOIN dbo.catalogo_delito cd ON cd.id_delito = sc.id_delito
WHERE sc.activo = 1
ORDER BY sc.id_semanal_carga DESC;
GO

GO

-- Fuente: indices y correcciones/20260823_optimizacion_reportes_diferencias.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    Script idempotente y no destructivo.

    Afecta únicamente índices de:
    - dbo.semanal_carga
    - dbo.semanal_carga_bloque

    No inserta, actualiza ni elimina datos.
*/

IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
         AND name = N'IX_semanal_carga_reporte_cargas'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_semanal_carga_reporte_cargas
    ON dbo.semanal_carga
    (
        id_entidad_federativa,
        id_usuario_carga,
        id_delito,
        anio_corte,
        mes_corte,
        fecha_inicio_semana,
        fecha_fin_semana,
        id_semanal_carga
    )
    INCLUDE
    (
        codigo_referencia,
        tipo_carga,
        estado,
        fecha_carga,
        fecha_validacion,
        fecha_confirmacion
    )
    WHERE activo = 1
      AND id_entidad_federativa IS NOT NULL
      AND id_delito IS NOT NULL;
END;
GO

IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1
       FROM sys.indexes
       WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
         AND name = N'IX_semanal_carga_bloque_carga_activo_reporte'
   )
BEGIN
    CREATE NONCLUSTERED INDEX IX_semanal_carga_bloque_carga_activo_reporte
    ON dbo.semanal_carga_bloque
    (
        id_semanal_carga,
        activo
    )
    INCLUDE
    (
        id_entidad_federativa,
        fecha_inicio_semana,
        fecha_fin_semana,
        fecha_inicio_tramo,
        fecha_fin_tramo,
        anio_corte,
        mes_corte,
        reemplaza_informacion
    );
END;
GO

PRINT N'Índices para reporte de cargas y diferencias preliminares verificados correctamente.';
GO


GO

-- Fuente: indices y correcciones/20260910_feminicidio_victimas_consolidado.sql
USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME() <> N'siiid2'
BEGIN
    THROW 55001, 'El script debe ejecutarse en la base siiid2.', 1;
END;
GO

/* ============================================================
   FEMINICIDIO - NUEVAS VARIABLES DE VICTIMAS
   SOLO MODULO CONSOLIDADO / MENSUAL DE FUERO COMUN
   ============================================================ */

/* ---------- STAGING ---------- */

IF COL_LENGTH(N'dbo.carga_tmp_victima', N'nombre_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.carga_tmp_victima
    ADD nombre_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.carga_tmp_victima', N'primer_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.carga_tmp_victima
    ADD primer_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.carga_tmp_victima', N'segundo_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.carga_tmp_victima
    ADD segundo_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.carga_tmp_victima', N'curp_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.carga_tmp_victima
    ADD curp_vicfem NVARCHAR(250) NULL;
END;
GO

/* ---------- INFORMACION CONFIRMADA ---------- */

IF COL_LENGTH(N'dbo.victima', N'nombre_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima
    ADD nombre_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima', N'primer_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima
    ADD primer_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima', N'segundo_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima
    ADD segundo_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima', N'curp_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima
    ADD curp_vicfem NVARCHAR(250) NULL;
END;
GO

/* ---------- HISTORICO ---------- */

IF COL_LENGTH(N'dbo.victima_historico', N'nombre_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima_historico
    ADD nombre_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima_historico', N'primer_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima_historico
    ADD primer_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima_historico', N'segundo_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima_historico
    ADD segundo_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima_historico', N'curp_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima_historico
    ADD curp_vicfem NVARCHAR(250) NULL;
END;
GO

/* ---------- VERIFICACION ---------- */

SELECT
    t.name AS tabla,
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.max_length,
    c.is_nullable
FROM sys.tables t
INNER JOIN sys.columns c
    ON c.object_id = t.object_id
WHERE t.name IN
(
    N'carga_tmp_victima',
    N'victima',
    N'victima_historico'
)
AND c.name IN
(
    N'nombre_vicfem',
    N'primer_apellido_vicfem',
    N'segundo_apellido_vicfem',
    N'curp_vicfem'
)
ORDER BY
    t.name,
    c.column_id;
GO

GO

-- Fuente: indices y correcciones/ajuste_orden_municipal_victimas.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @EjecutarAjuste BIT = 0; -- 0 = prueba con ROLLBACK, 1 = aplica con COMMIT

BEGIN TRY
    BEGIN TRANSACTION;

    ;WITH orden AS (
        SELECT N'El patrimonio' AS bien_juridico, N'Abuso de confianza' AS delito_sabana, N'Abuso de confianza' AS subtipo_delito_sabana, N'Abuso de confianza' AS modalidad_delito_sabana, 1 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Daño a la propiedad' AS delito_sabana, N'Daño a la propiedad' AS subtipo_delito_sabana, N'Daño a la propiedad' AS modalidad_delito_sabana, 2 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Despojo' AS delito_sabana, N'Despojo' AS subtipo_delito_sabana, N'Despojo' AS modalidad_delito_sabana, 3 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Extorsión por otros medios' AS subtipo_delito_sabana, N'Extorsión por otros medios' AS modalidad_delito_sabana, 4 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Extorsión presencial' AS subtipo_delito_sabana, N'Extorsión presencial' AS modalidad_delito_sabana, 5 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Tentativa de extorsión por otros medios' AS subtipo_delito_sabana, N'Tentativa de extorsión por otros medios' AS modalidad_delito_sabana, 6 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Tentativa de extorsión presencial' AS subtipo_delito_sabana, N'Tentativa de extorsión presencial' AS modalidad_delito_sabana, 7 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Fraude' AS delito_sabana, N'Fraude' AS subtipo_delito_sabana, N'Fraude' AS modalidad_delito_sabana, 8 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Otros delitos contra el patrimonio' AS delito_sabana, N'Otros delitos contra el patrimonio' AS subtipo_delito_sabana, N'Otros delitos contra el patrimonio' AS modalidad_delito_sabana, 9 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Otros robos' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 10 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Otros robos' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 11 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a casa habitación' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 12 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a casa habitación' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 13 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a institución bancaria' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 14 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a institución bancaria' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 15 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a negocio' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 16 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a negocio' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 17 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en espacio abierto al público' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 18 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en espacio abierto al público' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 19 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en vía pública' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 20 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en vía pública' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 21 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transportista' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 22 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transportista' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 23 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de autopartes' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 24 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de autopartes' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 25 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de ganado' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 26 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de ganado' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 27 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Cables, tubos y otros objetos destinados a servicios públicos' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 28 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Cables, tubos y otros objetos destinados a servicios públicos' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 29 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Herramienta industrial o agrícola' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 30 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Herramienta industrial o agrícola' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 31 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Tractores y/o montacargas' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 32 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Tractores y/o montacargas' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 33 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Coche de 4 ruedas' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 34 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Coche de 4 ruedas' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 35 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Embarcaciones' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 36 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Embarcaciones' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 37 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Motocicleta' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 38 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Motocicleta' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 39 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte individual' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 40 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte individual' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 41 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público colectivo' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 42 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público colectivo' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 43 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público individual' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 44 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público individual' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 45 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La familia' AS bien_juridico, N'Incumplimiento de obligaciones de asistencia familiar' AS delito_sabana, N'Incumplimiento de obligaciones de asistencia familiar' AS subtipo_delito_sabana, N'Incumplimiento de obligaciones de asistencia familiar' AS modalidad_delito_sabana, 46 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La familia' AS bien_juridico, N'Otros delitos contra la familia' AS delito_sabana, N'Otros delitos contra la familia' AS subtipo_delito_sabana, N'Otros delitos contra la familia' AS modalidad_delito_sabana, 47 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La familia' AS bien_juridico, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS delito_sabana, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS subtipo_delito_sabana, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS modalidad_delito_sabana, 48 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La familia' AS bien_juridico, N'Violencia familiar' AS delito_sabana, N'Violencia familiar' AS subtipo_delito_sabana, N'Violencia familiar' AS modalidad_delito_sabana, 49 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Abuso sexual' AS delito_sabana, N'Abuso sexual' AS subtipo_delito_sabana, N'Abuso sexual' AS modalidad_delito_sabana, 50 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Acoso sexual' AS delito_sabana, N'Acoso sexual' AS subtipo_delito_sabana, N'Acoso sexual' AS modalidad_delito_sabana, 51 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Hostigamiento sexual' AS delito_sabana, N'Hostigamiento sexual' AS subtipo_delito_sabana, N'Hostigamiento sexual' AS modalidad_delito_sabana, 52 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Incesto' AS delito_sabana, N'Incesto' AS subtipo_delito_sabana, N'Incesto' AS modalidad_delito_sabana, 53 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS delito_sabana, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS modalidad_delito_sabana, 54 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación' AS delito_sabana, N'Violación equiparada' AS subtipo_delito_sabana, N'Violación equiparada' AS modalidad_delito_sabana, 55 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación' AS delito_sabana, N'Violación simple' AS subtipo_delito_sabana, N'Violación simple' AS modalidad_delito_sabana, 56 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación a la intimidad sexual' AS delito_sabana, N'Violación a la intimidad sexual' AS subtipo_delito_sabana, N'Violación a la intimidad sexual' AS modalidad_delito_sabana, 57 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Corrupción de menores' AS delito_sabana, N'Corrupción de menores' AS subtipo_delito_sabana, N'Corrupción de menores' AS modalidad_delito_sabana, 58 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Discriminación' AS delito_sabana, N'Discriminación' AS subtipo_delito_sabana, N'Discriminación' AS modalidad_delito_sabana, 59 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Otros delitos contra la sociedad' AS delito_sabana, N'Otros delitos contra la sociedad' AS subtipo_delito_sabana, N'Otros delitos contra la sociedad' AS modalidad_delito_sabana, 60 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Pornografía infantil' AS delito_sabana, N'Pornografía infantil' AS subtipo_delito_sabana, N'Pornografía infantil' AS modalidad_delito_sabana, 61 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de explotación sexual' AS subtipo_delito_sabana, N'Trata de personas con fines de explotación sexual' AS modalidad_delito_sabana, 62 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de trabajo o servicios forzados' AS subtipo_delito_sabana, N'Trata de personas con fines de trabajo o servicios forzados' AS modalidad_delito_sabana, 63 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de tráfico de órganos' AS subtipo_delito_sabana, N'Trata de personas con fines de tráfico de órganos' AS modalidad_delito_sabana, 64 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con otros fines' AS subtipo_delito_sabana, N'Trata de personas con otros fines' AS modalidad_delito_sabana, 65 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Aborto' AS delito_sabana, N'Aborto' AS subtipo_delito_sabana, N'Aborto' AS modalidad_delito_sabana, 66 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 67 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 68 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 69 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 70 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Tentativa de feminicidio' AS subtipo_delito_sabana, N'Tentativa de feminicidio' AS modalidad_delito_sabana, 71 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 72 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 73 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 74 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'En accidente de tránsito' AS modalidad_delito_sabana, 75 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 76 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 77 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 78 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 79 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 80 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Tentativa de homicidio doloso' AS subtipo_delito_sabana, N'Tentativa de homicidio doloso' AS modalidad_delito_sabana, 81 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 82 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 83 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 84 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'En accidente de tránsito' AS modalidad_delito_sabana, 85 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 86 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 87 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 88 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 89 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 90 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Otros delitos que atentan contra la vida y la integridad corporal' AS delito_sabana, N'Otros delitos que atentan contra la vida y la integridad corporal' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la vida y la integridad corporal' AS modalidad_delito_sabana, 91 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Otros delitos que atentan contra la libertad personal' AS delito_sabana, N'Otros delitos que atentan contra la libertad personal' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la libertad personal' AS modalidad_delito_sabana, 92 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Privación ilegal de la libertad' AS delito_sabana, N'Privación ilegal de la libertad' AS subtipo_delito_sabana, N'Privación ilegal de la libertad' AS modalidad_delito_sabana, 93 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Rapto' AS delito_sabana, N'Rapto' AS subtipo_delito_sabana, N'Rapto' AS modalidad_delito_sabana, 94 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Retención o sustracción de menores e incapaces' AS delito_sabana, N'Retención o sustracción de menores e incapaces' AS subtipo_delito_sabana, N'Retención o sustracción de menores e incapaces' AS modalidad_delito_sabana, 95 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro con calidad de rehén' AS subtipo_delito_sabana, N'Secuestro con calidad de rehén' AS modalidad_delito_sabana, 96 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro exprés' AS subtipo_delito_sabana, N'Secuestro exprés' AS modalidad_delito_sabana, 97 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro extorsivo' AS subtipo_delito_sabana, N'Secuestro extorsivo' AS modalidad_delito_sabana, 98 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro para causar daño' AS subtipo_delito_sabana, N'Secuestro para causar daño' AS modalidad_delito_sabana, 99 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Tráfico de menores' AS delito_sabana, N'Tráfico de menores' AS subtipo_delito_sabana, N'Tráfico de menores' AS modalidad_delito_sabana, 100 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Allanamiento de morada' AS delito_sabana, N'Allanamiento de morada' AS subtipo_delito_sabana, N'Allanamiento de morada' AS modalidad_delito_sabana, 101 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Amenazas' AS delito_sabana, N'Amenazas' AS subtipo_delito_sabana, N'Amenazas' AS modalidad_delito_sabana, 102 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Contra el medio ambiente' AS delito_sabana, N'Contra el medio ambiente' AS subtipo_delito_sabana, N'Contra el medio ambiente' AS modalidad_delito_sabana, 103 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Delitos cometidos por servidores públicos' AS delito_sabana, N'Delitos cometidos por servidores públicos' AS subtipo_delito_sabana, N'Delitos cometidos por servidores públicos' AS modalidad_delito_sabana, 104 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Delitos contra la administración de justicia' AS delito_sabana, N'Delitos contra la administración de justicia' AS subtipo_delito_sabana, N'Delitos contra la administración de justicia' AS modalidad_delito_sabana, 105 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Electorales' AS delito_sabana, N'Electorales' AS subtipo_delito_sabana, N'Electorales' AS modalidad_delito_sabana, 106 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Evasión de presos' AS delito_sabana, N'Evasión de presos' AS subtipo_delito_sabana, N'Evasión de presos' AS modalidad_delito_sabana, 107 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Falsedad' AS delito_sabana, N'Falsedad' AS subtipo_delito_sabana, N'Falsedad' AS modalidad_delito_sabana, 108 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Falsificación' AS delito_sabana, N'Falsificación' AS subtipo_delito_sabana, N'Falsificación' AS modalidad_delito_sabana, 109 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Narcomenudeo' AS delito_sabana, N'Narcomenudeo con fines de venta' AS subtipo_delito_sabana, N'Narcomenudeo con fines de venta' AS modalidad_delito_sabana, 110 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Narcomenudeo' AS delito_sabana, N'Narcomenudeo posesión simple' AS subtipo_delito_sabana, N'Narcomenudeo posesión simple' AS modalidad_delito_sabana, 111 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Otros delitos del Fuero Común' AS delito_sabana, N'Otros delitos del Fuero Común' AS subtipo_delito_sabana, N'Otros delitos del Fuero Común' AS modalidad_delito_sabana, 112 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Suplantación y usurpación de identidad' AS delito_sabana, N'Suplantación y usurpación de identidad' AS subtipo_delito_sabana, N'Suplantación y usurpación de identidad' AS modalidad_delito_sabana, 113 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Tortura' AS delito_sabana, N'Tortura' AS subtipo_delito_sabana, N'Tortura' AS modalidad_delito_sabana, 114 AS orden_municipal_victimas
    )
    UPDATE ol
    SET orden_municipal_victimas = o.orden_municipal_victimas
    FROM dbo.catalogo_sabana_orden_legacy ol
    INNER JOIN orden o
        ON o.bien_juridico = ol.bien_juridico
       AND o.delito_sabana = ol.delito_sabana
       AND o.subtipo_delito_sabana = ol.subtipo_delito_sabana
       AND o.modalidad_delito_sabana = ol.modalidad_delito_sabana
    WHERE ol.activo = 1
      AND ISNULL(ol.orden_municipal_victimas, -1) <> o.orden_municipal_victimas;

    PRINT CONCAT('Renglones actualizados: ', @@ROWCOUNT);

    IF @EjecutarAjuste = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Ajuste aplicado con COMMIT.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Prueba terminada con ROLLBACK. Cambia @EjecutarAjuste = 1 para aplicar.';
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@MensajeError, 16, 1);
END CATCH;
GO

GO

-- Fuente: indices y correcciones/codigo_postal_fiscalia y tamaño de localidad.sql
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

GO

-- Fuente: indices y correcciones/correccionMunicipio.sql
SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @Viejo TABLE (
    id_entidad_federativa int NOT NULL,
    clave_municipio int NOT NULL,
    nombre_viejo nvarchar(255) NOT NULL
);

INSERT INTO @Viejo (id_entidad_federativa, clave_municipio, nombre_viejo)
VALUES
    (7, 72, N'Pueblo Nuevo Solistahuacá'),
    (7, 78, N'San Cristóbal de las Casa'),
    (7, 114, N'Benemérito de las América'),
    (8, 8, N'Batopilas de Manuel Gómez'),
    (8, 56, N'Rosario'),
    (11, 14, N'Dolores Hidalgo Cuna de l'),
    (11, 32, N'San José Iturbide'),
    (11, 35, N'Santa Cruz de Juventino R'),
    (12, 6, N'Apaxtla'),
    (12, 16, N'Coahuayutla de José María'),
    (12, 32, N'General Heliodoro Castill'),
    (12, 35, N'Iguala de la Independenci'),
    (12, 65, N'Tlalixtaquilla de Maldona'),
    (12, 68, N'La Unión de Isidoro Monte'),
    (13, 56, N'Santiago Tulantepec de Lu'),
    (14, 26, N'Concepción de Buenos Aire'),
    (14, 27, N'Cuautitlán de García Barr'),
    (14, 44, N'Ixtlahuacán de los Membri'),
    (14, 71, N'San Cristóbal de la Barra'),
    (14, 81, N'Santa María de los Ángele'),
    (14, 118, N'Yahualica de González Gal'),
    (15, 75, N'San Martín de las Pirámid'),
    (15, 122, N'Valle de Chalco Solidarid'),
    (16, 15, N'Coalcomán de Vázquez Pall'),
    (16, 92, N'Tiquicheo de Nicolás Rome'),
    (17, 13, N'Jonacatepec de Leandro Va'),
    (20, 24, N'Cuyamecalco Villa de Zara'),
    (20, 27, N'Chiquihuitlán de Benito J'),
    (20, 28, N'Heroica Ciudad de Ejutla '),
    (20, 29, N'Eloxochitlán de Flores Ma'),
    (20, 31, N'Tamazulápam del Espíritu '),
    (20, 39, N'Heroica Ciudad de Huajuap'),
    (20, 43, N'Heroica Ciudad de Juchitá'),
    (20, 59, N'Miahuatlán de Porfirio Dí'),
    (20, 74, N'Santa Catarina Quioquitan'),
    (20, 103, N'San Antonino Castillo Vel'),
    (20, 114, N'San Baltazar Yatzachi el '),
    (20, 124, N'Heroica Villa de San Blas'),
    (20, 129, N'San Cristóbal Suchixtlahu'),
    (20, 144, N'San Francisco Jaltepetong'),
    (20, 150, N'San Francisco Telixtlahua'),
    (20, 160, N'San Jerónimo Silacayoapil'),
    (20, 175, N'San Juan Bautista Atatlah'),
    (20, 176, N'San Juan Bautista Coixtla'),
    (20, 177, N'San Juan Bautista Cuicatl'),
    (20, 178, N'San Juan Bautista Guelach'),
    (20, 179, N'San Juan Bautista Jayacat'),
    (20, 180, N'San Juan Bautista Lo de S'),
    (20, 181, N'San Juan Bautista Suchite'),
    (20, 182, N'San Juan Bautista Tlacoat'),
    (20, 183, N'San Juan Bautista Tlachic'),
    (20, 184, N'San Juan Bautista Tuxtepe'),
    (20, 196, N'San Juan Evangelista Anal'),
    (20, 228, N'San Lorenzo Cuaunecuiltit'),
    (20, 238, N'Heroico San Martín de los'),
    (20, 304, N'San Pedro Coxcaltepec Cán'),
    (20, 316, N'San Pedro Mártir Quiechap'),
    (20, 337, N'San Pedro y San Pablo Ayu'),
    (20, 339, N'San Pedro y San Pablo Tep'),
    (20, 340, N'San Pedro y San Pablo Teq'),
    (20, 348, N'San Sebastián Tecomaxtlah'),
    (20, 381, N'Santa Cruz Tacache de Min'),
    (20, 397, N'Heroica Ciudad de Tlaxiac'),
    (20, 418, N'Santa María Jalapa del Ma'),
    (20, 437, N'Santa María Tlahuitoltepe'),
    (20, 459, N'Villa de Santiago Chazumb'),
    (20, 482, N'Santiago Pinotepa Naciona'),
    (20, 540, N'Villa de Tamazulápam del '),
    (20, 544, N'Teococuilco de Marcos Pér'),
    (20, 548, N'Tepelmeme Villa de Morelo'),
    (20, 549, N'Heroica Villa Tezoatlán d'),
    (20, 550, N'San Jerónimo Tlacochahuay'),
    (20, 554, N'Totontepec Villa de Morel'),
    (20, 559, N'San Juan Bautista Valle N'),
    (20, 562, N'Magdalena Yodocono de Por'),
    (21, 95, N'La Magdalena Tlatlauquite'),
    (21, 121, N'San Diego la Mesa Tochimi'),
    (21, 138, N'San Nicolás de los Rancho'),
    (21, 171, N'Tepeyahualco de Cuauhtémo'),
    (21, 177, N'Tlacotepec de Benito Juár'),
    (21, 202, N'Xochitlán de Vicente Suár'),
    (23, 8, N'Solidaridad'),
    (24, 35, N'Soledad de Graciano Sánch'),
    (26, 70, N'General Plutarco Elías Ca'),
    (29, 2, N'Apetatitlán de Antonio Ca'),
    (29, 15, N'Ixtacuixtla de Mariano Ma'),
    (29, 17, N'Mazatecochco de José Marí'),
    (29, 20, N'Sanctórum de Lázaro Cárde'),
    (29, 21, N'Nanacamilpa de Mariano Ar'),
    (29, 22, N'Acuamanala de Miguel Hida'),
    (29, 37, N'Ziltlaltépec de Trinidad '),
    (30, 9, N'Alto Lucero de Gutiérrez '),
    (30, 202, N'Zontecomatlán de López y '),
    (30, 206, N'Nanchital de Lázaro Cárde'),
    (32, 6, N'Cañitas de Felipe Pescado'),
    (32, 11, N'Trinidad García de la Cad'),
    (32, 14, N'General Francisco R. Murg'),
    (32, 15, N'El Plateado de Joaquín Am'),
    (32, 48, N'Tlaltenango de Sánchez Ro');

UPDATE m
SET m.nombre = v.nombre_viejo
FROM catalogo_municipio m
INNER JOIN @Viejo v
    ON v.id_entidad_federativa = m.id_entidad_federativa
   AND v.clave_municipio = TRY_CONVERT(int, m.clave)
WHERE ISNULL(m.nombre, N'') <> v.nombre_viejo;

-- Sobran contra el catálogo viejo: se desactivan.
UPDATE catalogo_municipio
SET activo = 0
WHERE id_entidad_federativa = 33
  AND TRY_CONVERT(int, clave) = 999
  AND nombre = N'No especificado';

UPDATE catalogo_municipio
SET activo = 0
WHERE id_entidad_federativa = 23
  AND TRY_CONVERT(int, clave) = 122
  AND nombre = N'Solidaridad';

COMMIT;


SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @MunicipiosExcel TABLE (
    id_entidad_federativa int NOT NULL,
    clave_municipio int NOT NULL,
    nombre_excel nvarchar(255) NOT NULL
);

INSERT INTO @MunicipiosExcel (id_entidad_federativa, clave_municipio, nombre_excel)
VALUES
    (7, 72, N'Pueblo Nuevo Solistahuacán'), -- 7072: Pueblo Nuevo Solistahuacá -> Pueblo Nuevo Solistahuacán
    (7, 78, N'San Cristóbal de las Casas'), -- 7078: San Cristóbal de las Casa -> San Cristóbal de las Casas
    (7, 114, N'Benemérito de las Américas'), -- 7114: Benemérito de las América -> Benemérito de las Américas
    (8, 8, N'Batopilas de Manuel Gómez Morín'), -- 8008: Batopilas de Manuel Gómez -> Batopilas de Manuel Gómez Morín
    (8, 56, N'Valle del Rosario'), -- 8056: Rosario -> Valle del Rosario
    (11, 14, N'Dolores Hidalgo Cuna de la Independencia Nacional'), -- 11014: Dolores Hidalgo Cuna de l -> Dolores Hidalgo Cuna de la Independencia Nacional
    (11, 32, N'San José de Iturbide'), -- 11032: San José Iturbide -> San José de Iturbide
    (11, 35, N'Santa Cruz de Juventino Rosas'), -- 11035: Santa Cruz de Juventino R -> Santa Cruz de Juventino Rosas
    (12, 6, N'Apaxtla de Castrejón'), -- 12006: Apaxtla -> Apaxtla de Castrejón
    (12, 16, N'Coahuayutla de José María Izazaga'), -- 12016: Coahuayutla de José María -> Coahuayutla de José María Izazaga
    (12, 32, N'General Heliodoro Castillo'), -- 12032: General Heliodoro Castill -> General Heliodoro Castillo
    (12, 35, N'Iguala de la Independencia'), -- 12035: Iguala de la Independenci -> Iguala de la Independencia
    (12, 65, N'Tlalixtaquilla de Maldonado'), -- 12065: Tlalixtaquilla de Maldona -> Tlalixtaquilla de Maldonado
    (12, 68, N'La Unión de Isidoro Montes de Oca'), -- 12068: La Unión de Isidoro Monte -> La Unión de Isidoro Montes de Oca
    (13, 56, N'Santiago Tulantepec de Lugo Guerrero'), -- 13056: Santiago Tulantepec de Lu -> Santiago Tulantepec de Lugo Guerrero
    (14, 26, N'Concepción de Buenos Aires'), -- 14026: Concepción de Buenos Aire -> Concepción de Buenos Aires
    (14, 27, N'Cuautitlán de García Barragán'), -- 14027: Cuautitlán de García Barr -> Cuautitlán de García Barragán
    (14, 44, N'Ixtlahuacán de los Membrillos'), -- 14044: Ixtlahuacán de los Membri -> Ixtlahuacán de los Membrillos
    (14, 71, N'San Cristóbal de la Barranca'), -- 14071: San Cristóbal de la Barra -> San Cristóbal de la Barranca
    (14, 81, N'Santa María de los Ángeles'), -- 14081: Santa María de los Ángele -> Santa María de los Ángeles
    (14, 118, N'Yahualica de González Gallo'), -- 14118: Yahualica de González Gal -> Yahualica de González Gallo
    (15, 75, N'San Martín de las Pirámides'), -- 15075: San Martín de las Pirámid -> San Martín de las Pirámides
    (15, 122, N'Valle de Chalco Solidaridad'), -- 15122: Valle de Chalco Solidarid -> Valle de Chalco Solidaridad
    (16, 15, N'Coalcomán de Vázquez Pallares'), -- 16015: Coalcomán de Vázquez Pall -> Coalcomán de Vázquez Pallares
    (16, 92, N'Tiquicheo de Nicolás Romero'), -- 16092: Tiquicheo de Nicolás Rome -> Tiquicheo de Nicolás Romero
    (17, 13, N'Jonacatepec de Leandro Valle'), -- 17013: Jonacatepec de Leandro Va -> Jonacatepec de Leandro Valle
    (20, 24, N'Cuyamecalco Villa de Zaragoza'), -- 20024: Cuyamecalco Villa de Zara -> Cuyamecalco Villa de Zaragoza
    (20, 27, N'Chiquihuitlán de Benito Juárez'), -- 20027: Chiquihuitlán de Benito J -> Chiquihuitlán de Benito Juárez
    (20, 28, N'Heroica Ciudad de Ejutla de Crespo'), -- 20028: Heroica Ciudad de Ejutla  -> Heroica Ciudad de Ejutla de Crespo
    (20, 29, N'Eloxochitlán de Flores Magón'), -- 20029: Eloxochitlán de Flores Ma -> Eloxochitlán de Flores Magón
    (20, 31, N'Tamazulápam del Espíritu Santo'), -- 20031: Tamazulápam del Espíritu  -> Tamazulápam del Espíritu Santo
    (20, 39, N'Heroica Ciudad de Huajuapan de León'), -- 20039: Heroica Ciudad de Huajuap -> Heroica Ciudad de Huajuapan de León
    (20, 43, N'Heroica Ciudad de Juchitán de Zaragoza'), -- 20043: Heroica Ciudad de Juchitá -> Heroica Ciudad de Juchitán de Zaragoza
    (20, 59, N'Heroica Ciudad de Miahuatlán de Porfirio Díaz'), -- 20059: Miahuatlán de Porfirio Dí -> Heroica Ciudad de Miahuatlán de Porfirio Díaz
    (20, 74, N'Santa Catarina Quioquitani'), -- 20074: Santa Catarina Quioquitan -> Santa Catarina Quioquitani
    (20, 103, N'San Antonino Castillo Velasco'), -- 20103: San Antonino Castillo Vel -> San Antonino Castillo Velasco
    (20, 114, N'San Baltazar Yatzachi el Bajo'), -- 20114: San Baltazar Yatzachi el  -> San Baltazar Yatzachi el Bajo
    (20, 124, N'Heroica Villa de San Blas Atempa'), -- 20124: Heroica Villa de San Blas -> Heroica Villa de San Blas Atempa
    (20, 129, N'San Cristóbal Suchixtlahuaca'), -- 20129: San Cristóbal Suchixtlahu -> San Cristóbal Suchixtlahuaca
    (20, 144, N'San Francisco Jaltepetongo'), -- 20144: San Francisco Jaltepetong -> San Francisco Jaltepetongo
    (20, 150, N'San Francisco Telixtlahuaca'), -- 20150: San Francisco Telixtlahua -> San Francisco Telixtlahuaca
    (20, 160, N'San Jerónimo Silacayoapilla'), -- 20160: San Jerónimo Silacayoapil -> San Jerónimo Silacayoapilla
    (20, 175, N'San Juan Bautista Atatlahuca'), -- 20175: San Juan Bautista Atatlah -> San Juan Bautista Atatlahuca
    (20, 176, N'San Juan Bautista Coixtlahuaca'), -- 20176: San Juan Bautista Coixtla -> San Juan Bautista Coixtlahuaca
    (20, 177, N'San Juan Bautista Cuicatlán'), -- 20177: San Juan Bautista Cuicatl -> San Juan Bautista Cuicatlán
    (20, 178, N'San Juan Bautista Guelache'), -- 20178: San Juan Bautista Guelach -> San Juan Bautista Guelache
    (20, 179, N'San Juan Bautista Jayacatlán'), -- 20179: San Juan Bautista Jayacat -> San Juan Bautista Jayacatlán
    (20, 180, N'San Juan Bautista Lo de Soto'), -- 20180: San Juan Bautista Lo de S -> San Juan Bautista Lo de Soto
    (20, 181, N'San Juan Bautista Suchitepec'), -- 20181: San Juan Bautista Suchite -> San Juan Bautista Suchitepec
    (20, 182, N'San Juan Bautista Tlacoatzintepec'), -- 20182: San Juan Bautista Tlacoat -> San Juan Bautista Tlacoatzintepec
    (20, 183, N'San Juan Bautista Tlachichilco'), -- 20183: San Juan Bautista Tlachic -> San Juan Bautista Tlachichilco
    (20, 184, N'San Juan Bautista Tuxtepec'), -- 20184: San Juan Bautista Tuxtepe -> San Juan Bautista Tuxtepec
    (20, 196, N'San Juan Evangelista Analco'), -- 20196: San Juan Evangelista Anal -> San Juan Evangelista Analco
    (20, 228, N'San Lorenzo Cuaunecuiltitla'), -- 20228: San Lorenzo Cuaunecuiltit -> San Lorenzo Cuaunecuiltitla
    (20, 238, N'Heroico San Martín de los Cansecos'), -- 20238: Heroico San Martín de los -> Heroico San Martín de los Cansecos
    (20, 304, N'San Pedro Coxcaltepec Cántaros'), -- 20304: San Pedro Coxcaltepec Cán -> San Pedro Coxcaltepec Cántaros
    (20, 316, N'San Pedro Mártir Quiechapa'), -- 20316: San Pedro Mártir Quiechap -> San Pedro Mártir Quiechapa
    (20, 337, N'San Pedro y San Pablo Ayutla'), -- 20337: San Pedro y San Pablo Ayu -> San Pedro y San Pablo Ayutla
    (20, 339, N'San Pedro y San Pablo Teposcolula'), -- 20339: San Pedro y San Pablo Tep -> San Pedro y San Pablo Teposcolula
    (20, 340, N'San Pedro y San Pablo Tequixtepec'), -- 20340: San Pedro y San Pablo Teq -> San Pedro y San Pablo Tequixtepec
    (20, 348, N'San Sebastián Tecomaxtlahuaca'), -- 20348: San Sebastián Tecomaxtlah -> San Sebastián Tecomaxtlahuaca
    (20, 381, N'Santa Cruz Tacache de Mina'), -- 20381: Santa Cruz Tacache de Min -> Santa Cruz Tacache de Mina
    (20, 397, N'Heroica Ciudad de Tlaxiaco'), -- 20397: Heroica Ciudad de Tlaxiac -> Heroica Ciudad de Tlaxiaco
    (20, 418, N'Santa María Jalapa del Marqués'), -- 20418: Santa María Jalapa del Ma -> Santa María Jalapa del Marqués
    (20, 437, N'Santa María Tlahuitoltepec'), -- 20437: Santa María Tlahuitoltepe -> Santa María Tlahuitoltepec
    (20, 459, N'Villa de Santiago Chazumba'), -- 20459: Villa de Santiago Chazumb -> Villa de Santiago Chazumba
    (20, 482, N'Santiago Pinotepa Nacional'), -- 20482: Santiago Pinotepa Naciona -> Santiago Pinotepa Nacional
    (20, 540, N'Villa de Tamazulápam del Progreso'), -- 20540: Villa de Tamazulápam del  -> Villa de Tamazulápam del Progreso
    (20, 544, N'Teococuilco de Marcos Pérez'), -- 20544: Teococuilco de Marcos Pér -> Teococuilco de Marcos Pérez
    (20, 548, N'Tepelmeme Villa de Morelos'), -- 20548: Tepelmeme Villa de Morelo -> Tepelmeme Villa de Morelos
    (20, 549, N'Heroica Villa Tezoatlán de Segura y Luna, Cuna de la Independencia de Oaxaca'), -- 20549: Heroica Villa Tezoatlán d -> Heroica Villa Tezoatlán de Segura y Luna, Cuna de la Independencia de Oaxaca
    (20, 550, N'San Jerónimo Tlacochahuaya'), -- 20550: San Jerónimo Tlacochahuay -> San Jerónimo Tlacochahuaya
    (20, 554, N'Totontepec Villa de Morelos'), -- 20554: Totontepec Villa de Morel -> Totontepec Villa de Morelos
    (20, 559, N'San Juan Bautista Valle Nacional'), -- 20559: San Juan Bautista Valle N -> San Juan Bautista Valle Nacional
    (20, 562, N'Magdalena Yodocono de Porfirio Díaz'), -- 20562: Magdalena Yodocono de Por -> Magdalena Yodocono de Porfirio Díaz
    (21, 95, N'La Magdalena Tlatlauquitepec'), -- 21095: La Magdalena Tlatlauquite -> La Magdalena Tlatlauquitepec
    (21, 121, N'San Diego la Mesa Tochimiltzingo'), -- 21121: San Diego la Mesa Tochimi -> San Diego la Mesa Tochimiltzingo
    (21, 138, N'San Nicolás de los Ranchos'), -- 21138: San Nicolás de los Rancho -> San Nicolás de los Ranchos
    (21, 171, N'Tepeyahualco de Cuauhtémoc'), -- 21171: Tepeyahualco de Cuauhtémo -> Tepeyahualco de Cuauhtémoc
    (21, 177, N'Tlacotepec de Benito Juárez'), -- 21177: Tlacotepec de Benito Juár -> Tlacotepec de Benito Juárez
    (21, 202, N'Xochitlán de Vicente Suárez'), -- 21202: Xochitlán de Vicente Suár -> Xochitlán de Vicente Suárez
    (23, 8, N'Playa del Carmen'), -- 23008: Solidaridad -> Playa del Carmen
    (24, 35, N'Soledad de Graciano Sánchez'), -- 24035: Soledad de Graciano Sánch -> Soledad de Graciano Sánchez
    (26, 70, N'General Plutarco Elías Calles'), -- 26070: General Plutarco Elías Ca -> General Plutarco Elías Calles
    (29, 2, N'Apetatitlán de Antonio Carvajal'), -- 29002: Apetatitlán de Antonio Ca -> Apetatitlán de Antonio Carvajal
    (29, 15, N'Ixtacuixtla de Mariano Matamoros'), -- 29015: Ixtacuixtla de Mariano Ma -> Ixtacuixtla de Mariano Matamoros
    (29, 17, N'Mazatecochco de José María Morelos'), -- 29017: Mazatecochco de José Marí -> Mazatecochco de José María Morelos
    (29, 20, N'Sanctórum de Lázaro Cárdenas'), -- 29020: Sanctórum de Lázaro Cárde -> Sanctórum de Lázaro Cárdenas
    (29, 21, N'Nanacamilpa de Mariano Arista'), -- 29021: Nanacamilpa de Mariano Ar -> Nanacamilpa de Mariano Arista
    (29, 22, N'Acuamanala de Miguel Hidalgo'), -- 29022: Acuamanala de Miguel Hida -> Acuamanala de Miguel Hidalgo
    (29, 37, N'Ziltlaltépec de Trinidad Sánchez Santos'), -- 29037: Ziltlaltépec de Trinidad  -> Ziltlaltépec de Trinidad Sánchez Santos
    (30, 9, N'Alto Lucero de Gutiérrez Barrios'), -- 30009: Alto Lucero de Gutiérrez  -> Alto Lucero de Gutiérrez Barrios
    (30, 202, N'Zontecomatlán de López y Fuentes'), -- 30202: Zontecomatlán de López y  -> Zontecomatlán de López y Fuentes
    (30, 206, N'Nanchital de Lázaro Cárdenas del Río'), -- 30206: Nanchital de Lázaro Cárde -> Nanchital de Lázaro Cárdenas del Río
    (32, 6, N'Cañitas de Felipe Pescador'), -- 32006: Cañitas de Felipe Pescado -> Cañitas de Felipe Pescador
    (32, 11, N'Trinidad García de la Cadena'), -- 32011: Trinidad García de la Cad -> Trinidad García de la Cadena
    (32, 14, N'General Francisco R. Murguía'), -- 32014: General Francisco R. Murg -> General Francisco R. Murguía
    (32, 15, N'El Plateado de Joaquín Amaro'), -- 32015: El Plateado de Joaquín Am -> El Plateado de Joaquín Amaro
    (32, 48, N'Tlaltenango de Sánchez Román'); -- 32048: Tlaltenango de Sánchez Ro -> Tlaltenango de Sánchez Román

-- Actualiza nombres del catálogo nuevo para que coincidan con el Excel original de municipal-delitos.
UPDATE m
SET m.nombre = e.nombre_excel
FROM catalogo_municipio m
INNER JOIN @MunicipiosExcel e
    ON e.id_entidad_federativa = m.id_entidad_federativa
   AND e.clave_municipio = TRY_CONVERT(int, m.clave)
WHERE m.activo = 1
  AND ISNULL(m.nombre, N'') <> e.nombre_excel;

-- Validación: no debe regresar filas.
SELECT
    e.id_entidad_federativa,
    e.clave_municipio,
    m.nombre AS nombre_actual,
    e.nombre_excel AS nombre_esperado
FROM @MunicipiosExcel e
LEFT JOIN catalogo_municipio m
    ON m.id_entidad_federativa = e.id_entidad_federativa
   AND TRY_CONVERT(int, m.clave) = e.clave_municipio
   AND m.activo = 1
WHERE m.id_municipio IS NULL
   OR ISNULL(m.nombre, N'') <> e.nombre_excel
ORDER BY e.id_entidad_federativa, e.clave_municipio;

COMMIT;

GO

-- Fuente: indices y correcciones/indicesSABANAS.sql
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

GO

-- Fuente: indices y correcciones/proteccionOperacionSemanal.sql
USE siiid2;
GO

SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
BEGIN
    THROW 50070, 'No existe dbo.semanal_carga.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.semanal_carga
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      )
    GROUP BY id_entidad_federativa, anio_semana, numero_semana
    HAVING COUNT(*) > 1
)
BEGIN
    SELECT id_entidad_federativa, anio_semana, numero_semana, COUNT(*) AS operaciones_pendientes
    FROM dbo.semanal_carga
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      )
    GROUP BY id_entidad_federativa, anio_semana, numero_semana
    HAVING COUNT(*) > 1;

    THROW 50071, 'Existen operaciones pendientes duplicadas. Deben resolverse antes de crear el índice.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
      AND name = N'UX_semanal_carga_operacion_pendiente'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_operacion_pendiente
    ON dbo.semanal_carga
    (
        id_entidad_federativa,
        anio_semana,
        numero_semana
    )
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      );
END;

SELECT name, is_unique, has_filter, is_disabled, filter_definition
FROM sys.indexes
WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
  AND name = N'UX_semanal_carga_operacion_pendiente';
GO