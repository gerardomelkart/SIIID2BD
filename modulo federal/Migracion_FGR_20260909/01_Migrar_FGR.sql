-- Ejecutar en SSMS / Consulta / Modo SQLCMD, conectado al servidor destino.
-- 0 = validar sin insertar registros en siiid2. 1 = insertar y confirmar la transaccion.
:setvar Aplicar "0"
:setvar Carpeta "D:\CNI\MigracionFederal\FGR_20260909"
:ON ERROR EXIT
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_WARNINGS ON;
SET NUMERIC_ROUNDABORT OFF;
SET DATEFORMAT ymd;
IF DB_NAME() <> N'siiid2' THROW 51000, 'La base destino debe ser siiid2.', 1;
IF @@TRANCOUNT <> 0 THROW 51000, 'Ejecute en una ventana sin transacciones abiertas.', 1;
IF N'$(Aplicar)' NOT IN (N'0', N'1') THROW 51000, 'Aplicar solo admite 0 o 1.', 1;
IF OBJECT_ID('tempdb..#FgrCarpetas') IS NOT NULL DROP TABLE #FgrCarpetas;
IF OBJECT_ID('tempdb..#FgrDelitos') IS NOT NULL DROP TABLE #FgrDelitos;
IF OBJECT_ID('tempdb..#FgrVictimas') IS NOT NULL DROP TABLE #FgrVictimas;
IF OBJECT_ID('tempdb..#FgrPeriodos') IS NOT NULL DROP TABLE #FgrPeriodos;
IF OBJECT_ID('tempdb..#FgrIncidencias') IS NOT NULL DROP TABLE #FgrIncidencias;
IF OBJECT_ID('tempdb..#FgrDelitosConvertidos') IS NOT NULL DROP TABLE #FgrDelitosConvertidos;
IF OBJECT_ID('tempdb..#FgrVictimasConvertidas') IS NOT NULL DROP TABLE #FgrVictimasConvertidas;
IF OBJECT_ID('tempdb..#FgrMapaCarga') IS NOT NULL DROP TABLE #FgrMapaCarga;
IF OBJECT_ID('tempdb..#FgrMapaCarpeta') IS NOT NULL DROP TABLE #FgrMapaCarpeta;
IF OBJECT_ID('tempdb..#FgrMapaDelito') IS NOT NULL DROP TABLE #FgrMapaDelito;
IF OBJECT_ID('tempdb..#FgrMapaVictima') IS NOT NULL DROP TABLE #FgrMapaVictima;
GO
:r "$(Carpeta)\02_Datos_FGR.sql"
GO
DECLARE @Aplicar BIT = $(Aplicar);
DECLARE @Usuario INT;
DECLARE @FechaMigracion DATETIME2(0) = SYSDATETIME();
DECLARE @ResultadoLock INT;
CREATE TABLE #FgrPeriodos
(
    codigo_referencia NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY,
    anio SMALLINT NOT NULL, mes TINYINT NOT NULL,
    carpetas INT NOT NULL, delitos INT NOT NULL, victimas INT NOT NULL,
    primer_registro DATETIME2(0) NOT NULL, ultimo_registro DATETIME2(0) NOT NULL
);
INSERT INTO #FgrPeriodos VALUES
(N'69852ac67e7f6', 2026, 1, 6312, 6328, 6963, N'2026-02-05 17:41:58', N'2026-02-05 17:41:58'),
(N'69b0a1035db12', 2026, 2, 6765, 6776, 7566, N'2026-03-10 16:53:55', N'2026-03-10 16:53:55'),
(N'69d274fb94bb4', 2026, 3, 7728, 7742, 8604, N'2026-04-05 08:43:07', N'2026-04-05 08:43:07'),
(N'69fd42e6c8c78', 2026, 4, 7308, 7330, 8168, N'2026-05-07 19:56:54', N'2026-05-07 19:56:54'),
(N'6a22f25900e9e', 2026, 5, 7418, 7433, 8310, N'2026-06-05 09:59:21', N'2026-06-05 09:59:21'),
(N'6a4a70cf9497f', 2026, 6, 7925, 7939, 8881, N'2026-07-05 08:57:19', N'2026-07-05 08:57:19'),
(N'6a7394e72121d', 2026, 7, 7786, 7800, 8686, N'2026-08-05 13:54:15', N'2026-08-05 13:54:15'),
(N'6a9c5e582fdff', 2026, 8, 7281, 7290, 8188, N'2026-09-05 12:24:24', N'2026-09-05 12:24:24');

CREATE TABLE #FgrIncidencias (catalogo NVARCHAR(100), clave NVARCHAR(150), registros BIGINT);
CREATE TABLE #FgrMapaCarga (codigo_referencia NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY, id_destino BIGINT NOT NULL UNIQUE);
CREATE TABLE #FgrMapaCarpeta (pk_origen BIGINT PRIMARY KEY, id_destino BIGINT NOT NULL UNIQUE, codigo_referencia NVARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL);
CREATE TABLE #FgrMapaDelito (pk_origen BIGINT PRIMARY KEY, id_destino BIGINT NOT NULL UNIQUE, codigo_referencia NVARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL);
CREATE TABLE #FgrMapaVictima (pk_origen BIGINT PRIMARY KEY, id_destino BIGINT NOT NULL UNIQUE, codigo_referencia NVARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL);

BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @ResultadoLock = sys.sp_getapplock @Resource = N'FGR_MIGRACION_20260909', @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 0;
    IF @ResultadoLock < 0 THROW 51000, 'Otra sesion esta ejecutando esta migracion.', 1;

    SELECT @Usuario = u.id_usuario
    FROM dbo.usuario u WITH (HOLDLOCK)
    WHERE u.usuario = N'FGRX26011400'
      AND u.activo = 1;

    IF @Usuario IS NULL
        THROW 51000, 'No existe el usuario activo FGRX26011400 en la base destino.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.usuario u WITH (HOLDLOCK)
        JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol
        WHERE u.id_usuario = @Usuario AND u.usuario = N'FGRX26011400'
          AND u.activo = 1 AND u.id_entidad_federativa IS NULL AND r.rol = N'ENLACE_ESTATAL'
    ) THROW 51000, 'El usuario FGRX26011400 no corresponde a un usuario nacional ENLACE_ESTATAL activo esperado.', 1;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.usuario_modulo um WITH (HOLDLOCK)
        JOIN dbo.catalogo_modulo m WITH (HOLDLOCK) ON m.id_modulo = um.id_modulo
        WHERE um.id_usuario = @Usuario AND m.clave = N'FEDERAL'
          AND m.activo = 1 AND um.activo = 1 AND um.habilitado = 1
    ) THROW 51000, 'El usuario FGR no tiene acceso activo a Federal.', 1;
    IF OBJECT_ID(N'dbo.federal_migracion_fgr_20260909_mapa', N'U') IS NOT NULL
        THROW 51000, 'Ya existe el mapa de esta migracion. No se repetira la importacion.', 1;

    IF EXISTS
    (
        SELECT 1 FROM dbo.federal_carga c WITH (UPDLOCK, HOLDLOCK)
        JOIN #FgrPeriodos p ON p.codigo_referencia = c.codigo_referencia
           OR (p.anio = c.anio_corte AND p.mes = c.mes_corte)
    )
    BEGIN
        SELECT c.id_federal_carga, c.codigo_referencia, c.anio_corte, c.mes_corte, c.estado, c.activo
        FROM dbo.federal_carga c JOIN #FgrPeriodos p
          ON p.codigo_referencia = c.codigo_referencia OR (p.anio = c.anio_corte AND p.mes = c.mes_corte);
        THROW 51000, 'Hay cargas federales existentes en los cortes de origen. No se sobreescribiran.', 1;
    END;
    IF (SELECT COUNT_BIG(*) FROM #FgrCarpetas) <> 58523
       OR (SELECT COUNT_BIG(*) FROM #FgrDelitos) <> 58638
       OR (SELECT COUNT_BIG(*) FROM #FgrVictimas) <> 65366
        THROW 51000, 'El archivo de datos no esta completo.', 1;
    IF EXISTS (SELECT 1 FROM #FgrCarpetas WHERE usuario_reg IS NULL OR usuario_reg <> N'FGRX26011400')
       OR EXISTS (SELECT 1 FROM #FgrDelitos WHERE usuario_reg IS NULL OR usuario_reg <> N'FGRX26011400')
       OR EXISTS (SELECT 1 FROM #FgrVictimas WHERE usuario_reg IS NULL OR usuario_reg <> N'FGRX26011400')
        THROW 51000, 'Hay registros de un usuario distinto de FGR.', 1;
    IF EXISTS
    (
        SELECT 1 FROM #FgrDelitos d LEFT JOIN #FgrCarpetas c ON c.pk_ci = d.pk_ci
        WHERE c.pk_ci IS NULL OR c.codigo_referencia <> d.codigo_referencia OR c.id_ci <> d.id_ci
           OR c.mes_corte <> d.mes_corte OR c.anio_corte <> d.anio_corte
    ) THROW 51000, 'Un delito no coincide con su carpeta de origen.', 1;
    IF EXISTS
    (
        SELECT 1 FROM #FgrVictimas v LEFT JOIN #FgrDelitos d ON d.pk_del = v.pk_del
        WHERE d.pk_del IS NULL OR d.pk_ci <> v.pk_ci OR d.codigo_referencia <> v.codigo_referencia
           OR d.id_ci <> v.id_ci OR d.id_delito <> v.id_delito
           OR d.mes_corte <> v.mes_corte OR d.anio_corte <> v.anio_corte
    ) THROW 51000, 'Una victima no coincide con su delito de origen.', 1;

    IF EXISTS
    (
        SELECT s.codigo_referencia, TRY_CONVERT(SMALLINT, s.anio_corte), TRY_CONVERT(TINYINT, s.mes_corte), COUNT_BIG(*)
        FROM #FgrCarpetas s GROUP BY s.codigo_referencia, s.anio_corte, s.mes_corte
        EXCEPT SELECT codigo_referencia, anio, mes, carpetas FROM #FgrPeriodos
    ) OR EXISTS
    (
        SELECT codigo_referencia, anio, mes, carpetas FROM #FgrPeriodos
        EXCEPT SELECT s.codigo_referencia, TRY_CONVERT(SMALLINT, s.anio_corte), TRY_CONVERT(TINYINT, s.mes_corte), COUNT_BIG(*)
        FROM #FgrCarpetas s GROUP BY s.codigo_referencia, s.anio_corte, s.mes_corte
    ) THROW 51000, 'No coinciden los conteos por periodo de tbl_carpetas.', 1;

    IF EXISTS
    (
        SELECT s.codigo_referencia, TRY_CONVERT(SMALLINT, s.anio_corte), TRY_CONVERT(TINYINT, s.mes_corte), COUNT_BIG(*)
        FROM #FgrDelitos s GROUP BY s.codigo_referencia, s.anio_corte, s.mes_corte
        EXCEPT SELECT codigo_referencia, anio, mes, delitos FROM #FgrPeriodos
    ) OR EXISTS
    (
        SELECT codigo_referencia, anio, mes, delitos FROM #FgrPeriodos
        EXCEPT SELECT s.codigo_referencia, TRY_CONVERT(SMALLINT, s.anio_corte), TRY_CONVERT(TINYINT, s.mes_corte), COUNT_BIG(*)
        FROM #FgrDelitos s GROUP BY s.codigo_referencia, s.anio_corte, s.mes_corte
    ) THROW 51000, 'No coinciden los conteos por periodo de tbl_delitos.', 1;

    IF EXISTS
    (
        SELECT s.codigo_referencia, TRY_CONVERT(SMALLINT, s.anio_corte), TRY_CONVERT(TINYINT, s.mes_corte), COUNT_BIG(*)
        FROM #FgrVictimas s GROUP BY s.codigo_referencia, s.anio_corte, s.mes_corte
        EXCEPT SELECT codigo_referencia, anio, mes, victimas FROM #FgrPeriodos
    ) OR EXISTS
    (
        SELECT codigo_referencia, anio, mes, victimas FROM #FgrPeriodos
        EXCEPT SELECT s.codigo_referencia, TRY_CONVERT(SMALLINT, s.anio_corte), TRY_CONVERT(TINYINT, s.mes_corte), COUNT_BIG(*)
        FROM #FgrVictimas s GROUP BY s.codigo_referencia, s.anio_corte, s.mes_corte
    ) THROW 51000, 'No coinciden los conteos por periodo de tbl_victimas.', 1;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_forma_accion', CONVERT(NVARCHAR(150), s.forma_acc), COUNT_BIG(*)
    FROM #FgrDelitos s
    WHERE (SELECT COUNT_BIG(*) FROM dbo.catalogo_forma_accion cat WITH (HOLDLOCK) WHERE TRY_CONVERT(INT, cat.clave) = TRY_CONVERT(INT, s.forma_acc) AND cat.activo = 1) <> 1
    GROUP BY s.forma_acc;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_instrumento_comision', CONVERT(NVARCHAR(150), s.emto_com_dto), COUNT_BIG(*)
    FROM #FgrDelitos s
    WHERE (SELECT COUNT_BIG(*) FROM dbo.catalogo_instrumento_comision cat WITH (HOLDLOCK) WHERE TRY_CONVERT(INT, cat.clave) = TRY_CONVERT(INT, s.emto_com_dto) AND cat.activo = 1) <> 1
    GROUP BY s.emto_com_dto;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_grado_consumacion', CONVERT(NVARCHAR(150), s.grdo_cons), COUNT_BIG(*)
    FROM #FgrDelitos s
    WHERE (SELECT COUNT_BIG(*) FROM dbo.catalogo_grado_consumacion cat WITH (HOLDLOCK) WHERE TRY_CONVERT(INT, cat.clave) = TRY_CONVERT(INT, s.grdo_cons) AND cat.activo = 1) <> 1
    GROUP BY s.grdo_cons;
    INSERT INTO #FgrIncidencias
    SELECT N'federal_catalogo_modalidad_delito', CONVERT(NVARCHAR(150), s.clasf_de_dto), COUNT_BIG(*)
    FROM #FgrDelitos s
    WHERE (SELECT COUNT_BIG(*) FROM dbo.federal_catalogo_modalidad_delito cat WITH (HOLDLOCK) WHERE cat.clave4 = s.clasf_de_dto AND cat.activo = 1) <> 1
    GROUP BY s.clasf_de_dto;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_entidad_federativa', CONVERT(NVARCHAR(150), s.id_ent_hchos), COUNT_BIG(*)
    FROM #FgrDelitos s
    WHERE (SELECT COUNT_BIG(*) FROM dbo.catalogo_entidad_federativa cat WITH (HOLDLOCK) WHERE TRY_CONVERT(INT, cat.id_entidad_federativa) = TRY_CONVERT(INT, s.id_ent_hchos) AND cat.activo = 1) <> 1
    GROUP BY s.id_ent_hchos;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_municipio', CONCAT(s.id_ent_hchos, N'/', s.id_mun_hchos), COUNT_BIG(*)
    FROM #FgrDelitos s
    WHERE (SELECT COUNT_BIG(*) FROM dbo.catalogo_municipio cat WITH (HOLDLOCK)
           WHERE cat.id_entidad_federativa = s.id_ent_hchos AND TRY_CONVERT(INT, cat.clave) = s.id_mun_hchos AND cat.activo = 1) <> 1
    GROUP BY s.id_ent_hchos, s.id_mun_hchos;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_tipo_victima', CONVERT(NVARCHAR(150), s.id_tv), COUNT_BIG(*)
    FROM #FgrVictimas s
    WHERE (SELECT COUNT_BIG(*) FROM dbo.catalogo_tipo_victima cat WITH (HOLDLOCK)
           WHERE TRY_CONVERT(INT, cat.clave) = s.id_tv AND cat.activo = 1) <> 1
    GROUP BY s.id_tv;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_tipo_victima_moral', CONVERT(NVARCHAR(150), s.id_tpm), COUNT_BIG(*)
    FROM #FgrVictimas s
    WHERE s.id_tpm IS NOT NULL AND s.id_tpm <> 0 AND (SELECT COUNT_BIG(*) FROM dbo.catalogo_tipo_victima_moral cat WITH (HOLDLOCK)
           WHERE TRY_CONVERT(INT, cat.clave) = s.id_tpm AND cat.activo = 1) <> 1
    GROUP BY s.id_tpm;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_sexo', CONVERT(NVARCHAR(150), s.sexo), COUNT_BIG(*)
    FROM #FgrVictimas s
    WHERE s.sexo IS NOT NULL AND s.sexo <> 0 AND (SELECT COUNT_BIG(*) FROM dbo.catalogo_sexo cat WITH (HOLDLOCK)
           WHERE TRY_CONVERT(INT, cat.clave) = s.sexo AND cat.activo = 1) <> 1
    GROUP BY s.sexo;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_genero', CONVERT(NVARCHAR(150), s.genero), COUNT_BIG(*)
    FROM #FgrVictimas s
    WHERE s.genero IS NOT NULL AND s.genero <> 0 AND (SELECT COUNT_BIG(*) FROM dbo.catalogo_genero cat WITH (HOLDLOCK)
           WHERE TRY_CONVERT(INT, cat.clave) = s.genero AND cat.activo = 1) <> 1
    GROUP BY s.genero;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_nacionalidad', CONVERT(NVARCHAR(150), s.nacional), COUNT_BIG(*)
    FROM #FgrVictimas s
    WHERE s.nacional IS NOT NULL AND s.nacional <> 0 AND (SELECT COUNT_BIG(*) FROM dbo.catalogo_nacionalidad cat WITH (HOLDLOCK)
           WHERE TRY_CONVERT(INT, cat.clave) = s.nacional AND cat.activo = 1) <> 1
    GROUP BY s.nacional;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_pertenece_poblacion_indigena', CONVERT(NVARCHAR(150), s.pob), COUNT_BIG(*)
    FROM #FgrVictimas s
    WHERE s.pob IS NOT NULL AND s.pob <> 0 AND (SELECT COUNT_BIG(*) FROM dbo.catalogo_pertenece_poblacion_indigena cat WITH (HOLDLOCK)
           WHERE TRY_CONVERT(INT, cat.clave) = s.pob AND cat.activo = 1) <> 1
    GROUP BY s.pob;
    INSERT INTO #FgrIncidencias
    SELECT N'catalogo_presenta_discapacidad', CONVERT(NVARCHAR(150), s.disc), COUNT_BIG(*)
    FROM #FgrVictimas s
    WHERE s.disc IS NOT NULL AND s.disc <> 0 AND (SELECT COUNT_BIG(*) FROM dbo.catalogo_presenta_discapacidad cat WITH (HOLDLOCK)
           WHERE TRY_CONVERT(INT, cat.clave) = s.disc AND cat.activo = 1) <> 1
    GROUP BY s.disc;
    IF EXISTS (SELECT 1 FROM #FgrIncidencias)
    BEGIN
        SELECT catalogo, clave, registros FROM #FgrIncidencias ORDER BY catalogo, clave;
        THROW 51000, 'Hay claves sin equivalencia unica activa en destino. No se omitira ningun registro.', 1;
    END;

    SELECT s.pk_del, s.pk_ci, s.codigo_referencia,
        s.id_delito AS identificador_delito_fiscalia,
        s.dto AS delito_fiscalia,
        s.moda_dto AS modalidad_delito_fiscalia,
        fa.id_forma_accion AS id_forma_accion,
        CONVERT(DATETIME2(0), CONCAT(s.fha_de_hchos, N'T', s.hra_de_hchos), 126) AS fecha_hechos,
        ic.id_instrumento_comision AS id_instrumento_comision,
        gc.id_grado_consumacion AS id_grado_consumacion,
        md.id_modalidad_delito AS id_modalidad_delito,
        ef.id_entidad_federativa AS id_entidad_federativa,
        mun.id_municipio AS id_municipio,
        CONVERT(NVARCHAR(250), s.id_loc_hchos) AS id_localidad_fiscalia,
        s.nom_loc_hchos AS localidad_fiscalia_nombre,
        CONVERT(NVARCHAR(250), s.id_col_hchos) AS id_colonia_fiscalia,
        s.nom_col_hchos AS colonia_fiscalia_nombre,
        cp.id_codigo_postal AS id_codigo_postal,
        NULLIF(CONVERT(NVARCHAR(50), s.cp), N'') AS codigo_postal_fiscalia,
        CONVERT(DECIMAL(10,6), NULLIF(s.coord_x, N'')) AS coordenada_x,
        CONVERT(DECIMAL(10,6), NULLIF(s.coord_y, N'')) AS coordenada_y,
        s.dom_hchos AS domicilio_hechos,
        @Usuario AS id_usuario_registro,
        CONVERT(DATETIME2(0), s.fcha_insert, 120) AS fecha_registro,
        CAST(1 AS BIT) AS activo
    INTO #FgrDelitosConvertidos
    FROM #FgrDelitos s
    JOIN dbo.catalogo_forma_accion fa WITH (HOLDLOCK) ON fa.clave = CONVERT(INT, s.forma_acc) AND fa.activo = 1
    JOIN dbo.catalogo_instrumento_comision ic WITH (HOLDLOCK) ON ic.clave = CONVERT(INT, s.emto_com_dto) AND ic.activo = 1
    JOIN dbo.catalogo_grado_consumacion gc WITH (HOLDLOCK) ON gc.clave = CONVERT(INT, s.grdo_cons) AND gc.activo = 1
    JOIN dbo.federal_catalogo_modalidad_delito md WITH (HOLDLOCK) ON md.clave4 = s.clasf_de_dto AND md.activo = 1
    JOIN dbo.catalogo_entidad_federativa ef WITH (HOLDLOCK) ON ef.id_entidad_federativa = s.id_ent_hchos AND ef.activo = 1
    JOIN dbo.catalogo_municipio mun WITH (HOLDLOCK) ON mun.id_entidad_federativa = s.id_ent_hchos AND TRY_CONVERT(INT, mun.clave) = s.id_mun_hchos AND mun.activo = 1
    OUTER APPLY
    (
        SELECT TOP (1) cat.id_codigo_postal FROM dbo.catalogo_codigo_postal cat WITH (HOLDLOCK)
        WHERE cat.codigo_postal = RIGHT(N'00000' + CONVERT(NVARCHAR(50), s.cp), 5)
          AND cat.id_municipio = mun.id_municipio AND cat.activo = 1
        ORDER BY cat.id_codigo_postal
    ) cp;
    CREATE UNIQUE CLUSTERED INDEX IX_FgrDelitosConvertidos ON #FgrDelitosConvertidos(pk_del);

    SELECT s.pk_vict, s.pk_del, s.codigo_referencia,
        s.id_vicf AS identificador_victima_fiscalia,
        tv.id_tipo_victima AS id_tipo_victima,
        tvm.id_tipo_victima_moral AS id_tipo_victima_moral,
        sx.id_sexo AS id_sexo,
        gen.id_genero AS id_genero,
        nac.id_nacionalidad AS id_nacionalidad,
        pob.id_pertenece_poblacion_indigena AS id_pertenece_poblacion_indigena,
        disc.id_presenta_discapacidad AS id_presenta_discapacidad,
        CONVERT(DATE, NULLIF(s.fha_nac, N''), 23) AS fecha_nacimiento,
        CONVERT(SMALLINT, NULLIF(s.edad, N'')) AS edad,
        @Usuario AS id_usuario_registro,
        CONVERT(DATETIME2(0), s.fcha_insert, 120) AS fecha_registro,
        CAST(1 AS BIT) AS activo
    INTO #FgrVictimasConvertidas
    FROM #FgrVictimas s
    JOIN dbo.catalogo_tipo_victima tv WITH (HOLDLOCK) ON tv.clave = s.id_tv AND tv.activo = 1
    LEFT JOIN dbo.catalogo_tipo_victima_moral tvm WITH (HOLDLOCK) ON tvm.clave = NULLIF(s.id_tpm, 0) AND tvm.activo = 1
    LEFT JOIN dbo.catalogo_sexo sx WITH (HOLDLOCK) ON sx.clave = NULLIF(s.sexo, 0) AND sx.activo = 1
    LEFT JOIN dbo.catalogo_genero gen WITH (HOLDLOCK) ON gen.clave = NULLIF(s.genero, 0) AND gen.activo = 1
    LEFT JOIN dbo.catalogo_nacionalidad nac WITH (HOLDLOCK) ON TRY_CONVERT(INT, nac.clave) = NULLIF(s.nacional, 0) AND nac.activo = 1
    LEFT JOIN dbo.catalogo_pertenece_poblacion_indigena pob WITH (HOLDLOCK) ON pob.clave = NULLIF(s.pob, 0) AND pob.activo = 1
    LEFT JOIN dbo.catalogo_presenta_discapacidad disc WITH (HOLDLOCK) ON disc.clave = NULLIF(s.disc, 0) AND disc.activo = 1;
    CREATE UNIQUE CLUSTERED INDEX IX_FgrVictimasConvertidas ON #FgrVictimasConvertidas(pk_vict);

    IF (SELECT COUNT_BIG(*) FROM #FgrDelitosConvertidos) <> 58638 OR (SELECT COUNT_BIG(*) FROM #FgrVictimasConvertidas) <> 65366
        THROW 51000, 'La conversion de catalogos altero los conteos.', 1;
    -- Dates in this fixed dump are ISO and present for every folder/offense.
    IF EXISTS (SELECT 1 FROM #FgrCarpetas WHERE TRY_CONVERT(DATETIME2(0), CONCAT(fha_de_ini, N'T', hra_de_ini), 126) IS NULL OR TRY_CONVERT(DATETIME2(0), fcha_insert, 120) IS NULL)
        THROW 51000, 'Fecha de carpeta no convertible.', 1;
    IF EXISTS (SELECT 1 FROM #FgrDelitosConvertidos WHERE fecha_hechos IS NULL OR fecha_registro IS NULL)
       OR EXISTS (SELECT 1 FROM #FgrVictimasConvertidas WHERE fecha_registro IS NULL)
        THROW 51000, 'Fecha de registro no convertible.', 1;

    SELECT @@SERVERNAME AS servidor_destino, DB_NAME() AS base_destino, @Usuario AS id_usuario_FGR,
           @Aplicar AS aplicar, 8 AS envios, 58523 AS carpetas, 58638 AS delitos, 65366 AS victimas;
    SELECT anio, mes, codigo_referencia, carpetas, delitos, victimas, primer_registro, ultimo_registro FROM #FgrPeriodos ORDER BY anio, mes;
    SELECT N'Pares historicos conservados' AS concepto, COUNT(*) AS pares
    FROM (SELECT codigo_referencia, id_ci, id_delito FROM #FgrDelitos GROUP BY codigo_referencia, id_ci, id_delito HAVING COUNT(*) = 2) d;
    SELECT N'Codigo postal conservado como texto sin FK' AS concepto, COUNT_BIG(*) AS registros
    FROM #FgrDelitosConvertidos WHERE codigo_postal_fiscalia IS NOT NULL AND id_codigo_postal IS NULL;
    IF @Aplicar = 0
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT N'VALIDACION CORRECTA. No se insertaron registros en siiid2. Cambie Aplicar a 1 y ejecute el mismo archivo para importar.';
        RETURN;
    END;

    -- One trace table links every legacy PK to its SQL Server identity.
    -- No legacy business identifier is rewritten or deduplicated.
    CREATE TABLE dbo.federal_migracion_fgr_20260909_mapa
    (
        tipo NVARCHAR(10) NOT NULL,
        clave_origen NVARCHAR(50) NOT NULL,
        id_destino BIGINT NOT NULL,
        codigo_referencia NVARCHAR(50) NOT NULL,
        sha256_respaldo CHAR(64) NOT NULL,
        fecha_migracion DATETIME2(0) NOT NULL,
        ejecutado_por NVARCHAR(128) NOT NULL,
        CONSTRAINT PK_federal_migracion_fgr_20260909_mapa PRIMARY KEY (tipo, clave_origen),
        CONSTRAINT UQ_federal_migracion_fgr_20260909_destino UNIQUE (tipo, id_destino)
    );
    MERGE dbo.federal_carga AS destino
    USING #FgrPeriodos AS origen ON 1 = 0
    WHEN NOT MATCHED THEN INSERT
    (id_usuario_carga, id_entidad_federativa, codigo_referencia, tipo_carga, mes_corte, anio_corte,
     fecha_carga, total_carpetas_investigacion, total_delitos, total_victimas, estado,
     fecha_validacion, fecha_confirmacion, fecha_expiracion, id_usuario_confirmacion, mensaje_error, rechazo_visto, activo)
    VALUES
    (@Usuario, NULL, origen.codigo_referencia, N'CARGA_INICIAL', origen.mes, origen.anio,
     origen.primer_registro, origen.carpetas, origen.delitos, origen.victimas, N'CONFIRMADO',
     origen.primer_registro, NULL, NULL, NULL, NULL, 1, 1)
    OUTPUT origen.codigo_referencia, inserted.id_federal_carga INTO #FgrMapaCarga(codigo_referencia, id_destino);

    MERGE dbo.federal_carpeta_investigacion AS destino
    USING
    (
        SELECT s.pk_ci AS pk_origen, s.codigo_referencia,
            s.id_ci AS identificador_carpeta_fiscalia,
            s.ntra_ci AS nomenclatura_carpeta_fiscalia,
            CONVERT(DATETIME2(0), CONCAT(s.fha_de_ini, N'T', s.hra_de_ini), 126) AS fecha_inicio,
            s.rmen_de_hchos AS resumen_hechos,
            @Usuario AS id_usuario_registro,
            CONVERT(DATETIME2(0), s.fcha_insert, 120) AS fecha_registro,
            mc.id_destino AS id_federal_carga,
            CAST(1 AS BIT) AS activo
        FROM #FgrCarpetas s JOIN #FgrMapaCarga mc ON mc.codigo_referencia = s.codigo_referencia
    ) AS origen ON 1 = 0
    WHEN NOT MATCHED THEN INSERT
    (identificador_carpeta_fiscalia, nomenclatura_carpeta_fiscalia, fecha_inicio, resumen_hechos, id_usuario_registro, fecha_registro, id_federal_carga, activo)
    VALUES
    (origen.identificador_carpeta_fiscalia, origen.nomenclatura_carpeta_fiscalia, origen.fecha_inicio, origen.resumen_hechos, origen.id_usuario_registro, origen.fecha_registro, origen.id_federal_carga, origen.activo)
    OUTPUT origen.pk_origen, inserted.id_federal_carpeta_investigacion, origen.codigo_referencia INTO #FgrMapaCarpeta(pk_origen, id_destino, codigo_referencia);
    RAISERROR(N'Insertados registros de CARPETA. Verificacion en curso.', 10, 1) WITH NOWAIT;
    IF (SELECT COUNT_BIG(*) FROM #FgrMapaCarpeta) <> 58523
       OR EXISTS
    (
        SELECT m.id_destino, CONVERT(VARBINARY(MAX), s.id_ci), CONVERT(VARBINARY(MAX), s.ntra_ci), CONVERT(DATETIME2(0), CONCAT(s.fha_de_ini, N'T', s.hra_de_ini), 126), CONVERT(VARBINARY(MAX), s.rmen_de_hchos), @Usuario, CONVERT(DATETIME2(0), s.fcha_insert, 120), mc.id_destino, CAST(1 AS BIT)
        FROM #FgrCarpetas s JOIN #FgrMapaCarga mc ON mc.codigo_referencia = s.codigo_referencia JOIN #FgrMapaCarpeta m ON m.pk_origen = s.pk_ci
        EXCEPT
        SELECT d.id_federal_carpeta_investigacion, CONVERT(VARBINARY(MAX), d.identificador_carpeta_fiscalia), CONVERT(VARBINARY(MAX), d.nomenclatura_carpeta_fiscalia), d.fecha_inicio, CONVERT(VARBINARY(MAX), d.resumen_hechos), d.id_usuario_registro, d.fecha_registro, d.id_federal_carga, d.activo
        FROM dbo.federal_carpeta_investigacion d JOIN #FgrMapaCarpeta m ON m.id_destino = d.id_federal_carpeta_investigacion
    ) THROW 51000, 'No coinciden los datos o las relaciones de CARPETA. Se cancela toda la importacion.', 1;

    MERGE dbo.federal_delito AS destino
    USING
    (
        SELECT s.pk_del AS pk_origen, s.codigo_referencia,
            mp.id_destino AS id_federal_carpeta_investigacion,
            s.identificador_delito_fiscalia AS identificador_delito_fiscalia,
            s.delito_fiscalia AS delito_fiscalia,
            s.modalidad_delito_fiscalia AS modalidad_delito_fiscalia,
            s.id_forma_accion AS id_forma_accion,
            s.fecha_hechos AS fecha_hechos,
            s.id_instrumento_comision AS id_instrumento_comision,
            s.id_grado_consumacion AS id_grado_consumacion,
            s.id_modalidad_delito AS id_modalidad_delito,
            s.id_entidad_federativa AS id_entidad_federativa,
            s.id_municipio AS id_municipio,
            s.id_localidad_fiscalia AS id_localidad_fiscalia,
            s.localidad_fiscalia_nombre AS localidad_fiscalia_nombre,
            s.id_colonia_fiscalia AS id_colonia_fiscalia,
            s.colonia_fiscalia_nombre AS colonia_fiscalia_nombre,
            s.id_codigo_postal AS id_codigo_postal,
            s.codigo_postal_fiscalia AS codigo_postal_fiscalia,
            s.coordenada_x AS coordenada_x,
            s.coordenada_y AS coordenada_y,
            s.domicilio_hechos AS domicilio_hechos,
            s.id_usuario_registro AS id_usuario_registro,
            s.fecha_registro AS fecha_registro,
            mc.id_destino AS id_federal_carga,
            s.activo AS activo
        FROM #FgrDelitosConvertidos s JOIN #FgrMapaCarpeta mp ON mp.pk_origen = s.pk_ci JOIN #FgrMapaCarga mc ON mc.codigo_referencia = s.codigo_referencia
    ) AS origen ON 1 = 0
    WHEN NOT MATCHED THEN INSERT
    (id_federal_carpeta_investigacion, identificador_delito_fiscalia, delito_fiscalia, modalidad_delito_fiscalia, id_forma_accion, fecha_hechos, id_instrumento_comision, id_grado_consumacion, id_modalidad_delito, id_entidad_federativa, id_municipio, id_localidad_fiscalia, localidad_fiscalia_nombre, id_colonia_fiscalia, colonia_fiscalia_nombre, id_codigo_postal, codigo_postal_fiscalia, coordenada_x, coordenada_y, domicilio_hechos, id_usuario_registro, fecha_registro, id_federal_carga, activo)
    VALUES
    (origen.id_federal_carpeta_investigacion, origen.identificador_delito_fiscalia, origen.delito_fiscalia, origen.modalidad_delito_fiscalia, origen.id_forma_accion, origen.fecha_hechos, origen.id_instrumento_comision, origen.id_grado_consumacion, origen.id_modalidad_delito, origen.id_entidad_federativa, origen.id_municipio, origen.id_localidad_fiscalia, origen.localidad_fiscalia_nombre, origen.id_colonia_fiscalia, origen.colonia_fiscalia_nombre, origen.id_codigo_postal, origen.codigo_postal_fiscalia, origen.coordenada_x, origen.coordenada_y, origen.domicilio_hechos, origen.id_usuario_registro, origen.fecha_registro, origen.id_federal_carga, origen.activo)
    OUTPUT origen.pk_origen, inserted.id_federal_delito, origen.codigo_referencia INTO #FgrMapaDelito(pk_origen, id_destino, codigo_referencia);
    RAISERROR(N'Insertados registros de DELITO. Verificacion en curso.', 10, 1) WITH NOWAIT;
    IF (SELECT COUNT_BIG(*) FROM #FgrMapaDelito) <> 58638
       OR EXISTS
    (
        SELECT m.id_destino, mp.id_destino, CONVERT(VARBINARY(MAX), s.identificador_delito_fiscalia), CONVERT(VARBINARY(MAX), s.delito_fiscalia), CONVERT(VARBINARY(MAX), s.modalidad_delito_fiscalia), s.id_forma_accion, s.fecha_hechos, s.id_instrumento_comision, s.id_grado_consumacion, s.id_modalidad_delito, s.id_entidad_federativa, s.id_municipio, CONVERT(VARBINARY(MAX), s.id_localidad_fiscalia), CONVERT(VARBINARY(MAX), s.localidad_fiscalia_nombre), CONVERT(VARBINARY(MAX), s.id_colonia_fiscalia), CONVERT(VARBINARY(MAX), s.colonia_fiscalia_nombre), s.id_codigo_postal, CONVERT(VARBINARY(MAX), s.codigo_postal_fiscalia), s.coordenada_x, s.coordenada_y, CONVERT(VARBINARY(MAX), s.domicilio_hechos), s.id_usuario_registro, s.fecha_registro, mc.id_destino, s.activo
        FROM #FgrDelitosConvertidos s JOIN #FgrMapaCarpeta mp ON mp.pk_origen = s.pk_ci JOIN #FgrMapaCarga mc ON mc.codigo_referencia = s.codigo_referencia JOIN #FgrMapaDelito m ON m.pk_origen = s.pk_del
        EXCEPT
        SELECT d.id_federal_delito, d.id_federal_carpeta_investigacion, CONVERT(VARBINARY(MAX), d.identificador_delito_fiscalia), CONVERT(VARBINARY(MAX), d.delito_fiscalia), CONVERT(VARBINARY(MAX), d.modalidad_delito_fiscalia), d.id_forma_accion, d.fecha_hechos, d.id_instrumento_comision, d.id_grado_consumacion, d.id_modalidad_delito, d.id_entidad_federativa, d.id_municipio, CONVERT(VARBINARY(MAX), d.id_localidad_fiscalia), CONVERT(VARBINARY(MAX), d.localidad_fiscalia_nombre), CONVERT(VARBINARY(MAX), d.id_colonia_fiscalia), CONVERT(VARBINARY(MAX), d.colonia_fiscalia_nombre), d.id_codigo_postal, CONVERT(VARBINARY(MAX), d.codigo_postal_fiscalia), d.coordenada_x, d.coordenada_y, CONVERT(VARBINARY(MAX), d.domicilio_hechos), d.id_usuario_registro, d.fecha_registro, d.id_federal_carga, d.activo
        FROM dbo.federal_delito d JOIN #FgrMapaDelito m ON m.id_destino = d.id_federal_delito
    ) THROW 51000, 'No coinciden los datos o las relaciones de DELITO. Se cancela toda la importacion.', 1;

    MERGE dbo.federal_victima AS destino
    USING
    (
        SELECT s.pk_vict AS pk_origen, s.codigo_referencia,
            mp.id_destino AS id_federal_delito,
            s.identificador_victima_fiscalia AS identificador_victima_fiscalia,
            s.id_tipo_victima AS id_tipo_victima,
            s.id_tipo_victima_moral AS id_tipo_victima_moral,
            s.id_sexo AS id_sexo,
            s.id_genero AS id_genero,
            s.id_nacionalidad AS id_nacionalidad,
            s.id_pertenece_poblacion_indigena AS id_pertenece_poblacion_indigena,
            s.id_presenta_discapacidad AS id_presenta_discapacidad,
            s.fecha_nacimiento AS fecha_nacimiento,
            s.edad AS edad,
            s.id_usuario_registro AS id_usuario_registro,
            s.fecha_registro AS fecha_registro,
            mc.id_destino AS id_federal_carga,
            s.activo AS activo
        FROM #FgrVictimasConvertidas s JOIN #FgrMapaDelito mp ON mp.pk_origen = s.pk_del JOIN #FgrMapaCarga mc ON mc.codigo_referencia = s.codigo_referencia
    ) AS origen ON 1 = 0
    WHEN NOT MATCHED THEN INSERT
    (id_federal_delito, identificador_victima_fiscalia, id_tipo_victima, id_tipo_victima_moral, id_sexo, id_genero, id_nacionalidad, id_pertenece_poblacion_indigena, id_presenta_discapacidad, fecha_nacimiento, edad, id_usuario_registro, fecha_registro, id_federal_carga, activo)
    VALUES
    (origen.id_federal_delito, origen.identificador_victima_fiscalia, origen.id_tipo_victima, origen.id_tipo_victima_moral, origen.id_sexo, origen.id_genero, origen.id_nacionalidad, origen.id_pertenece_poblacion_indigena, origen.id_presenta_discapacidad, origen.fecha_nacimiento, origen.edad, origen.id_usuario_registro, origen.fecha_registro, origen.id_federal_carga, origen.activo)
    OUTPUT origen.pk_origen, inserted.id_federal_victima, origen.codigo_referencia INTO #FgrMapaVictima(pk_origen, id_destino, codigo_referencia);
    RAISERROR(N'Insertados registros de VICTIMA. Verificacion en curso.', 10, 1) WITH NOWAIT;
    IF (SELECT COUNT_BIG(*) FROM #FgrMapaVictima) <> 65366
       OR EXISTS
    (
        SELECT m.id_destino, mp.id_destino, CONVERT(VARBINARY(MAX), s.identificador_victima_fiscalia), s.id_tipo_victima, s.id_tipo_victima_moral, s.id_sexo, s.id_genero, s.id_nacionalidad, s.id_pertenece_poblacion_indigena, s.id_presenta_discapacidad, s.fecha_nacimiento, s.edad, s.id_usuario_registro, s.fecha_registro, mc.id_destino, s.activo
        FROM #FgrVictimasConvertidas s JOIN #FgrMapaDelito mp ON mp.pk_origen = s.pk_del JOIN #FgrMapaCarga mc ON mc.codigo_referencia = s.codigo_referencia JOIN #FgrMapaVictima m ON m.pk_origen = s.pk_vict
        EXCEPT
        SELECT d.id_federal_victima, d.id_federal_delito, CONVERT(VARBINARY(MAX), d.identificador_victima_fiscalia), d.id_tipo_victima, d.id_tipo_victima_moral, d.id_sexo, d.id_genero, d.id_nacionalidad, d.id_pertenece_poblacion_indigena, d.id_presenta_discapacidad, d.fecha_nacimiento, d.edad, d.id_usuario_registro, d.fecha_registro, d.id_federal_carga, d.activo
        FROM dbo.federal_victima d JOIN #FgrMapaVictima m ON m.id_destino = d.id_federal_victima
    ) THROW 51000, 'No coinciden los datos o las relaciones de VICTIMA. Se cancela toda la importacion.', 1;

    IF (SELECT COUNT_BIG(*) FROM #FgrMapaCarga) <> 8 THROW 51000, 'No se crearon los ocho envios.', 1;
    IF (SELECT COUNT_BIG(*) FROM (SELECT d.id_federal_carpeta_investigacion, d.identificador_delito_fiscalia
        FROM dbo.federal_delito d JOIN #FgrMapaDelito m ON m.id_destino = d.id_federal_delito
        GROUP BY d.id_federal_carpeta_investigacion, d.identificador_delito_fiscalia HAVING COUNT(*) = 2) pares) <> 115
        THROW 51000, 'No se conservaron los 115 pares historicos.', 1;
    IF EXISTS
    (
        SELECT p.codigo_referencia, p.carpetas FROM #FgrPeriodos p
        EXCEPT SELECT mc.codigo_referencia, COUNT_BIG(*) FROM dbo.federal_carpeta_investigacion d
        JOIN #FgrMapaCarga mc ON mc.id_destino = d.id_federal_carga GROUP BY mc.codigo_referencia
    ) THROW 51000, 'Conteo de carpetas incorrecto por envio.', 1;
    IF EXISTS
    (
        SELECT p.codigo_referencia, p.delitos FROM #FgrPeriodos p
        EXCEPT SELECT mc.codigo_referencia, COUNT_BIG(*) FROM dbo.federal_delito d
        JOIN #FgrMapaCarga mc ON mc.id_destino = d.id_federal_carga GROUP BY mc.codigo_referencia
    ) THROW 51000, 'Conteo de delitos incorrecto por envio.', 1;
    IF EXISTS
    (
        SELECT p.codigo_referencia, p.victimas FROM #FgrPeriodos p
        EXCEPT SELECT mc.codigo_referencia, COUNT_BIG(*) FROM dbo.federal_victima d
        JOIN #FgrMapaCarga mc ON mc.id_destino = d.id_federal_carga GROUP BY mc.codigo_referencia
    ) THROW 51000, 'Conteo de victimas incorrecto por envio.', 1;
    INSERT INTO dbo.federal_migracion_fgr_20260909_mapa
    (tipo, clave_origen, id_destino, codigo_referencia, sha256_respaldo, fecha_migracion, ejecutado_por)
    SELECT N'CARGA', codigo_referencia, id_destino, codigo_referencia, '3bc3fac452b8f6d663ff2f2646579e4effd556799b3ea756415cd33d89dc04f2', @FechaMigracion, ORIGINAL_LOGIN() FROM #FgrMapaCarga
    UNION ALL SELECT N'CARPETA', CONVERT(NVARCHAR(50), pk_origen), id_destino, codigo_referencia, '3bc3fac452b8f6d663ff2f2646579e4effd556799b3ea756415cd33d89dc04f2', @FechaMigracion, ORIGINAL_LOGIN() FROM #FgrMapaCarpeta
    UNION ALL SELECT N'DELITO', CONVERT(NVARCHAR(50), pk_origen), id_destino, codigo_referencia, '3bc3fac452b8f6d663ff2f2646579e4effd556799b3ea756415cd33d89dc04f2', @FechaMigracion, ORIGINAL_LOGIN() FROM #FgrMapaDelito
    UNION ALL SELECT N'VICTIMA', CONVERT(NVARCHAR(50), pk_origen), id_destino, codigo_referencia, '3bc3fac452b8f6d663ff2f2646579e4effd556799b3ea756415cd33d89dc04f2', @FechaMigracion, ORIGINAL_LOGIN() FROM #FgrMapaVictima
    ;
    IF (SELECT COUNT_BIG(*) FROM dbo.federal_migracion_fgr_20260909_mapa) <> 182535
        THROW 51000, 'No se completo el mapa de identidades.', 1;
    INSERT INTO dbo.federal_carga_bitacora_estado
    (id_federal_carga, estado_anterior, estado_nuevo, id_usuario, fecha, comentario, activo)
    SELECT id_destino, NULL, N'CONFIRMADO', NULL, @FechaMigracion,
           N'Migracion del respaldo FGR de 09/09/2026. Datos definitivos del legado, conservados sin deduplicar. Autor original: FGRX26011400. Fecha de carga/validacion reconstruida con fcha_insert; sin fecha ni usuario de aprobacion historica disponibles.', 1
    FROM #FgrMapaCarga;
    COMMIT TRANSACTION;
    PRINT N'MIGRACION CONFIRMADA: 8 envios, 58523 carpetas, 58638 delitos y 65366 victimas. Se conservaron los 115 pares.';
    SELECT tipo, COUNT_BIG(*) AS registros FROM dbo.federal_migracion_fgr_20260909_mapa GROUP BY tipo ORDER BY tipo;
    SELECT c.id_federal_carga, c.codigo_referencia, c.mes_corte, c.anio_corte, c.id_usuario_carga, c.estado,
           c.total_carpetas_investigacion, c.total_delitos, c.total_victimas
    FROM dbo.federal_carga c JOIN #FgrMapaCarga m ON m.id_destino = c.id_federal_carga ORDER BY c.anio_corte, c.mes_corte;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
