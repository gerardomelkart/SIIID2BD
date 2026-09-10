-- Repo SIIID2BD / vistas faby / vistasCompatibilidadFederal.sql
-- Ejecutar COMPLETO en SSMS, modo normal, sobre siiid2.
-- Misma proyección del Consolidado: 11 / 29 / 20 / 42 / 69 columnas.
-- Conserva código postal de fiscalía, registros repetidos y estados confirmados.
-- Catálogos de delitos federales; catálogos demográficos/geográficos compartidos.
-- entidad_reg conserva la regla original y puede ser NULL para un usuario nacional.
-- No crea logins ni cambia contraseñas. Reutiliza usuario y rol de Fabiola.
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF @@TRANCOUNT <> 0 OR (2 & @@OPTIONS) = 2
    THROW 54000, 'Ejecute en una ventana sin transacciones abiertas ni IMPLICIT_TRANSACTIONS.', 1;

IF DB_NAME() <> N'siiid2'
BEGIN
    THROW 54001, 'El script debe ejecutarse en la base siiid2.', 1;
END;

DECLARE @Objetivos TABLE (nombre SYSNAME PRIMARY KEY);

INSERT INTO @Objetivos (nombre)
VALUES
    (N'federal_tbl_carpetas'),
    (N'federal_tbl_delitos'),
    (N'federal_tbl_victimas'),
    (N'federal_vw_listado_nominal_delitos'),
    (N'federal_vw_listado_nominal_victimas');

IF EXISTS
(
    SELECT 1
    FROM sys.objects o
    INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
    INNER JOIN @Objetivos x ON x.nombre = o.name
    WHERE s.name = N'dbo'
      AND o.type <> N'V'
)
BEGIN
    SELECT s.name AS esquema, o.name AS objeto, o.type_desc AS tipo_objeto
    FROM sys.objects o
    INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
    INNER JOIN @Objetivos x ON x.nombre = o.name
    WHERE s.name = N'dbo'
      AND o.type <> N'V'
    ORDER BY o.name;

    THROW 54002, 'Uno o más nombres objetivo ya existen y no son vistas. No se modificó ese objeto.', 1;
END;

DECLARE @Fuentes TABLE (nombre SYSNAME PRIMARY KEY);

INSERT INTO @Fuentes (nombre)
VALUES
    (N'federal_carga'),
    (N'federal_carpeta_investigacion'),
    (N'federal_delito'),
    (N'federal_victima'),
    (N'usuario'),
    (N'federal_catalogo_bien_juridico'),
    (N'catalogo_codigo_postal'),
    (N'federal_catalogo_delito'),
    (N'federal_catalogo_delito_sabana'),
    (N'catalogo_entidad_federativa'),
    (N'catalogo_forma_accion'),
    (N'catalogo_genero'),
    (N'catalogo_grado_consumacion'),
    (N'catalogo_instrumento_comision'),
    (N'federal_catalogo_modalidad_delito'),
    (N'catalogo_municipio'),
    (N'catalogo_nacionalidad'),
    (N'catalogo_pertenece_poblacion_indigena'),
    (N'catalogo_presenta_discapacidad'),
    (N'catalogo_sexo'),
    (N'federal_catalogo_subtipo_delito'),
    (N'catalogo_tipo_victima'),
    (N'catalogo_tipo_victima_moral');

IF EXISTS
(
    SELECT 1
    FROM @Fuentes f
    WHERE OBJECT_ID(N'dbo.' + f.nombre, N'U') IS NULL
)
BEGIN
    SELECT f.nombre AS objeto_faltante
    FROM @Fuentes f
    WHERE OBJECT_ID(N'dbo.' + f.nombre, N'U') IS NULL
    ORDER BY f.nombre;

    THROW 54003, 'Faltan una o más tablas requeridas por las vistas de compatibilidad.', 1;
END;

IF COL_LENGTH(N'dbo.federal_delito', N'codigo_postal_fiscalia') IS NULL
BEGIN
    THROW 54004, 'Falta la columna dbo.federal_delito.codigo_postal_fiscalia.', 1;
