-- Inventario para sustituir BANCI por el modelo mensual. Seleccionar QA en SSMS.
-- Solo consulta metadatos, configuración y estimaciones de filas; no lee víctimas ni usuarios.
-- No crea, altera ni elimina objetos. La tabla variable solo identifica módulos relacionados.
-- SSMS: Opciones > Resultados de consulta > SQL Server > Resultados en texto:
-- establecer máximo de caracteres por columna en 8192, abrir una ventana nueva
-- y guardar TODOS los resultados en archivo (Ctrl+Shift+F antes de ejecutar).
-- Los cuerpos se dividen en 4000 caracteres para evitar truncamiento de celdas en SSMS.
SET NOCOUNT ON;
IF DB_NAME() IN (N'master',N'model',N'msdb',N'tempdb')
    THROW 52900, 'Seleccione la base SIIID2_QA correspondiente.', 1;
IF ISNULL(HAS_PERMS_BY_NAME(DB_NAME(),N'DATABASE',N'VIEW DEFINITION'),0) <> 1
    THROW 52901, 'Se requiere VIEW DEFINITION de la base para evitar un inventario incompleto.', 1;

SELECT N'01_CONTEXTO' AS seccion, @@SERVERNAME AS servidor, DB_NAME() AS base_actual,
    CONVERT(NVARCHAR(128),SERVERPROPERTY('ProductVersion')) AS version_sql,
    d.compatibility_level, d.collation_name, SYSDATETIMEOFFSET() AS fecha_inventario
FROM sys.databases d WHERE d.database_id=DB_ID();

SELECT N'02_OBJETOS' AS seccion, o.object_id, SCHEMA_NAME(o.schema_id) AS esquema,
    o.name AS objeto, o.type, o.type_desc, o.parent_object_id, o.create_date, o.modify_date,
    CASE WHEN o.name COLLATE Latin1_General_100_CI_AS LIKE N'%banci%' THEN 1 ELSE 0 END AS nombre_banci
FROM sys.objects o WHERE o.is_ms_shipped=0 ORDER BY esquema, objeto;

SELECT N'03_COLUMNAS' AS seccion, SCHEMA_NAME(o.schema_id) AS esquema, o.name AS objeto,
    c.column_id, c.name AS columna, TYPE_SCHEMA_NAME(c.user_type_id) AS esquema_tipo,
    TYPE_NAME(c.user_type_id) AS tipo, c.max_length AS longitud_bytes, c.precision, c.scale,
    c.is_nullable, c.is_identity, c.is_computed, c.collation_name,
    CONVERT(NVARCHAR(100),ic.seed_value) AS semilla, CONVERT(NVARCHAR(100),ic.increment_value) AS incremento,
    dc.name AS default_nombre, dc.definition AS default_definicion, cc.definition AS calculada_definicion
FROM sys.columns c JOIN sys.objects o ON o.object_id=c.object_id
LEFT JOIN sys.identity_columns ic ON ic.object_id=c.object_id AND ic.column_id=c.column_id
LEFT JOIN sys.default_constraints dc ON dc.object_id=c.default_object_id
LEFT JOIN sys.computed_columns cc ON cc.object_id=c.object_id AND cc.column_id=c.column_id
WHERE o.is_ms_shipped=0 AND o.type IN (N'U',N'V',N'TT') ORDER BY esquema, objeto, c.column_id;

SELECT N'04_CLAVES_FORANEAS' AS seccion, fk.name AS restriccion,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS esquema_origen, OBJECT_NAME(fk.parent_object_id) AS tabla_origen,
    pc.name AS columna_origen, OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS esquema_destino,
    OBJECT_NAME(fk.referenced_object_id) AS tabla_destino, rc.name AS columna_destino,
    fkc.constraint_column_id AS posicion, fk.is_disabled, fk.is_not_trusted,
    fk.delete_referential_action_desc, fk.update_referential_action_desc
FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id=fk.object_id
JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id
WHERE fk.is_ms_shipped=0 ORDER BY tabla_origen, restriccion, posicion;

SELECT N'05_CHECKS' AS seccion, OBJECT_SCHEMA_NAME(c.parent_object_id) AS esquema,
    OBJECT_NAME(c.parent_object_id) AS tabla, c.name, c.definition, c.is_disabled, c.is_not_trusted
FROM sys.check_constraints c WHERE c.is_ms_shipped=0 ORDER BY esquema, tabla, c.name;

SELECT N'06_INDICES' AS seccion, OBJECT_SCHEMA_NAME(i.object_id) AS esquema,
    OBJECT_NAME(i.object_id) AS tabla, i.name, i.type_desc, i.is_unique, i.is_primary_key,
    i.is_unique_constraint, i.is_disabled, i.filter_definition, c.name AS columna,
    ic.key_ordinal, ic.is_descending_key, ic.is_included_column
FROM sys.indexes i JOIN sys.objects o ON o.object_id=i.object_id
LEFT JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
LEFT JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
WHERE o.is_ms_shipped=0 AND i.index_id>0
ORDER BY esquema, tabla, i.index_id, ic.index_column_id;

SELECT N'07_DEPENDENCIAS' AS seccion, OBJECT_SCHEMA_NAME(d.referencing_id) AS esquema_origen,
    OBJECT_NAME(d.referencing_id) AS objeto_origen, d.referencing_minor_id,
    d.referenced_server_name, d.referenced_database_name,
    COALESCE(d.referenced_schema_name,OBJECT_SCHEMA_NAME(d.referenced_id)) AS esquema_destino,
    COALESCE(d.referenced_entity_name,OBJECT_NAME(d.referenced_id)) AS objeto_destino,
    d.referenced_id, d.referenced_minor_id, d.is_schema_bound_reference,
    d.is_caller_dependent, d.is_ambiguous
