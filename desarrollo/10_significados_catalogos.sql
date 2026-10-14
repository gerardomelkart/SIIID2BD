-- Significado estable de opciones: la API conserva las reglas y consulta las claves vigentes.
-- Ejecutar en la base seleccionada después de desarrollo/09, antes de publicar API y Front.
-- Usar una ventana sin cargas BANCI en ejecución; el script realiza DDL transaccional.
-- No cambia claves, descripciones, registros operativos ni permisos. No usa USE.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
IF DB_NAME() IN (N'master',N'model',N'msdb',N'tempdb') THROW 52710, 'Seleccione la base SIIID2 correspondiente.', 1;
IF @@TRANCOUNT <> 0 THROW 52710, 'Ejecute sin transacción abierta.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.catalogo_sexo',N'U') IS NULL THROW 52710, 'Falta catalogo_sexo. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_sexo',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_sexo ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''1'',N''HOMBRE''),(N''2'',N''MUJER''),(N''3'',N''NO_IDENTIFICADO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_sexo c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_sexo x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_sexo c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_sexo.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_sexo') AND name=N'UX_catalogo_sexo_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_sexo_codigo_regla ON dbo.catalogo_sexo(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_genero',N'U') IS NULL THROW 52710, 'Falta catalogo_genero. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_genero',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_genero ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''3'',N''NO_IDENTIFICADO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_genero c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_genero x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_genero c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_genero.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_genero') AND name=N'UX_catalogo_genero_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_genero_codigo_regla ON dbo.catalogo_genero(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_pertenece_poblacion_indigena',N'U') IS NULL THROW 52710, 'Falta catalogo_pertenece_poblacion_indigena. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_pertenece_poblacion_indigena',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_pertenece_poblacion_indigena ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''3'',N''NO_IDENTIFICADO''),(N''4'',N''NO_APLICA'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_pertenece_poblacion_indigena c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_pertenece_poblacion_indigena x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_pertenece_poblacion_indigena c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_pertenece_poblacion_indigena.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_pertenece_poblacion_indigena') AND name=N'UX_catalogo_pertenece_poblacion_indigena_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_pertenece_poblacion_indigena_codigo_regla ON dbo.catalogo_pertenece_poblacion_indigena(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_presenta_discapacidad',N'U') IS NULL THROW 52710, 'Falta catalogo_presenta_discapacidad. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_presenta_discapacidad',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_presenta_discapacidad ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''3'',N''NO_IDENTIFICADO''),(N''4'',N''NO_APLICA'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_presenta_discapacidad c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_presenta_discapacidad x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_presenta_discapacidad c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_presenta_discapacidad.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_presenta_discapacidad') AND name=N'UX_catalogo_presenta_discapacidad_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_presenta_discapacidad_codigo_regla ON dbo.catalogo_presenta_discapacidad(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_nacionalidad',N'U') IS NULL THROW 52710, 'Falta catalogo_nacionalidad. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_nacionalidad',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_nacionalidad ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''174'',N''NO_IDENTIFICADO''),(N''73'',N''MEXICANA'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_nacionalidad c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_nacionalidad x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_nacionalidad c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_nacionalidad.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_nacionalidad') AND name=N'UX_catalogo_nacionalidad_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_nacionalidad_codigo_regla ON dbo.catalogo_nacionalidad(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_forma_accion',N'U') IS NULL THROW 52710, 'Falta catalogo_forma_accion. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_forma_accion',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_forma_accion ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''1'',N''CON_VIOLENCIA''),(N''2'',N''SIN_VIOLENCIA''),(N''3'',N''NO_IDENTIFICADO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_forma_accion c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_forma_accion x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_forma_accion c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_forma_accion.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_forma_accion') AND name=N'UX_catalogo_forma_accion_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_forma_accion_codigo_regla ON dbo.catalogo_forma_accion(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_instrumento_comision',N'U') IS NULL THROW 52710, 'Falta catalogo_instrumento_comision. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_instrumento_comision',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_instrumento_comision ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''6'',N''OTRO''),(N''7'',N''NO_IDENTIFICADO''),(N''8'',N''NO_APLICA'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_instrumento_comision c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_instrumento_comision x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_instrumento_comision c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_instrumento_comision.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_instrumento_comision') AND name=N'UX_catalogo_instrumento_comision_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_instrumento_comision_codigo_regla ON dbo.catalogo_instrumento_comision(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_grado_consumacion',N'U') IS NULL THROW 52710, 'Falta catalogo_grado_consumacion. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_grado_consumacion',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_grado_consumacion ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''1'',N''CONSUMADO''),(N''2'',N''TENTATIVA''),(N''3'',N''NO_IDENTIFICADO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_grado_consumacion c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_grado_consumacion x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_grado_consumacion c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_grado_consumacion.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_grado_consumacion') AND name=N'UX_catalogo_grado_consumacion_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_grado_consumacion_codigo_regla ON dbo.catalogo_grado_consumacion(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_tipo_victima',N'U') IS NULL THROW 52710, 'Falta catalogo_tipo_victima. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_tipo_victima',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_tipo_victima ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''1'',N''PERSONA_FISICA''),(N''2'',N''PERSONA_MORAL''),(N''3'',N''OTRO''),(N''4'',N''NO_IDENTIFICADO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_tipo_victima c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_tipo_victima x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_tipo_victima c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_tipo_victima.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_tipo_victima') AND name=N'UX_catalogo_tipo_victima_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_tipo_victima_codigo_regla ON dbo.catalogo_tipo_victima(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.catalogo_tipo_victima_moral',N'U') IS NULL THROW 52710, 'Falta catalogo_tipo_victima_moral. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.catalogo_tipo_victima_moral',N'codigo_regla') IS NULL
        ALTER TABLE dbo.catalogo_tipo_victima_moral ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''5'',N''OTRO''),(N''6'',N''NO_IDENTIFICADO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_tipo_victima_moral c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.catalogo_tipo_victima_moral x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.catalogo_tipo_victima_moral c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de catalogo_tipo_victima_moral.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.catalogo_tipo_victima_moral') AND name=N'UX_catalogo_tipo_victima_moral_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_catalogo_tipo_victima_moral_codigo_regla ON dbo.catalogo_tipo_victima_moral(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.banci_catalogo_localizacion',N'U') IS NULL THROW 52710, 'Falta banci_catalogo_localizacion. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.banci_catalogo_localizacion',N'codigo_regla') IS NULL
        ALTER TABLE dbo.banci_catalogo_localizacion ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''1'',N''NO_LOCALIZADO''),(N''2'',N''LOCALIZADO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.banci_catalogo_localizacion c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.banci_catalogo_localizacion x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.banci_catalogo_localizacion c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de banci_catalogo_localizacion.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.banci_catalogo_localizacion') AND name=N'UX_banci_catalogo_localizacion_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_banci_catalogo_localizacion_codigo_regla ON dbo.banci_catalogo_localizacion(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.banci_catalogo_condicion_vida',N'U') IS NULL THROW 52710, 'Falta banci_catalogo_condicion_vida. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.banci_catalogo_condicion_vida',N'codigo_regla') IS NULL
        ALTER TABLE dbo.banci_catalogo_condicion_vida ADD codigo_regla NVARCHAR(80) NULL;
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.banci_catalogo_condicion_vida') AND name=N'UX_banci_catalogo_condicion_vida_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_banci_catalogo_condicion_vida_codigo_regla ON dbo.banci_catalogo_condicion_vida(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    IF OBJECT_ID(N'dbo.banci_catalogo_constitutiva_delito',N'U') IS NULL THROW 52710, 'Falta banci_catalogo_constitutiva_delito. Ejecute los scripts previos.', 1;
    IF COL_LENGTH(N'dbo.banci_catalogo_constitutiva_delito',N'codigo_regla') IS NULL
        ALTER TABLE dbo.banci_catalogo_constitutiva_delito ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''1'',N''DELITO''),(N''2'',N''NO_DELITO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.banci_catalogo_constitutiva_delito c JOIN @Opciones o ON CONVERT(NVARCHAR(20),c.clave)=o.clave
WHERE c.codigo_regla IS NULL AND NOT EXISTS(SELECT 1 FROM dbo.banci_catalogo_constitutiva_delito x WHERE x.codigo_regla=o.codigo);
IF EXISTS(SELECT 1 FROM @Opciones o WHERE (SELECT COUNT(*) FROM dbo.banci_catalogo_constitutiva_delito c WHERE c.codigo_regla=o.codigo AND c.activo=1)<>1)
THROW 52711, ''Revise los significados activos de banci_catalogo_constitutiva_delito.'', 1;';
    IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.banci_catalogo_constitutiva_delito') AND name=N'UX_banci_catalogo_constitutiva_delito_codigo_regla')
        EXEC(N'CREATE UNIQUE INDEX UX_banci_catalogo_constitutiva_delito_codigo_regla ON dbo.banci_catalogo_constitutiva_delito(codigo_regla) WHERE codigo_regla IS NOT NULL;');
    -- Diferenciar las entidades territoriales de No aplica y Extranjero desde el catálogo.
    IF COL_LENGTH(N'dbo.catalogo_entidad_federativa',N'es_entidad_territorial') IS NULL
    BEGIN
        ALTER TABLE dbo.catalogo_entidad_federativa ADD es_entidad_territorial BIT NOT NULL CONSTRAINT DF_entidad_territorial DEFAULT(0);
        EXEC(N'UPDATE dbo.catalogo_entidad_federativa SET es_entidad_territorial=1 WHERE id_entidad_federativa BETWEEN 1 AND 32;');
    END;
    IF COL_LENGTH(N'dbo.catalogo_delito',N'codigo_regla') IS NULL ALTER TABLE dbo.catalogo_delito ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''1.01'',N''HOMICIDIO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_delito c JOIN @Opciones o ON c.clave2=o.clave WHERE c.codigo_regla IS NULL;
IF EXISTS(SELECT 1 FROM @Opciones o WHERE NOT EXISTS(SELECT 1 FROM dbo.catalogo_delito c WHERE c.clave2=o.clave AND c.codigo_regla=o.codigo AND c.activo=1)) THROW 52711, ''Revise los significados de catalogo_delito.'', 1;';
    IF COL_LENGTH(N'dbo.catalogo_subtipo_delito',N'codigo_regla') IS NULL ALTER TABLE dbo.catalogo_subtipo_delito ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''1.01.01'',N''HOMICIDIO_DOLOSO''),(N''1.02.01'',N''LESIONES_DOLOSAS'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_subtipo_delito c JOIN @Opciones o ON c.clave3=o.clave WHERE c.codigo_regla IS NULL;
IF EXISTS(SELECT 1 FROM @Opciones o WHERE NOT EXISTS(SELECT 1 FROM dbo.catalogo_subtipo_delito c WHERE c.clave3=o.clave AND c.codigo_regla=o.codigo AND c.activo=1)) THROW 52711, ''Revise los significados de catalogo_subtipo_delito.'', 1;';
    IF COL_LENGTH(N'dbo.catalogo_modalidad_delito',N'codigo_regla') IS NULL ALTER TABLE dbo.catalogo_modalidad_delito ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'DECLARE @Opciones TABLE(clave NVARCHAR(20),codigo NVARCHAR(80));
INSERT INTO @Opciones VALUES (N''4.01.02.01'',N''ROBO_VEHICULO''),(N''4.01.02.02'',N''ROBO_VEHICULO''),(N''4.04.01'',N''EXTORSION''),(N''4.04.02'',N''EXTORSION''),(N''1.03'',N''FEMINICIDIO'');
UPDATE c SET codigo_regla=o.codigo FROM dbo.catalogo_modalidad_delito c JOIN @Opciones o ON c.clave4=o.clave WHERE c.codigo_regla IS NULL;
IF EXISTS(SELECT 1 FROM @Opciones o WHERE NOT EXISTS(SELECT 1 FROM dbo.catalogo_modalidad_delito c WHERE c.clave4=o.clave AND c.codigo_regla=o.codigo AND c.activo=1)) THROW 52711, ''Revise los significados de catalogo_modalidad_delito.'', 1;';
    IF COL_LENGTH(N'dbo.federal_catalogo_modalidad_delito',N'codigo_regla') IS NULL
        ALTER TABLE dbo.federal_catalogo_modalidad_delito ADD codigo_regla NVARCHAR(80) NULL;
    EXEC sys.sp_executesql N'UPDATE dbo.federal_catalogo_modalidad_delito SET codigo_regla=N''FEMINICIDIO'' WHERE clave4=N''1.03'' AND codigo_regla IS NULL;
IF (SELECT COUNT(*) FROM dbo.federal_catalogo_modalidad_delito WHERE codigo_regla=N''FEMINICIDIO'' AND activo=1)<>1
THROW 52711, ''Revise el significado de Feminicidio en Federal.'', 1;';
    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.vw_catalogos_reglas AS
SELECT N''catalogo_sexo'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_sexo WHERE activo=1
UNION ALL
SELECT N''catalogo_genero'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_genero WHERE activo=1
UNION ALL
SELECT N''catalogo_pertenece_poblacion_indigena'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_pertenece_poblacion_indigena WHERE activo=1
UNION ALL
SELECT N''catalogo_presenta_discapacidad'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_presenta_discapacidad WHERE activo=1
UNION ALL
SELECT N''catalogo_nacionalidad'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_nacionalidad WHERE activo=1
UNION ALL
SELECT N''catalogo_forma_accion'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_forma_accion WHERE activo=1
UNION ALL
SELECT N''catalogo_instrumento_comision'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_instrumento_comision WHERE activo=1
UNION ALL
SELECT N''catalogo_grado_consumacion'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_grado_consumacion WHERE activo=1
UNION ALL
SELECT N''catalogo_tipo_victima'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_tipo_victima WHERE activo=1
UNION ALL
SELECT N''catalogo_tipo_victima_moral'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_tipo_victima_moral WHERE activo=1
UNION ALL
SELECT N''banci_catalogo_localizacion'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.banci_catalogo_localizacion WHERE activo=1
UNION ALL
SELECT N''banci_catalogo_condicion_vida'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.banci_catalogo_condicion_vida WHERE activo=1
UNION ALL
SELECT N''banci_catalogo_constitutiva_delito'' AS Catalogo, CONVERT(NVARCHAR(20),clave) AS Clave, descripcion AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.banci_catalogo_constitutiva_delito WHERE activo=1
UNION ALL
SELECT N''catalogo_delito'' AS Catalogo, CONVERT(NVARCHAR(20),clave2) AS Clave, delito AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_delito WHERE activo=1
UNION ALL
SELECT N''catalogo_subtipo_delito'' AS Catalogo, CONVERT(NVARCHAR(20),clave3) AS Clave, subtipo_delito AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_subtipo_delito WHERE activo=1
UNION ALL
SELECT N''catalogo_modalidad_delito'' AS Catalogo, CONVERT(NVARCHAR(20),clave4) AS Clave, modalidad_delito AS Descripcion, codigo_regla AS CodigoRegla FROM dbo.catalogo_modalidad_delito WHERE activo=1
UNION ALL
SELECT N''federal_catalogo_modalidad_delito'',CONVERT(NVARCHAR(20),clave4),modalidad_delito,codigo_regla FROM dbo.federal_catalogo_modalidad_delito WHERE activo=1;';
    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_motivo_desaparicion_catalogo AS
SELECT c.clave AS constitutiva_delito, CONVERT(NVARCHAR(1000),m.clave) AS clave,m.descripcion
FROM dbo.banci_catalogo_constitutiva_delito c CROSS JOIN dbo.banci_vw_delito_localizacion_catalogo m
WHERE c.activo=1 AND c.codigo_regla=N''DELITO''
UNION ALL
SELECT c.clave,CONVERT(NVARCHAR(1000),m.clave),m.descripcion
FROM dbo.banci_catalogo_constitutiva_delito c CROSS JOIN dbo.banci_catalogo_motivo_no_delito m
WHERE c.activo=1 AND c.codigo_regla=N''NO_DELITO'' AND m.activo=1;';
    -- Mantener las guardas existentes de BANCI consistentes con los catálogos.
    -- Solo sustituye listas de claves y el estado inicial; conserva el SP instalado y sus permisos.
    IF OBJECT_ID(N'dbo.CK_banci_constitutiva_clave',N'C') IS NOT NULL
        ALTER TABLE dbo.banci_catalogo_constitutiva_delito DROP CONSTRAINT CK_banci_constitutiva_clave;
    IF OBJECT_ID(N'dbo.CK_banci_victima_motivo_par',N'C') IS NOT NULL
        ALTER TABLE dbo.banci_victima DROP CONSTRAINT CK_banci_victima_motivo_par;
    ALTER TABLE dbo.banci_victima WITH CHECK ADD CONSTRAINT CK_banci_victima_motivo_par CHECK(
        (constitutiva_delito IS NULL AND motivo_desaparicion IS NULL) OR
        (constitutiva_delito IS NOT NULL AND motivo_desaparicion IS NOT NULL AND LEN(LTRIM(RTRIM(motivo_desaparicion)))>0));
    DECLARE @Definicion NVARCHAR(MAX), @DefinicionNueva NVARCHAR(MAX), @ValidacionCatalogo NVARCHAR(MAX);
    DECLARE @NombreSP SYSNAME, @PosNombre INT, @RevCreate INT, @RevAlter INT,
        @Cabecera INT, @Palabra NVARCHAR(6), @Firma NVARCHAR(MAX), @FirmaNormalizada NVARCHAR(MAX);
    SET @ValidacionCatalogo=N'NOT EXISTS(SELECT 1 FROM dbo.vw_catalogos_reglas r WHERE r.Catalogo=CASE campo WHEN N''localizado_o_no_localizado'' THEN N''banci_catalogo_localizacion'' WHEN N''con_o_sin_vida'' THEN N''banci_catalogo_condicion_vida'' WHEN N''constitutiva_delito'' THEN N''banci_catalogo_constitutiva_delito'' END AND r.Clave=CONVERT(NVARCHAR(20),TRY_CONVERT(TINYINT,valor)))';
    SET @NombreSP=N'sp_banci_calcular_actualizacion_v2';
    SET @Definicion=OBJECT_DEFINITION(OBJECT_ID(N'dbo.'+@NombreSP));
    IF @Definicion IS NULL THROW 52712, 'Falta sp_banci_calcular_actualizacion_v2 o permiso para leer su definición.', 1;
    SET @DefinicionNueva=REPLACE(REPLACE(@Definicion,N'TRY_CONVERT(TINYINT,valor) NOT IN (1,2)',@ValidacionCatalogo),N'TRY_CONVERT(TINYINT,valor) NOT IN (1, 2)',@ValidacionCatalogo);
    IF @DefinicionNueva NOT LIKE N'%vw_catalogos_reglas%' THROW 52712, 'La guarda de actualización BANCI no coincide con la versión esperada. Revise antes de publicar.', 1;
    IF @DefinicionNueva<>@Definicion
    BEGIN
        -- Convertir únicamente la palabra de declaración, independientemente de espacios o saltos.
        -- Conserva el cuerpo, los comentarios y CREATE OR ALTER, que ya permite actualizar el objeto.
        SET @PosNombre=CHARINDEX(@NombreSP, @DefinicionNueva COLLATE Latin1_General_100_CI_AS);
        IF @PosNombre=0 THROW 52713, 'La definición no contiene el nombre del procedimiento.', 1;
        SET @Firma=REVERSE(LEFT(@DefinicionNueva,@PosNombre-1));
        SET @RevCreate=CHARINDEX(N'ETAERC',@Firma COLLATE Latin1_General_100_CI_AS);
        SET @RevAlter=CHARINDEX(N'RETLA',@Firma COLLATE Latin1_General_100_CI_AS);
        IF @RevCreate=0 AND @RevAlter=0 THROW 52713, 'No se identificó CREATE ni ALTER en la declaración.', 1;
        IF @RevAlter>0 AND (@RevCreate=0 OR @RevAlter<@RevCreate)
        BEGIN
            SET @Cabecera=@PosNombre-1-@RevAlter-LEN(N'ALTER')+2;
            SET @Palabra=N'ALTER';
        END
        ELSE
        BEGIN
            SET @Cabecera=@PosNombre-1-@RevCreate-LEN(N'CREATE')+2;
            SET @Palabra=N'CREATE';
        END;
        SET @Firma=SUBSTRING(@DefinicionNueva,@Cabecera,@PosNombre-@Cabecera);
        SET @FirmaNormalizada=UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            @Firma,N' ',N''),NCHAR(9),N''),NCHAR(10),N''),NCHAR(13),N''),N'[',N''),N']',N''));
        IF @FirmaNormalizada COLLATE Latin1_General_100_BIN2 NOT IN
            (N'CREATEPROCEDUREDBO.',N'CREATEPROCDBO.',N'ALTERPROCEDUREDBO.',N'ALTERPROCDBO.',
             N'CREATEPROCEDURE',N'CREATEPROC',N'ALTERPROCEDURE',N'ALTERPROC')
            THROW 52713, 'Declaración de procedimiento no reconocida; no se modificó.', 1;
        IF @Palabra=N'CREATE' SET @DefinicionNueva=STUFF(@DefinicionNueva,@Cabecera,LEN(N'CREATE'),N'ALTER');
        EXEC sys.sp_executesql @DefinicionNueva;
    END;
    DECLARE estados CURSOR LOCAL FAST_FORWARD FOR
        SELECT nombre FROM (VALUES(N'sp_banci_procesar_carga_v2'),(N'sp_banci_vista_previa_v2')) n(nombre);
    OPEN estados;
    FETCH NEXT FROM estados INTO @NombreSP;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Definicion=OBJECT_DEFINITION(OBJECT_ID(N'dbo.'+@NombreSP));
        IF @Definicion IS NULL THROW 52712, 'Falta un procedimiento de carga/vista previa BANCI o permiso para leer su definición.', 1;
        SET @DefinicionNueva=REPLACE(@Definicion,N'localizado_o_no_localizado = CAST(1 AS TINYINT)',N'localizado_o_no_localizado = (SELECT clave FROM dbo.banci_catalogo_localizacion WHERE activo=1 AND codigo_regla=N''NO_LOCALIZADO'')');
        IF @DefinicionNueva NOT LIKE N'%codigo_regla%NO_LOCALIZADO%' THROW 52712, 'El estado inicial BANCI no coincide con la versión esperada. Revise antes de publicar.', 1;
        IF @DefinicionNueva<>@Definicion
        BEGIN
            -- Convertir únicamente la palabra de declaración, independientemente de espacios o saltos.
            -- Conserva el cuerpo, los comentarios y CREATE OR ALTER, que ya permite actualizar el objeto.
            SET @PosNombre=CHARINDEX(@NombreSP, @DefinicionNueva COLLATE Latin1_General_100_CI_AS);
            IF @PosNombre=0 THROW 52713, 'La definición no contiene el nombre del procedimiento.', 1;
            SET @Firma=REVERSE(LEFT(@DefinicionNueva,@PosNombre-1));
            SET @RevCreate=CHARINDEX(N'ETAERC',@Firma COLLATE Latin1_General_100_CI_AS);
            SET @RevAlter=CHARINDEX(N'RETLA',@Firma COLLATE Latin1_General_100_CI_AS);
            IF @RevCreate=0 AND @RevAlter=0 THROW 52713, 'No se identificó CREATE ni ALTER en la declaración.', 1;
            IF @RevAlter>0 AND (@RevCreate=0 OR @RevAlter<@RevCreate)
            BEGIN
                SET @Cabecera=@PosNombre-1-@RevAlter-LEN(N'ALTER')+2;
                SET @Palabra=N'ALTER';
            END
            ELSE
            BEGIN
                SET @Cabecera=@PosNombre-1-@RevCreate-LEN(N'CREATE')+2;
                SET @Palabra=N'CREATE';
            END;
            SET @Firma=SUBSTRING(@DefinicionNueva,@Cabecera,@PosNombre-@Cabecera);
            SET @FirmaNormalizada=UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                @Firma,N' ',N''),NCHAR(9),N''),NCHAR(10),N''),NCHAR(13),N''),N'[',N''),N']',N''));
            IF @FirmaNormalizada COLLATE Latin1_General_100_BIN2 NOT IN
                (N'CREATEPROCEDUREDBO.',N'CREATEPROCDBO.',N'ALTERPROCEDUREDBO.',N'ALTERPROCDBO.',
                 N'CREATEPROCEDURE',N'CREATEPROC',N'ALTERPROCEDURE',N'ALTERPROC')
                THROW 52713, 'Declaración de procedimiento no reconocida; no se modificó.', 1;
            IF @Palabra=N'CREATE' SET @DefinicionNueva=STUFF(@DefinicionNueva,@Cabecera,LEN(N'CREATE'),N'ALTER');
            EXEC sys.sp_executesql @DefinicionNueva;
        END;
        FETCH NEXT FROM estados INTO @NombreSP;
    END;
    CLOSE estados;
    DEALLOCATE estados;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