END;
IF USER_ID(N'fabiola.martinez') IS NULL
    THROW 54006, 'No existe el usuario fabiola.martinez en siiid2. Ejecute en la base donde Fabiola ya tiene acceso.', 1;

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'rol_listado_nominal_lectura' AND type <> N'R')
    THROW 54007, 'El nombre rol_listado_nominal_lectura existe pero no corresponde a un rol.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.federal_tbl_carpetas
AS
SELECT
    ci.id_federal_carpeta_investigacion AS pk_ci,
    ci.identificador_carpeta_fiscalia AS id_ci,
    ci.nomenclatura_carpeta_fiscalia AS ntra_ci,
    CONVERT(NVARCHAR(10), ci.fecha_inicio, 23) AS fha_de_ini,
    CASE WHEN CONVERT(TIME(0), ci.fecha_inicio) = ''00:00:00'' THEN N'''' ELSE CONVERT(NVARCHAR(8), ci.fecha_inicio, 108) END AS hra_de_ini,
    ci.resumen_hechos AS rmen_de_hchos,
    u.usuario AS usuario_reg,
    ci.fecha_registro AS fcha_insert,
    c.codigo_referencia,
    CONVERT(NVARCHAR(2), c.mes_corte) AS mes_corte,
    CONVERT(NVARCHAR(4), c.anio_corte) AS anio_corte
FROM dbo.federal_carpeta_investigacion ci
INNER JOIN dbo.federal_carga c ON c.id_federal_carga = ci.id_federal_carga
INNER JOIN dbo.usuario u ON u.id_usuario = c.id_usuario_carga
WHERE ci.activo = 1
  AND c.activo = 1
  AND ((c.tipo_carga = N''CARGA_INICIAL'' AND c.estado = N''CONFIRMADO'') OR (c.tipo_carga = N''ACTUALIZACION'' AND c.estado = N''CONFIRMADO_ACTUALIZACION''));';

    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.federal_tbl_delitos
AS
SELECT
    d.id_federal_delito AS pk_del,
    d.id_federal_carpeta_investigacion AS pk_ci,
    ci.identificador_carpeta_fiscalia AS id_ci,
    d.identificador_delito_fiscalia AS id_delito,
    d.delito_fiscalia AS dto,
    d.modalidad_delito_fiscalia AS moda_dto,
    CONVERT(DECIMAL(3,0), fa.clave) AS forma_acc,
    CONVERT(NVARCHAR(10), d.fecha_hechos, 23) AS fha_de_hchos,
    CONVERT(NVARCHAR(8), d.fecha_hechos, 108) AS hra_de_hchos,
    CONVERT(NVARCHAR(45), ic.clave) AS emto_com_dto,
    CONVERT(DECIMAL(3,0), gc.clave) AS grdo_cons,
    md.clave4 AS clasf_de_dto,
    ef.nombre AS nom_ent_hchos,
    TRY_CONVERT(INT, ef.clave) AS id_ent_hchos,
    mun.nombre AS nom_mun_hchos,
    TRY_CONVERT(INT, mun.clave) AS id_mun_hchos,
    d.localidad_fiscalia_nombre AS nom_loc_hchos,
    d.id_localidad_fiscalia AS id_loc_hchos,
    d.colonia_fiscalia_nombre AS nom_col_hchos,
    d.id_colonia_fiscalia AS id_col_hchos,
    COALESCE(NULLIF(LTRIM(RTRIM(d.codigo_postal_fiscalia)), N''''), cp.codigo_postal) AS cp,
    CONVERT(NVARCHAR(50), d.coordenada_x) AS coord_x,
    CONVERT(NVARCHAR(50), d.coordenada_y) AS coord_y,
    d.domicilio_hechos AS dom_hchos,
    u.usuario AS usuario_reg,
    d.fecha_registro AS fcha_insert,
    c.codigo_referencia,
    CONVERT(NVARCHAR(2), c.mes_corte) AS mes_corte,
    CONVERT(NVARCHAR(4), c.anio_corte) AS anio_corte