FROM sys.sql_expression_dependencies d JOIN sys.objects o ON o.object_id=d.referencing_id
WHERE o.is_ms_shipped=0 ORDER BY esquema_origen, objeto_origen, objeto_destino;

DECLARE @Modulos TABLE(object_id INT PRIMARY KEY);
INSERT @Modulos SELECT DISTINCT o.object_id FROM sys.objects o
LEFT JOIN sys.sql_modules m ON m.object_id=o.object_id
WHERE o.is_ms_shipped=0 AND (o.name COLLATE Latin1_General_100_CI_AS LIKE N'%banci%'
    OR m.definition COLLATE Latin1_General_100_CI_AS LIKE N'%banci%');
-- Añade los módulos que dependen indirectamente de esos objetos; no decide qué borrar.
WHILE 1=1
BEGIN
    INSERT @Modulos SELECT DISTINCT d.referencing_id
    FROM sys.sql_expression_dependencies d JOIN @Modulos t ON t.object_id=d.referenced_id
    JOIN sys.sql_modules m ON m.object_id=d.referencing_id
    JOIN sys.objects o ON o.object_id=m.object_id AND o.is_ms_shipped=0
    WHERE NOT EXISTS(SELECT 1 FROM @Modulos x WHERE x.object_id=d.referencing_id);
    IF @@ROWCOUNT=0 BREAK;
END;

SELECT N'08_MODULOS_RELACIONADOS' AS seccion, o.object_id, SCHEMA_NAME(o.schema_id) AS esquema,
    o.name AS objeto, o.type_desc, m.uses_ansi_nulls, m.uses_quoted_identifier,
    m.is_schema_bound, CASE WHEN m.definition IS NULL THEN 0 ELSE 1 END AS definicion_visible,
    tr.parent_id AS trigger_objeto_padre, tr.is_disabled AS trigger_desactivado
FROM @Modulos x JOIN sys.objects o ON o.object_id=x.object_id
LEFT JOIN sys.sql_modules m ON m.object_id=o.object_id
LEFT JOIN sys.triggers tr ON tr.object_id=o.object_id
ORDER BY esquema, objeto;

;WITH numeros AS
(
    SELECT TOP (10000) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT N'09_DEFINICIONES' AS seccion, SCHEMA_NAME(o.schema_id) AS esquema, o.name AS objeto,
    n.n AS fragmento, SUBSTRING(m.definition,(n.n-1)*4000+1,4000) AS definicion_fragmento
FROM @Modulos x JOIN sys.objects o ON o.object_id=x.object_id
JOIN sys.sql_modules m ON m.object_id=x.object_id
JOIN numeros n ON n.n <= (DATALENGTH(m.definition)/2+3999)/4000
ORDER BY esquema, objeto, fragmento;

SELECT N'10_FILAS_BANCI' AS seccion, SCHEMA_NAME(t.schema_id) AS esquema, t.name AS tabla,
    SUM(p.rows) AS filas_estimadas_metadatos
FROM sys.tables t LEFT JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1)
WHERE t.name COLLATE Latin1_General_100_CI_AS LIKE N'%banci%'
GROUP BY t.schema_id,t.name ORDER BY esquema, tabla;

IF OBJECT_ID(N'dbo.sistema_configuracion',N'U') IS NOT NULL AND OBJECT_ID(N'dbo.catalogo_modulo',N'U') IS NOT NULL
    EXEC sys.sp_executesql N'SELECT N''11_CONFIGURACION'' AS seccion,m.clave AS modulo,c.clave,c.descripcion,c.habilitado,c.disponible
        FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo
        WHERE m.clave=N''BANCI'' OR c.clave LIKE N''%BANCI%'' ORDER BY m.clave,c.clave;';

SELECT N'12_PERMISOS_OBJETOS' AS seccion, OBJECT_SCHEMA_NAME(p.major_id) AS esquema,
    OBJECT_NAME(p.major_id) AS objeto, dp.name AS principal, p.state_desc, p.permission_name, p.minor_id
FROM sys.database_permissions p JOIN @Modulos x ON x.object_id=p.major_id AND p.class=1
JOIN sys.database_principals dp ON dp.principal_id=p.grantee_principal_id
ORDER BY esquema, objeto, principal, p.permission_name;

SELECT N'13_SECUENCIAS_SINONIMOS' AS seccion, SCHEMA_NAME(o.schema_id) AS esquema,
    o.name AS objeto, o.type_desc, sy.base_object_name AS destino_sinonimo
FROM sys.objects o LEFT JOIN sys.synonyms sy ON sy.object_id=o.object_id
WHERE o.is_ms_shipped=0 AND o.type IN(N'SO',N'SN') ORDER BY esquema,objeto;

-- SQL Agent puede referenciar BANCI sin una dependencia registrada en la base.
-- No exporta comandos de jobs ni credenciales; si no hay permisos lo indica.
BEGIN TRY
    EXEC sys.sp_executesql N'SELECT N''14_JOBS_BANCI'' AS seccion,j.name AS job,s.step_id,s.step_name,s.subsystem,s.database_name
        FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobsteps s ON s.job_id=j.job_id
        WHERE (s.database_name=DB_NAME() OR s.database_name IS NULL OR s.database_name=N'''')
          AND s.command COLLATE Latin1_General_100_CI_AS LIKE N''%banci%'' ORDER BY j.name,s.step_id;';
END TRY
BEGIN CATCH
    SELECT N'14_JOBS_BANCI_NO_VERIFICADOS' AS seccion,ERROR_NUMBER() AS error,ERROR_MESSAGE() AS motivo;
END CATCH;
