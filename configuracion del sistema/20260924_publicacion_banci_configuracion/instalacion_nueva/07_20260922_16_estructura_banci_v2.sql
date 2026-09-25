USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- BANCI V2 / estructura_banci_v2. Ejecutar completo en desarrollo, sin modo SQLCMD.
IF DB_NAME() <> N'siiid2' THROW 52500, 'Base de datos incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52500, 'Use una ventana sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sp_banci_vista_previa', N'P') IS NULL OR OBJECT_ID(N'dbo.banci_historial_cambio', N'U') IS NULL
    THROW 52500, 'Requiere la instalación BANCI hasta el script 15.', 1;
IF (SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID()) < 130 THROW 52500, 'Se requiere compatibilidad SQL 130 o superior.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @BloqueoMigracion INT;
    EXEC @BloqueoMigracion = sys.sp_getapplock @Resource = N'BANCI:MIGRACION:V2', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @BloqueoMigracion < 0 THROW 52500, 'Hay otra migración BANCI en curso.', 1;
EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.banci_consecutivo_carpeta'', N''U'') IS NULL
CREATE TABLE dbo.banci_consecutivo_carpeta (
    id_entidad_federativa TINYINT NOT NULL, anio SMALLINT NOT NULL, ultimo INT NOT NULL,
    CONSTRAINT PK_banci_consecutivo_carpeta PRIMARY KEY (id_entidad_federativa, anio),
    CONSTRAINT CK_banci_consecutivo_carpeta CHECK (id_entidad_federativa BETWEEN 1 AND 32 AND anio BETWEEN 1900 AND 9999 AND ultimo BETWEEN 0 AND 999999),
    CONSTRAINT FK_banci_consecutivo_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa)
);';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_carpeta_investigacion'', N''no_banci'') IS NULL ALTER TABLE dbo.banci_carpeta_investigacion ADD no_banci NVARCHAR(40) NULL;';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_carga_tmp_carpeta'', N''no_banci'') IS NULL ALTER TABLE dbo.banci_carga_tmp_carpeta ADD no_banci NVARCHAR(100) NULL;';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_carga'', N''version_formato'') IS NULL ALTER TABLE dbo.banci_carga ADD version_formato TINYINT NOT NULL CONSTRAINT DF_banci_carga_version_formato DEFAULT (1);';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_victima'', N''voluntaria_o_fue_delito'') IS NULL ALTER TABLE dbo.banci_victima ADD voluntaria_o_fue_delito TINYINT NULL;';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_victima'', N''acciones_busqueda'') IS NULL ALTER TABLE dbo.banci_victima ADD acciones_busqueda NVARCHAR(MAX) NULL;';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_victima'', N''version_banci'') IS NULL ALTER TABLE dbo.banci_victima ADD version_banci ROWVERSION;';

EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.banci_catalogo_motivo_localizacion'', N''U'') IS NULL
CREATE TABLE dbo.banci_catalogo_motivo_localizacion (clave TINYINT NOT NULL CONSTRAINT PK_banci_motivo_localizacion PRIMARY KEY, descripcion NVARCHAR(100) NOT NULL, activo BIT NOT NULL CONSTRAINT DF_banci_motivo_activo DEFAULT (1), CONSTRAINT CK_banci_motivo_clave CHECK (clave IN (1, 2, 3)));
INSERT INTO dbo.banci_catalogo_motivo_localizacion (clave, descripcion)
SELECT v.clave, v.descripcion FROM (VALUES (1, N''Voluntaria''), (2, N''Delito''), (3, N''No identificado'')) v(clave, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM dbo.banci_catalogo_motivo_localizacion c WHERE c.clave = v.clave);
IF EXISTS (SELECT 1 FROM dbo.banci_catalogo_motivo_localizacion WHERE (clave = 1 AND descripcion <> N''Voluntaria'') OR (clave = 2 AND descripcion <> N''Delito'') OR (clave = 3 AND descripcion <> N''No identificado'') OR activo <> 1)
    THROW 52505, ''El catálogo de motivo de localización difiere de las claves acordadas.'', 1;';

EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.FK_banci_victima_motivo_localizacion'', N''F'') IS NULL ALTER TABLE dbo.banci_victima WITH CHECK ADD CONSTRAINT FK_banci_victima_motivo_localizacion FOREIGN KEY (voluntaria_o_fue_delito) REFERENCES dbo.banci_catalogo_motivo_localizacion(clave);';

EXEC sys.sp_executesql N'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N''dbo.banci_carpeta_investigacion'') AND name = N''UX_banci_carpeta_no_banci'') CREATE UNIQUE INDEX UX_banci_carpeta_no_banci ON dbo.banci_carpeta_investigacion(no_banci) WHERE no_banci IS NOT NULL;';

EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_asignar_folios_v2 @IdEntidad TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Interno: la integración o la migración son dueñas de la transacción.
    IF @@TRANCOUNT = 0 OR XACT_STATE() <> 1 THROW 52501, ''Asignar folios requiere una transacción activa.'', 1;
    DECLARE @Lock INT;
    EXEC @Lock = sys.sp_getapplock @Resource = N''BANCI:FOLIOS:V2'', @LockMode = N''Exclusive'', @LockOwner = N''Transaction'', @LockTimeout = 10000;
    IF @Lock < 0 THROW 52502, ''No se pudo reservar el consecutivo BANCI.'', 1;
    SELECT c.id_banci_carpeta_investigacion AS id, c.id_entidad_federativa AS entidad, YEAR(c.fecha_registro) AS anio,
        ROW_NUMBER() OVER (PARTITION BY c.id_entidad_federativa, YEAR(c.fecha_registro) ORDER BY c.id_banci_carpeta_investigacion) AS numero
    INTO #Asignar
    FROM dbo.banci_carpeta_investigacion c WITH (UPDLOCK, HOLDLOCK)
    WHERE c.no_banci IS NULL AND (@IdEntidad IS NULL OR c.id_entidad_federativa = @IdEntidad);
    IF EXISTS (SELECT 1 FROM #Asignar WHERE entidad NOT BETWEEN 1 AND 32 OR anio NOT BETWEEN 1900 AND 9999)
        THROW 52503, ''Entidad o año de registro inválido para asignar el folio.'', 1;
    INSERT INTO dbo.banci_consecutivo_carpeta (id_entidad_federativa, anio, ultimo)
    SELECT entidad, anio, 0 FROM #Asignar a
    WHERE NOT EXISTS (SELECT 1 FROM dbo.banci_consecutivo_carpeta n WITH (UPDLOCK, HOLDLOCK) WHERE n.id_entidad_federativa = a.entidad AND n.anio = a.anio)
    GROUP BY entidad, anio;
    IF EXISTS (SELECT 1 FROM #Asignar a JOIN dbo.banci_consecutivo_carpeta n ON n.id_entidad_federativa = a.entidad AND n.anio = a.anio WHERE a.numero + n.ultimo > 999999)
        THROW 52504, ''Se agotaron los seis dígitos del consecutivo BANCI para entidad/año.'', 1;
    UPDATE c SET no_banci = CONCAT(N''BANCI/'', RIGHT(N''00'' + CONVERT(NVARCHAR(2), a.entidad), 2), N''/'', a.anio, N''/'', RIGHT(N''000000'' + CONVERT(NVARCHAR(6), a.numero + n.ultimo), 6))
    FROM dbo.banci_carpeta_investigacion c JOIN #Asignar a ON a.id = c.id_banci_carpeta_investigacion
    JOIN dbo.banci_consecutivo_carpeta n ON n.id_entidad_federativa = a.entidad AND n.anio = a.anio;
    UPDATE n SET ultimo = n.ultimo + x.total FROM dbo.banci_consecutivo_carpeta n
    JOIN (SELECT entidad, anio, COUNT(*) AS total FROM #Asignar GROUP BY entidad, anio) x ON x.entidad = n.id_entidad_federativa AND x.anio = n.anio;
END;';

EXEC sys.sp_executesql N'EXEC dbo.sp_banci_asignar_folios_v2;';

EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_delito_localizacion_catalogo AS
SELECT clave2 AS clave, delito AS descripcion FROM dbo.catalogo_delito WHERE activo = 1;';

EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_victimas_v2 AS
SELECT c.id_entidad_federativa, c.no_banci, c.id_ci, c.ntra_ci, c.fha_de_ini,
    c.id_banci_carpeta_investigacion, d.id_banci_delito, d.id_delito, v.id_banci_victima, v.id_vicf,
    v.id_tv, v.id_tpm, v.sexo, v.genero, v.pob, v.disc, v.fha_nac, v.edad, v.nacional,
    v.folio_rnpdno, v.pro_apellido, v.sdo_apellido, v.nomb, v.entidad_nacimiento, v.estado_migratorio, v.curp, v.rfc,
    v.localizado_o_no_localizado, v.con_o_sin_vida, v.fecha_localizacion, v.voluntaria_o_fue_delito, v.delito, v.acciones_busqueda, v.obs,
    v.version_banci, v.fecha_modificacion
FROM dbo.banci_carpeta_investigacion c JOIN dbo.banci_delito d ON d.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion
JOIN dbo.banci_victima v ON v.id_banci_delito = d.id_banci_delito WHERE c.activo = 1 AND d.activo = 1 AND v.activo = 1;';

EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.banci_actualizacion_v2'', N''U'') IS NULL
CREATE TABLE dbo.banci_actualizacion_v2 (
    id_actualizacion BIGINT IDENTITY NOT NULL CONSTRAINT PK_banci_actualizacion_v2 PRIMARY KEY,
    codigo_referencia UNIQUEIDENTIFIER NOT NULL CONSTRAINT UQ_banci_actualizacion_v2_referencia UNIQUE,
    id_entidad_federativa TINYINT NOT NULL, id_usuario INT NOT NULL, origen NVARCHAR(20) NOT NULL,
    datos_json NVARCHAR(MAX) NOT NULL, advertencias_json NVARCHAR(MAX) NOT NULL,
    estado NVARCHAR(20) NOT NULL CONSTRAINT DF_banci_actualizacion_v2_estado DEFAULT N''PENDIENTE'',
    fecha_registro DATETIME2(7) NOT NULL CONSTRAINT DF_banci_actualizacion_v2_fecha DEFAULT SYSDATETIME(),
    fecha_decision DATETIME2(7) NULL, total_cambios INT NULL,
    CONSTRAINT CK_banci_actualizacion_v2_json CHECK (ISJSON(datos_json) = 1 AND ISJSON(advertencias_json) = 1),
    CONSTRAINT CK_banci_actualizacion_v2_estado CHECK (estado IN (N''PENDIENTE'', N''INTEGRADA'', N''RECHAZADA'')),
    CONSTRAINT CK_banci_actualizacion_v2_origen CHECK (origen IN (N''FORMULARIO'', N''EXCEL'')),
    CONSTRAINT FK_banci_actualizacion_v2_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
    CONSTRAINT FK_banci_actualizacion_v2_usuario FOREIGN KEY (id_usuario) REFERENCES dbo.usuario(id_usuario)
);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N''dbo.banci_actualizacion_v2'') AND name = N''IX_banci_actualizacion_v2_usuario'')
CREATE INDEX IX_banci_actualizacion_v2_usuario ON dbo.banci_actualizacion_v2(id_usuario, estado, fecha_registro);';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_historial_cambio'', N''id_actualizacion_v2'') IS NULL ALTER TABLE dbo.banci_historial_cambio ADD id_actualizacion_v2 BIGINT NULL;';

EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.FK_banci_historial_actualizacion_v2'', N''F'') IS NULL ALTER TABLE dbo.banci_historial_cambio WITH CHECK ADD CONSTRAINT FK_banci_historial_actualizacion_v2 FOREIGN KEY (id_actualizacion_v2) REFERENCES dbo.banci_actualizacion_v2(id_actualizacion);';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_historial_cambio'', N''no_banci_carpeta'') IS NULL ALTER TABLE dbo.banci_historial_cambio ADD no_banci_carpeta NVARCHAR(40) NULL;';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