FROM dbo.federal_delito d
INNER JOIN dbo.federal_carpeta_investigacion ci ON ci.id_federal_carpeta_investigacion = d.id_federal_carpeta_investigacion AND ci.activo = 1
INNER JOIN dbo.federal_carga c ON c.id_federal_carga = d.id_federal_carga
INNER JOIN dbo.usuario u ON u.id_usuario = c.id_usuario_carga
INNER JOIN dbo.catalogo_forma_accion fa ON fa.id_forma_accion = d.id_forma_accion
INNER JOIN dbo.catalogo_instrumento_comision ic ON ic.id_instrumento_comision = d.id_instrumento_comision
INNER JOIN dbo.catalogo_grado_consumacion gc ON gc.id_grado_consumacion = d.id_grado_consumacion
INNER JOIN dbo.federal_catalogo_modalidad_delito md ON md.id_modalidad_delito = d.id_modalidad_delito
INNER JOIN dbo.catalogo_entidad_federativa ef ON ef.id_entidad_federativa = d.id_entidad_federativa
INNER JOIN dbo.catalogo_municipio mun ON mun.id_municipio = d.id_municipio
LEFT JOIN dbo.catalogo_codigo_postal cp ON cp.id_codigo_postal = d.id_codigo_postal
WHERE d.activo = 1
  AND c.activo = 1
  AND ((c.tipo_carga = N''CARGA_INICIAL'' AND c.estado = N''CONFIRMADO'') OR (c.tipo_carga = N''ACTUALIZACION'' AND c.estado = N''CONFIRMADO_ACTUALIZACION''));';

    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.federal_tbl_victimas
AS
SELECT
    v.id_federal_victima AS pk_vict,
    ci.id_federal_carpeta_investigacion AS pk_ci,
    d.id_federal_delito AS pk_del,
    ci.identificador_carpeta_fiscalia AS id_ci,
    d.identificador_delito_fiscalia AS id_delito,
    v.identificador_victima_fiscalia AS id_vicf,
    CONVERT(DECIMAL(3,0), tv.clave) AS id_tv,
    CONVERT(DECIMAL(3,0), tvm.clave) AS id_tpm,
    CONVERT(DECIMAL(3,0), sx.clave) AS sexo,
    CONVERT(DECIMAL(3,0), gen.clave) AS genero,
    CONVERT(DECIMAL(3,0), pob.clave) AS pob,
    CONVERT(DECIMAL(3,0), disc.clave) AS disc,
    CONVERT(NVARCHAR(10), v.fecha_nacimiento, 23) AS fha_nac,
    COALESCE(CONVERT(NVARCHAR(25), v.edad), N''999'') AS edad,
    TRY_CONVERT(INT, nac.clave) AS nacional,
    u.usuario AS usuario_reg,
    v.fecha_registro AS fcha_insert,
    c.codigo_referencia,
    CONVERT(NVARCHAR(2), c.mes_corte) AS mes_corte,
    CONVERT(NVARCHAR(4), c.anio_corte) AS anio_corte
FROM dbo.federal_victima v
INNER JOIN dbo.federal_delito d ON d.id_federal_delito = v.id_federal_delito AND d.activo = 1
INNER JOIN dbo.federal_carpeta_investigacion ci ON ci.id_federal_carpeta_investigacion = d.id_federal_carpeta_investigacion AND ci.activo = 1
INNER JOIN dbo.federal_carga c ON c.id_federal_carga = v.id_federal_carga
INNER JOIN dbo.usuario u ON u.id_usuario = c.id_usuario_carga
INNER JOIN dbo.catalogo_tipo_victima tv ON tv.id_tipo_victima = v.id_tipo_victima
LEFT JOIN dbo.catalogo_tipo_victima_moral tvm ON tvm.id_tipo_victima_moral = v.id_tipo_victima_moral
LEFT JOIN dbo.catalogo_sexo sx ON sx.id_sexo = v.id_sexo
LEFT JOIN dbo.catalogo_genero gen ON gen.id_genero = v.id_genero
LEFT JOIN dbo.catalogo_pertenece_poblacion_indigena pob ON pob.id_pertenece_poblacion_indigena = v.id_pertenece_poblacion_indigena
LEFT JOIN dbo.catalogo_presenta_discapacidad disc ON disc.id_presenta_discapacidad = v.id_presenta_discapacidad
LEFT JOIN dbo.catalogo_nacionalidad nac ON nac.id_nacionalidad = v.id_nacionalidad
WHERE v.activo = 1
  AND c.activo = 1
  AND ((c.tipo_carga = N''CARGA_INICIAL'' AND c.estado = N''CONFIRMADO'') OR (c.tipo_carga = N''ACTUALIZACION'' AND c.estado = N''CONFIRMADO_ACTUALIZACION''));';

    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.federal_vw_listado_nominal_delitos
AS
SELECT
    ci.id_federal_carpeta_investigacion AS pk_ci,
    ci.identificador_carpeta_fiscalia AS id_ci,
    ci.nomenclatura_carpeta_fiscalia AS ntra_ci,
    CONVERT(NVARCHAR(10), ci.fecha_inicio, 23) AS fha_de_ini,
    CASE WHEN CONVERT(TIME(0), ci.fecha_inicio) = ''00:00:00'' THEN N'''' ELSE CONVERT(NVARCHAR(8), ci.fecha_inicio, 108) END AS hra_de_ini,
    ci.resumen_hechos AS rmen_de_hchos,
    ci.fecha_registro AS fcha_insert,
    c_ci.codigo_referencia,
    CONVERT(NVARCHAR(2), c_ci.mes_corte) AS mes_corte,
    CONVERT(NVARCHAR(4), c_ci.anio_corte) AS anio_corte,
    d.id_federal_delito AS pk_del,
    d.identificador_delito_fiscalia AS id_delito,
    d.delito_fiscalia AS dto,
    d.modalidad_delito_fiscalia AS moda_dto,
    fa.descripcion AS forma_acc,
    CONVERT(NVARCHAR(10), d.fecha_hechos, 23) AS fha_de_hchos,
    CONVERT(NVARCHAR(8), d.fecha_hechos, 108) AS hra_de_hchos,
    ic.descripcion AS emto_com_dto,
    gc.descripcion AS grdo_cons,
    md.clave4 AS clasf_de_dto,
    bj.bien_juridico,
    cd.delito,
    sd.subtipo_delito,
    md.modalidad_delito,
    ef.nombre AS nom_ent_hchos,
    TRY_CONVERT(INT, ef.clave) AS id_ent_hchos,
    mun.nombre AS nom_mun_hchos,
    TRY_CONVERT(INT, mun.clave) AS id_mun_hchos,
    d.localidad_fiscalia_nombre AS nom_loc_hchos,
    d.id_localidad_fiscalia AS id_loc_hchos,
    COALESCE(NULLIF(LTRIM(RTRIM(d.codigo_postal_fiscalia)), N''''), cp.codigo_postal) AS cp,
    CONVERT(NVARCHAR(50), d.coordenada_x) AS coord_x,
    CONVERT(NVARCHAR(50), d.coordenada_y) AS coord_y,
    d.domicilio_hechos AS dom_hchos,
    ef.nombre AS nom_ent_catalogo,
    mun.nombre AS nom_mun_catalogo,
    CASE WHEN sab.id_delito_sabana IS NULL THEN NULL ELSE bj.bien_juridico END AS bien_juridico_sabana,
    sab.delito_sabana,
    sab.subtipo_delito_sabana,
    sab.modalidad_delito_sabana,
    ef_reg.nombre AS entidad_reg,
    u_d.usuario AS usuario_reg
FROM dbo.federal_carpeta_investigacion ci
INNER JOIN dbo.federal_delito d ON d.id_federal_carpeta_investigacion = ci.id_federal_carpeta_investigacion
INNER JOIN dbo.federal_carga c_ci ON c_ci.id_federal_carga = ci.id_federal_carga
INNER JOIN dbo.usuario u_ci ON u_ci.id_usuario = c_ci.id_usuario_carga
INNER JOIN dbo.federal_carga c_d ON c_d.id_federal_carga = d.id_federal_carga
INNER JOIN dbo.usuario u_d ON u_d.id_usuario = c_d.id_usuario_carga
INNER JOIN dbo.catalogo_forma_accion fa ON fa.id_forma_accion = d.id_forma_accion
INNER JOIN dbo.catalogo_instrumento_comision ic ON ic.id_instrumento_comision = d.id_instrumento_comision
INNER JOIN dbo.catalogo_grado_consumacion gc ON gc.id_grado_consumacion = d.id_grado_consumacion
INNER JOIN dbo.federal_catalogo_modalidad_delito md ON md.id_modalidad_delito = d.id_modalidad_delito
INNER JOIN dbo.federal_catalogo_subtipo_delito sd ON sd.id_subtipo_delito = md.id_subtipo_delito
INNER JOIN dbo.federal_catalogo_delito cd ON cd.id_delito = sd.id_delito
INNER JOIN dbo.federal_catalogo_bien_juridico bj ON bj.id_bien_juridico = cd.id_bien_juridico
INNER JOIN dbo.catalogo_entidad_federativa ef ON ef.id_entidad_federativa = d.id_entidad_federativa
INNER JOIN dbo.catalogo_municipio mun ON mun.id_municipio = d.id_municipio
LEFT JOIN dbo.catalogo_codigo_postal cp ON cp.id_codigo_postal = d.id_codigo_postal
LEFT JOIN dbo.federal_catalogo_delito_sabana sab ON sab.id_modalidad_delito = d.id_modalidad_delito AND sab.id_grado_consumacion = d.id_grado_consumacion AND sab.id_instrumento_comision = d.id_instrumento_comision AND sab.id_forma_accion = d.id_forma_accion AND sab.activo = 1
LEFT JOIN dbo.catalogo_entidad_federativa ef_reg ON ef_reg.id_entidad_federativa = COALESCE(c_d.id_entidad_federativa, u_d.id_entidad_federativa)
WHERE ci.activo = 1
  AND d.activo = 1
  AND c_ci.activo = 1
  AND c_d.activo = 1
  AND ((c_ci.tipo_carga = N''CARGA_INICIAL'' AND c_ci.estado = N''CONFIRMADO'') OR (c_ci.tipo_carga = N''ACTUALIZACION'' AND c_ci.estado = N''CONFIRMADO_ACTUALIZACION''))
  AND ((c_d.tipo_carga = N''CARGA_INICIAL'' AND c_d.estado = N''CONFIRMADO'') OR (c_d.tipo_carga = N''ACTUALIZACION'' AND c_d.estado = N''CONFIRMADO_ACTUALIZACION''));';

    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.federal_vw_listado_nominal_victimas
AS
SELECT
    ef_reg.nombre AS entidad_reg,
    u_v.usuario AS usuario_reg,
    ci.fecha_registro AS fcha_insert,
    CONVERT(NVARCHAR(4), c_ci.anio_corte) AS anio_corte,
    CONVERT(NVARCHAR(2), c_ci.mes_corte) AS mes_corte,
    c_ci.codigo_referencia,
    ci.identificador_carpeta_fiscalia AS id_ci,
    ci.id_federal_carpeta_investigacion AS pk_ci,
    d.identificador_delito_fiscalia AS id_delito,
    d.id_federal_delito AS pk_del,
    v.identificador_victima_fiscalia AS id_vicf,
    v.id_federal_victima AS pk_vict,
    ci.nomenclatura_carpeta_fiscalia AS ntra_ci,
    CONVERT(NVARCHAR(10), ci.fecha_inicio, 23) AS fha_de_ini,
    CASE WHEN CONVERT(TIME(0), ci.fecha_inicio) = ''00:00:00'' THEN N'''' ELSE CONVERT(NVARCHAR(8), ci.fecha_inicio, 108) END AS hra_de_ini,
    DATEFROMPARTS(YEAR(ci.fecha_inicio), MONTH(ci.fecha_inicio), 1) AS fecha,
    ci.resumen_hechos AS rmen_de_hchos,
    d.delito_fiscalia AS dto,
    d.modalidad_delito_fiscalia AS moda_dto,
    CONVERT(NVARCHAR(10), d.fecha_hechos, 23) AS fha_de_hchos,
    CONVERT(NVARCHAR(8), d.fecha_hechos, 108) AS hra_de_hchos,
    CONVERT(DECIMAL(3,0), gc.clave) AS grdo_cons,
    gc.descripcion AS d_grdo_cons,
    CONVERT(DECIMAL(3,0), fa.clave) AS forma_acc,
    fa.descripcion AS d_forma_acc,
    CONVERT(NVARCHAR(45), ic.clave) AS emto_com_dto,
    ic.descripcion AS d_emto_com_dto,
    md.clave4 AS clasf_de_dto,
    cd.delito,
    md.modalidad_delito,
    sd.subtipo_delito,
    bj.bien_juridico,
    sab.delito_sabana,
    sab.subtipo_delito_sabana,
    sab.modalidad_delito_sabana,
    CASE WHEN sab.id_delito_sabana IS NULL THEN NULL ELSE bj.bien_juridico END AS bien_juridico_sabana,
    TRY_CONVERT(INT, ef.clave) AS id_ent_hchos,
    ef.nombre AS nom_ent_hchos,
    ef.nombre AS nom_ent_catalogo,
    ef.siglas AS nom_corto_ent,
    TRY_CONVERT(INT, mun.clave) AS id_mun_hchos,
    mun.nombre AS nom_mun_hchos,
    mun.nombre AS nom_mun_catalogo,
    mun.nombre + N'' ('' + UPPER(ef.siglas) + N'')'' AS municipio_hechos_ent,
    d.id_localidad_fiscalia AS id_loc_hchos,
    d.localidad_fiscalia_nombre AS nom_loc_hchos,
    d.id_colonia_fiscalia AS id_col_hchos,
    d.colonia_fiscalia_nombre AS nom_col_hchos,
    COALESCE(NULLIF(LTRIM(RTRIM(d.codigo_postal_fiscalia)), N''''), cp.codigo_postal) AS cp,
    d.domicilio_hechos AS dom_hchos,
    CONVERT(NVARCHAR(50), d.coordenada_x) AS coord_x,
    CONVERT(NVARCHAR(50), d.coordenada_y) AS coord_y,
    CONVERT(DECIMAL(3,0), tv.clave) AS id_tv,
    tv.descripcion AS d_tv,
    CONVERT(DECIMAL(3,0), tvm.clave) AS id_tpm,
    tvm.descripcion AS d_tpm,
    CONVERT(DECIMAL(3,0), sx.clave) AS sexo,
    sx.descripcion AS d_sexo,
    CONVERT(DECIMAL(3,0), gen.clave) AS genero,
    gen.descripcion AS d_genero,
    CONVERT(DECIMAL(3,0), pob.clave) AS pob,
    pob.descripcion AS d_pob,
    CONVERT(DECIMAL(3,0), disc.clave) AS disc,
    disc.descripcion AS d_disc,
    CONVERT(NVARCHAR(10), v.fecha_nacimiento, 23) AS fha_nac,
    COALESCE(CONVERT(NVARCHAR(25), v.edad), N''999'') AS edad,
    CASE WHEN v.edad IS NULL THEN N''No especificado'' WHEN v.edad BETWEEN 0 AND 120 THEN CONVERT(NVARCHAR(20), v.edad) ELSE NULL END AS d_edad,
    TRY_CONVERT(INT, nac.clave) AS nacional,
    nac.descripcion AS d_nacional
FROM dbo.federal_carpeta_investigacion ci
INNER JOIN dbo.federal_delito d ON d.id_federal_carpeta_investigacion = ci.id_federal_carpeta_investigacion
INNER JOIN dbo.federal_victima v ON v.id_federal_delito = d.id_federal_delito
INNER JOIN dbo.federal_carga c_ci ON c_ci.id_federal_carga = ci.id_federal_carga
INNER JOIN dbo.usuario u_ci ON u_ci.id_usuario = c_ci.id_usuario_carga
INNER JOIN dbo.federal_carga c_d ON c_d.id_federal_carga = d.id_federal_carga
INNER JOIN dbo.usuario u_d ON u_d.id_usuario = c_d.id_usuario_carga
INNER JOIN dbo.federal_carga c_v ON c_v.id_federal_carga = v.id_federal_carga
INNER JOIN dbo.usuario u_v ON u_v.id_usuario = c_v.id_usuario_carga
INNER JOIN dbo.catalogo_forma_accion fa ON fa.id_forma_accion = d.id_forma_accion
INNER JOIN dbo.catalogo_instrumento_comision ic ON ic.id_instrumento_comision = d.id_instrumento_comision
INNER JOIN dbo.catalogo_grado_consumacion gc ON gc.id_grado_consumacion = d.id_grado_consumacion
INNER JOIN dbo.federal_catalogo_modalidad_delito md ON md.id_modalidad_delito = d.id_modalidad_delito
INNER JOIN dbo.federal_catalogo_subtipo_delito sd ON sd.id_subtipo_delito = md.id_subtipo_delito
INNER JOIN dbo.federal_catalogo_delito cd ON cd.id_delito = sd.id_delito
INNER JOIN dbo.federal_catalogo_bien_juridico bj ON bj.id_bien_juridico = cd.id_bien_juridico
INNER JOIN dbo.catalogo_entidad_federativa ef ON ef.id_entidad_federativa = d.id_entidad_federativa
INNER JOIN dbo.catalogo_municipio mun ON mun.id_municipio = d.id_municipio
LEFT JOIN dbo.catalogo_codigo_postal cp ON cp.id_codigo_postal = d.id_codigo_postal
LEFT JOIN dbo.federal_catalogo_delito_sabana sab ON sab.id_modalidad_delito = d.id_modalidad_delito AND sab.id_grado_consumacion = d.id_grado_consumacion AND sab.id_instrumento_comision = d.id_instrumento_comision AND sab.id_forma_accion = d.id_forma_accion AND sab.activo = 1
INNER JOIN dbo.catalogo_tipo_victima tv ON tv.id_tipo_victima = v.id_tipo_victima
LEFT JOIN dbo.catalogo_tipo_victima_moral tvm ON tvm.id_tipo_victima_moral = v.id_tipo_victima_moral
LEFT JOIN dbo.catalogo_sexo sx ON sx.id_sexo = v.id_sexo
LEFT JOIN dbo.catalogo_genero gen ON gen.id_genero = v.id_genero
LEFT JOIN dbo.catalogo_pertenece_poblacion_indigena pob ON pob.id_pertenece_poblacion_indigena = v.id_pertenece_poblacion_indigena
LEFT JOIN dbo.catalogo_presenta_discapacidad disc ON disc.id_presenta_discapacidad = v.id_presenta_discapacidad
LEFT JOIN dbo.catalogo_nacionalidad nac ON nac.id_nacionalidad = v.id_nacionalidad
LEFT JOIN dbo.catalogo_entidad_federativa ef_reg ON ef_reg.id_entidad_federativa = COALESCE(c_v.id_entidad_federativa, u_v.id_entidad_federativa)
WHERE ci.activo = 1
  AND d.activo = 1
  AND v.activo = 1
  AND c_ci.activo = 1
  AND c_d.activo = 1
  AND c_v.activo = 1
  AND ((c_ci.tipo_carga = N''CARGA_INICIAL'' AND c_ci.estado = N''CONFIRMADO'') OR (c_ci.tipo_carga = N''ACTUALIZACION'' AND c_ci.estado = N''CONFIRMADO_ACTUALIZACION''))
  AND ((c_d.tipo_carga = N''CARGA_INICIAL'' AND c_d.estado = N''CONFIRMADO'') OR (c_d.tipo_carga = N''ACTUALIZACION'' AND c_d.estado = N''CONFIRMADO_ACTUALIZACION''))
  AND ((c_v.tipo_carga = N''CARGA_INICIAL'' AND c_v.estado = N''CONFIRMADO'') OR (c_v.tipo_carga = N''ACTUALIZACION'' AND c_v.estado = N''CONFIRMADO_ACTUALIZACION''));';

    IF DATABASE_PRINCIPAL_ID(N'rol_listado_nominal_lectura') IS NULL
        CREATE ROLE [rol_listado_nominal_lectura] AUTHORIZATION [dbo];

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.database_role_members drm
        INNER JOIN sys.database_principals rol ON rol.principal_id = drm.role_principal_id
        INNER JOIN sys.database_principals miembro ON miembro.principal_id = drm.member_principal_id
        WHERE rol.name = N'rol_listado_nominal_lectura'
          AND miembro.name = N'fabiola.martinez'
    )
        ALTER ROLE [rol_listado_nominal_lectura] ADD MEMBER [fabiola.martinez];

    GRANT SELECT ON OBJECT::dbo.federal_tbl_carpetas TO [rol_listado_nominal_lectura];
    GRANT SELECT ON OBJECT::dbo.federal_tbl_delitos TO [rol_listado_nominal_lectura];
    GRANT SELECT ON OBJECT::dbo.federal_tbl_victimas TO [rol_listado_nominal_lectura];
    GRANT SELECT ON OBJECT::dbo.federal_vw_listado_nominal_delitos TO [rol_listado_nominal_lectura];
    GRANT SELECT ON OBJECT::dbo.federal_vw_listado_nominal_victimas TO [rol_listado_nominal_lectura];

    DECLARE @Esperado TABLE
    (
        objeto SYSNAME PRIMARY KEY,
        columnas_esperadas INT NOT NULL
    );

    INSERT INTO @Esperado (objeto, columnas_esperadas)
    VALUES
        (N'federal_tbl_carpetas', 11),
        (N'federal_tbl_delitos', 29),
        (N'federal_tbl_victimas', 20),
        (N'federal_vw_listado_nominal_delitos', 42),
        (N'federal_vw_listado_nominal_victimas', 69);

    IF EXISTS
    (
        SELECT 1
        FROM @Esperado e
        LEFT JOIN sys.views v ON v.name = e.objeto AND v.schema_id = SCHEMA_ID(N'dbo')
        OUTER APPLY (SELECT COUNT(*) AS total FROM sys.columns c WHERE c.object_id = v.object_id) x
        WHERE v.object_id IS NULL
           OR ISNULL(x.total, 0) <> e.columnas_esperadas
    )
    BEGIN
        THROW 54005, 'La cantidad de columnas de una o más vistas no coincide con la estructura esperada.', 1;
    END;


    COMMIT TRANSACTION;
    SELECT
        e.objeto,
        e.columnas_esperadas,
        COUNT(c.column_id) AS columnas_creadas,
        CASE WHEN COUNT(c.column_id) = e.columnas_esperadas THEN N'CORRECTO' ELSE N'REVISAR' END AS resultado
    FROM @Esperado e
    LEFT JOIN sys.views v ON v.name = e.objeto AND v.schema_id = SCHEMA_ID(N'dbo')
    LEFT JOIN sys.columns c ON c.object_id = v.object_id
    GROUP BY e.objeto, e.columnas_esperadas
    ORDER BY e.objeto;


    SELECT miembro.name AS usuario, rol.name AS rol
    FROM sys.database_role_members drm
    INNER JOIN sys.database_principals rol ON rol.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals miembro ON miembro.principal_id = drm.member_principal_id
    WHERE rol.name = N'rol_listado_nominal_lectura'
      AND miembro.name = N'fabiola.martinez';

    SELECT o.name AS vista, p.permission_name AS permiso, p.state_desc AS estado
    FROM sys.database_permissions p
    INNER JOIN sys.objects o ON o.object_id = p.major_id
    INNER JOIN @Objetivos x ON x.nombre = o.name
    WHERE p.class = 1 AND p.minor_id = 0
      AND o.schema_id = SCHEMA_ID(N'dbo')
      AND p.grantee_principal_id = DATABASE_PRINCIPAL_ID(N'rol_listado_nominal_lectura')
      AND p.permission_name = N'SELECT'
    ORDER BY o.name;

    PRINT N'Las cinco vistas Federales y sus permisos de lectura quedaron instalados.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
