USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    SIIID2 - Módulo FEDERAL
    Paso 01: estructura aislada.

    Este script:
    - registra FEDERAL desactivado;
    - no asigna usuarios;
    - no modifica datos ni estructuras de MENSUAL o SEMANAL;
    - crea catálogos y tablas operativas exclusivas del módulo federal.

    Ejecutar primero únicamente en DEV.
*/

IF DB_NAME() <> N'siiid2'
BEGIN
    THROW 51000, 'El script debe ejecutarse en la base siiid2.', 1;
END;

DECLARE @Requeridas TABLE (nombre SYSNAME PRIMARY KEY);

INSERT INTO @Requeridas (nombre)
VALUES
    (N'catalogo_modulo'),
    (N'usuario'),
    (N'catalogo_admite_tentativa'),
    (N'catalogo_forma_accion'),
    (N'catalogo_grado_consumacion'),
    (N'catalogo_instrumento_comision'),
    (N'catalogo_entidad_federativa'),
    (N'catalogo_municipio'),
    (N'catalogo_codigo_postal'),
    (N'catalogo_tipo_victima'),
    (N'catalogo_tipo_victima_moral'),
    (N'catalogo_sexo'),
    (N'catalogo_genero'),
    (N'catalogo_nacionalidad'),
    (N'catalogo_pertenece_poblacion_indigena'),
    (N'catalogo_presenta_discapacidad');

IF EXISTS
(
    SELECT 1
    FROM @Requeridas r
    WHERE OBJECT_ID(N'dbo.' + r.nombre, N'U') IS NULL
)
BEGIN
    SELECT r.nombre AS tabla_faltante
    FROM @Requeridas r
    WHERE OBJECT_ID(N'dbo.' + r.nombre, N'U') IS NULL
    ORDER BY r.nombre;

    THROW 51001, 'Faltan tablas compartidas requeridas por el módulo FEDERAL.', 1;
END;

DECLARE @Federales TABLE (nombre SYSNAME PRIMARY KEY);

INSERT INTO @Federales (nombre)
VALUES
    (N'federal_catalogo_bien_juridico'),
    (N'federal_catalogo_delito'),
    (N'federal_catalogo_subtipo_delito'),
    (N'federal_catalogo_modalidad_delito'),
    (N'federal_catalogo_delito_sabana'),
    (N'federal_carga'),
    (N'federal_carga_advertencia'),
    (N'federal_carga_bitacora_estado'),
    (N'federal_carga_tmp_carpeta'),
    (N'federal_carga_tmp_delito'),
    (N'federal_carga_tmp_victima'),
    (N'federal_carpeta_investigacion'),
    (N'federal_carpeta_investigacion_historico'),
    (N'federal_delito'),
    (N'federal_delito_historico'),
    (N'federal_victima'),
    (N'federal_victima_historico');

IF EXISTS
(
    SELECT 1
    FROM @Federales f
    WHERE OBJECT_ID(N'dbo.' + f.nombre, N'U') IS NOT NULL
)
BEGIN
    SELECT f.nombre AS objeto_federal_existente
    FROM @Federales f
    WHERE OBJECT_ID(N'dbo.' + f.nombre, N'U') IS NOT NULL
    ORDER BY f.nombre;

    THROW 51002, 'Ya existe al menos una tabla FEDERAL. No se aplicó ninguna modificación.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.catalogo_modulo WHERE clave = N'FEDERAL')
    BEGIN
        INSERT INTO dbo.catalogo_modulo (clave, nombre, activo)
        VALUES (N'FEDERAL', N'SIIID2 Federal', 0);
    END
    ELSE IF EXISTS (SELECT 1 FROM dbo.catalogo_modulo WHERE clave = N'FEDERAL' AND activo = 1)
    BEGIN
        THROW 51003, 'FEDERAL ya existe y está activo. Se cancela para no exponer un módulo todavía no implementado.', 1;
    END;

    CREATE TABLE dbo.federal_catalogo_bien_juridico
    (
        id_bien_juridico INT NOT NULL,
        clave1 NVARCHAR(10) NOT NULL,
        bien_juridico NVARCHAR(200) NOT NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_bien_activo DEFAULT (1),
        CONSTRAINT PK_federal_catalogo_bien_juridico PRIMARY KEY (id_bien_juridico),
        CONSTRAINT UQ_federal_catalogo_bien_clave UNIQUE (clave1)
    );

    CREATE TABLE dbo.federal_catalogo_delito
    (
        id_delito INT NOT NULL,
        id_bien_juridico INT NOT NULL,
        clave2 NVARCHAR(10) NOT NULL,
        delito NVARCHAR(200) NOT NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_catalogo_delito_activo DEFAULT (1),
        CONSTRAINT PK_federal_catalogo_delito PRIMARY KEY (id_delito),
        CONSTRAINT UQ_federal_catalogo_delito_clave UNIQUE (clave2),
        CONSTRAINT FK_federal_delito_bien FOREIGN KEY (id_bien_juridico) REFERENCES dbo.federal_catalogo_bien_juridico(id_bien_juridico)
    );

    CREATE TABLE dbo.federal_catalogo_subtipo_delito
    (
        id_subtipo_delito INT NOT NULL,
        id_delito INT NOT NULL,
        clave3 NVARCHAR(20) NOT NULL,
        subtipo_delito NVARCHAR(200) NOT NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_subtipo_activo DEFAULT (1),
        CONSTRAINT PK_federal_catalogo_subtipo_delito PRIMARY KEY (id_subtipo_delito),
        CONSTRAINT UQ_federal_catalogo_subtipo_clave UNIQUE (clave3),
        CONSTRAINT FK_federal_subtipo_delito FOREIGN KEY (id_delito) REFERENCES dbo.federal_catalogo_delito(id_delito)
    );

    CREATE TABLE dbo.federal_catalogo_modalidad_delito
    (
        id_modalidad_delito INT NOT NULL,
        id_subtipo_delito INT NOT NULL,
        clave4 NVARCHAR(20) NOT NULL,
        modalidad_delito NVARCHAR(250) NOT NULL,
        id_admite_tentativa TINYINT NOT NULL,
        es_fuero_federal BIT NOT NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_modalidad_activo DEFAULT (1),
        CONSTRAINT PK_federal_catalogo_modalidad_delito PRIMARY KEY (id_modalidad_delito),
        CONSTRAINT UQ_federal_catalogo_modalidad_clave UNIQUE (clave4),
        CONSTRAINT FK_federal_modalidad_subtipo FOREIGN KEY (id_subtipo_delito) REFERENCES dbo.federal_catalogo_subtipo_delito(id_subtipo_delito),
        CONSTRAINT FK_federal_modalidad_tentativa FOREIGN KEY (id_admite_tentativa) REFERENCES dbo.catalogo_admite_tentativa(id_admite_tentativa)
    );

    CREATE TABLE dbo.federal_catalogo_delito_sabana
    (
        id_delito_sabana INT NOT NULL,
        id_modalidad_delito INT NOT NULL,
        id_grado_consumacion TINYINT NOT NULL,
        id_instrumento_comision TINYINT NOT NULL,
        id_forma_accion TINYINT NOT NULL,
        delito_sabana NVARCHAR(200) NOT NULL,
        subtipo_delito_sabana NVARCHAR(250) NOT NULL,
        modalidad_delito_sabana NVARCHAR(250) NOT NULL,
        clave2_sabana NVARCHAR(20) NOT NULL,
        clave3_sabana NVARCHAR(20) NOT NULL,
        es_fuero_federal BIT NOT NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_sabana_activo DEFAULT (1),
        CONSTRAINT PK_federal_catalogo_delito_sabana PRIMARY KEY (id_delito_sabana),
        CONSTRAINT UQ_federal_sabana_combinacion UNIQUE
        (
            id_modalidad_delito,
            id_grado_consumacion,
            id_instrumento_comision,
            id_forma_accion,
            clave2_sabana,
            clave3_sabana
        ),
        CONSTRAINT FK_federal_sabana_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.federal_catalogo_modalidad_delito(id_modalidad_delito),
        CONSTRAINT FK_federal_sabana_grado FOREIGN KEY (id_grado_consumacion) REFERENCES dbo.catalogo_grado_consumacion(id_grado_consumacion),
        CONSTRAINT FK_federal_sabana_instrumento FOREIGN KEY (id_instrumento_comision) REFERENCES dbo.catalogo_instrumento_comision(id_instrumento_comision),
        CONSTRAINT FK_federal_sabana_forma FOREIGN KEY (id_forma_accion) REFERENCES dbo.catalogo_forma_accion(id_forma_accion)
    );

    CREATE TABLE dbo.federal_carga
    (
        id_federal_carga BIGINT IDENTITY(1,1) NOT NULL,
        id_usuario_carga INT NOT NULL,
        id_entidad_federativa TINYINT NULL,
        codigo_referencia NVARCHAR(50) NOT NULL,
        tipo_carga NVARCHAR(20) NOT NULL CONSTRAINT DF_federal_carga_tipo DEFAULT (N'CARGA_INICIAL'),
        mes_corte TINYINT NOT NULL,
        anio_corte SMALLINT NOT NULL,
        fecha_carga DATETIME2(0) NOT NULL CONSTRAINT DF_federal_carga_fecha DEFAULT (SYSDATETIME()),
        total_carpetas_investigacion INT NOT NULL CONSTRAINT DF_federal_carga_carpetas DEFAULT (0),
        total_delitos INT NOT NULL CONSTRAINT DF_federal_carga_delitos DEFAULT (0),
        total_victimas INT NOT NULL CONSTRAINT DF_federal_carga_victimas DEFAULT (0),
        estado NVARCHAR(50) NOT NULL CONSTRAINT DF_federal_carga_estado DEFAULT (N'VALIDADO_PENDIENTE'),
        fecha_validacion DATETIME2(0) NOT NULL CONSTRAINT DF_federal_carga_validacion DEFAULT (SYSDATETIME()),
        fecha_confirmacion DATETIME2(0) NULL,
        fecha_expiracion DATETIME2(0) NULL,
        id_usuario_confirmacion INT NULL,
        mensaje_error NVARCHAR(MAX) NULL,
        rechazo_visto BIT NOT NULL CONSTRAINT DF_federal_carga_rechazo_visto DEFAULT (1),
        fecha_rechazo_visto DATETIME2(0) NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_carga_activo DEFAULT (1),
        CONSTRAINT PK_federal_carga PRIMARY KEY (id_federal_carga),
        CONSTRAINT UQ_federal_carga_codigo UNIQUE (codigo_referencia),
        CONSTRAINT FK_federal_carga_usuario FOREIGN KEY (id_usuario_carga) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_carga_confirmacion FOREIGN KEY (id_usuario_confirmacion) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_carga_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
        CONSTRAINT CK_federal_carga_alcance_nacional CHECK (id_entidad_federativa IS NULL),
        CONSTRAINT CK_federal_carga_tipo CHECK (tipo_carga IN (N'CARGA_INICIAL', N'ACTUALIZACION')),
        CONSTRAINT CK_federal_carga_mes CHECK (mes_corte BETWEEN 1 AND 12),
        CONSTRAINT CK_federal_carga_anio CHECK (anio_corte BETWEEN 2000 AND 9999),
        CONSTRAINT CK_federal_carga_totales CHECK (total_carpetas_investigacion >= 0 AND total_delitos >= 0 AND total_victimas >= 0)
    );

    CREATE TABLE dbo.federal_carga_tmp_carpeta
    (
        id_federal_carga_tmp_carpeta BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_carga BIGINT NOT NULL,
        numero_fila INT NOT NULL,
        id_ci NVARCHAR(250) NOT NULL,
        ntra_ci NVARCHAR(250) NOT NULL,
        fha_de_ini NVARCHAR(50) NOT NULL,
        hra_de_ini NVARCHAR(50) NULL,
        rmen_de_hchos NVARCHAR(MAX) NULL,
        estado NVARCHAR(50) NOT NULL CONSTRAINT DF_federal_tmp_carpeta_estado DEFAULT (N'PENDIENTE'),
        fecha_procesamiento DATETIME2(0) NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_tmp_carpeta_activo DEFAULT (1),
        CONSTRAINT PK_federal_carga_tmp_carpeta PRIMARY KEY (id_federal_carga_tmp_carpeta),
        CONSTRAINT FK_federal_tmp_carpeta_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga)
    );

    CREATE TABLE dbo.federal_carga_tmp_delito
    (
        id_federal_carga_tmp_delito BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_carga BIGINT NOT NULL,
        numero_fila INT NOT NULL,
        id_ci NVARCHAR(250) NOT NULL,
        id_delito NVARCHAR(250) NOT NULL,
        dto NVARCHAR(MAX) NOT NULL,
        moda_dto NVARCHAR(MAX) NULL,
        forma_acc NVARCHAR(150) NOT NULL,
        fha_de_hchos NVARCHAR(50) NULL,
        hra_de_hchos NVARCHAR(50) NULL,
        emto_com_dto NVARCHAR(150) NOT NULL,
        grdo_cons NVARCHAR(150) NOT NULL,
        clasf_de_dto NVARCHAR(100) NOT NULL,
        id_ent_hchos NVARCHAR(150) NOT NULL,
        id_mun_hchos NVARCHAR(150) NOT NULL,
        id_loc_hchos NVARCHAR(250) NULL,
        nom_loc_hchos NVARCHAR(250) NULL,
        id_col_hchos NVARCHAR(250) NULL,
        nom_col_hchos NVARCHAR(250) NULL,
        cp NVARCHAR(250) NULL,
        coord_x NVARCHAR(50) NULL,
        coord_y NVARCHAR(50) NULL,
        dom_hchos NVARCHAR(MAX) NULL,
        estado NVARCHAR(50) NOT NULL CONSTRAINT DF_federal_tmp_delito_estado DEFAULT (N'PENDIENTE'),
        fecha_procesamiento DATETIME2(0) NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_tmp_delito_activo DEFAULT (1),
        CONSTRAINT PK_federal_carga_tmp_delito PRIMARY KEY (id_federal_carga_tmp_delito),
        CONSTRAINT FK_federal_tmp_delito_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga)
    );

    CREATE TABLE dbo.federal_carga_tmp_victima
    (
        id_federal_carga_tmp_victima BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_carga BIGINT NOT NULL,
        numero_fila INT NOT NULL,
        id_ci NVARCHAR(250) NOT NULL,
        id_delito NVARCHAR(250) NOT NULL,
        id_vicf NVARCHAR(250) NOT NULL,
        id_tv NVARCHAR(50) NOT NULL,
        id_tpm NVARCHAR(50) NULL,
        sexo NVARCHAR(50) NULL,
        genero NVARCHAR(50) NULL,
        pob NVARCHAR(50) NULL,
        disc NVARCHAR(50) NULL,
        fha_nac NVARCHAR(50) NULL,
        edad NVARCHAR(50) NULL,
        nacional NVARCHAR(50) NULL,
        estado NVARCHAR(50) NOT NULL CONSTRAINT DF_federal_tmp_victima_estado DEFAULT (N'PENDIENTE'),
        fecha_procesamiento DATETIME2(0) NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_tmp_victima_activo DEFAULT (1),
        CONSTRAINT PK_federal_carga_tmp_victima PRIMARY KEY (id_federal_carga_tmp_victima),
        CONSTRAINT FK_federal_tmp_victima_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga)
    );

    CREATE TABLE dbo.federal_carga_advertencia
    (
        id_federal_carga_advertencia BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_carga BIGINT NOT NULL,
        codigo NVARCHAR(150) NOT NULL,
        archivo NVARCHAR(50) NOT NULL,
        numero_fila INT NULL,
        columna NVARCHAR(150) NULL,
        campo NVARCHAR(150) NULL,
        valor NVARCHAR(1000) NULL,
        descripcion_resumen NVARCHAR(500) NOT NULL,
        mensaje NVARCHAR(2000) NOT NULL,
        aceptada_usuario BIT NOT NULL CONSTRAINT DF_federal_advertencia_aceptada DEFAULT (0),
        id_usuario_aceptacion INT NULL,
        fecha_aceptacion DATETIME2(0) NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_advertencia_activo DEFAULT (1),
        CONSTRAINT PK_federal_carga_advertencia PRIMARY KEY (id_federal_carga_advertencia),
        CONSTRAINT FK_federal_advertencia_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga),
        CONSTRAINT FK_federal_advertencia_usuario FOREIGN KEY (id_usuario_aceptacion) REFERENCES dbo.usuario(id_usuario)
    );

    CREATE TABLE dbo.federal_carga_bitacora_estado
    (
        id_federal_carga_bitacora_estado BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_carga BIGINT NOT NULL,
        estado_anterior NVARCHAR(50) NULL,
        estado_nuevo NVARCHAR(50) NOT NULL,
        id_usuario INT NULL,
        fecha DATETIME2(0) NOT NULL CONSTRAINT DF_federal_bitacora_fecha DEFAULT (SYSDATETIME()),
        comentario NVARCHAR(2000) NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_bitacora_activo DEFAULT (1),
        CONSTRAINT PK_federal_carga_bitacora_estado PRIMARY KEY (id_federal_carga_bitacora_estado),
        CONSTRAINT FK_federal_bitacora_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga),
        CONSTRAINT FK_federal_bitacora_usuario FOREIGN KEY (id_usuario) REFERENCES dbo.usuario(id_usuario)
    );

    CREATE TABLE dbo.federal_carpeta_investigacion
    (
        id_federal_carpeta_investigacion BIGINT IDENTITY(1,1) NOT NULL,
        identificador_carpeta_fiscalia NVARCHAR(250) NOT NULL,
        nomenclatura_carpeta_fiscalia NVARCHAR(250) NOT NULL,
        fecha_inicio DATETIME2(0) NOT NULL,
        resumen_hechos NVARCHAR(MAX) NULL,
        id_usuario_registro INT NOT NULL,
        fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_federal_carpeta_fecha DEFAULT (SYSDATETIME()),
        id_federal_carga BIGINT NOT NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_carpeta_activo DEFAULT (1),
        CONSTRAINT PK_federal_carpeta_investigacion PRIMARY KEY (id_federal_carpeta_investigacion),
        CONSTRAINT FK_federal_carpeta_usuario FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_carpeta_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga)
    );

    CREATE TABLE dbo.federal_carpeta_investigacion_historico
    (
        id_federal_carpeta_investigacion_historico BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_carpeta_investigacion BIGINT NOT NULL,
        identificador_carpeta_fiscalia NVARCHAR(250) NOT NULL,
        nomenclatura_carpeta_fiscalia NVARCHAR(250) NOT NULL,
        fecha_inicio DATETIME2(0) NOT NULL,
        resumen_hechos NVARCHAR(MAX) NULL,
        id_usuario_registro INT NOT NULL,
        fecha_registro DATETIME2(0) NOT NULL,
        id_federal_carga BIGINT NOT NULL,
        id_usuario_modificacion INT NULL,
        id_federal_carga_nueva BIGINT NOT NULL,
        tipo_movimiento NVARCHAR(20) NOT NULL CONSTRAINT DF_federal_carpeta_hist_tipo DEFAULT (N'MODIFICADO'),
        fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_federal_carpeta_hist_fecha DEFAULT (SYSDATETIME()),
        activo BIT NOT NULL CONSTRAINT DF_federal_carpeta_hist_activo DEFAULT (1),
        CONSTRAINT PK_federal_carpeta_investigacion_historico PRIMARY KEY (id_federal_carpeta_investigacion_historico),
        CONSTRAINT FK_federal_carpeta_hist_carpeta FOREIGN KEY (id_federal_carpeta_investigacion) REFERENCES dbo.federal_carpeta_investigacion(id_federal_carpeta_investigacion),
        CONSTRAINT FK_federal_carpeta_hist_usuario FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_carpeta_hist_modificador FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_carpeta_hist_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga),
        CONSTRAINT FK_federal_carpeta_hist_carga_nueva FOREIGN KEY (id_federal_carga_nueva) REFERENCES dbo.federal_carga(id_federal_carga),
        CONSTRAINT CK_federal_carpeta_hist_tipo CHECK (tipo_movimiento IN (N'MODIFICADO', N'ELIMINADO'))
    );

    CREATE TABLE dbo.federal_delito
    (
        id_federal_delito BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_carpeta_investigacion BIGINT NOT NULL,
        identificador_delito_fiscalia NVARCHAR(250) NOT NULL,
        delito_fiscalia NVARCHAR(2000) NOT NULL,
        modalidad_delito_fiscalia NVARCHAR(2000) NULL,
        id_forma_accion TINYINT NOT NULL,
        fecha_hechos DATETIME2(0) NULL,
        id_instrumento_comision TINYINT NOT NULL,
        id_grado_consumacion TINYINT NOT NULL,
        id_modalidad_delito INT NOT NULL,
        id_entidad_federativa TINYINT NOT NULL,
        id_municipio INT NOT NULL,
        id_localidad_fiscalia NVARCHAR(250) NULL,
        localidad_fiscalia_nombre NVARCHAR(250) NULL,
        id_colonia_fiscalia NVARCHAR(250) NULL,
        colonia_fiscalia_nombre NVARCHAR(250) NULL,
        id_codigo_postal INT NULL,
        codigo_postal_fiscalia NVARCHAR(50) NULL,
        coordenada_x DECIMAL(10,6) NULL,
        coordenada_y DECIMAL(10,6) NULL,
        domicilio_hechos NVARCHAR(MAX) NULL,
        id_usuario_registro INT NOT NULL,
        fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_federal_delito_fecha DEFAULT (SYSDATETIME()),
        id_federal_carga BIGINT NOT NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_delito_activo DEFAULT (1),
        CONSTRAINT PK_federal_delito PRIMARY KEY (id_federal_delito),
        CONSTRAINT FK_federal_delito_carpeta FOREIGN KEY (id_federal_carpeta_investigacion) REFERENCES dbo.federal_carpeta_investigacion(id_federal_carpeta_investigacion),
        CONSTRAINT FK_federal_delito_forma FOREIGN KEY (id_forma_accion) REFERENCES dbo.catalogo_forma_accion(id_forma_accion),
        CONSTRAINT FK_federal_delito_instrumento FOREIGN KEY (id_instrumento_comision) REFERENCES dbo.catalogo_instrumento_comision(id_instrumento_comision),
        CONSTRAINT FK_federal_delito_grado FOREIGN KEY (id_grado_consumacion) REFERENCES dbo.catalogo_grado_consumacion(id_grado_consumacion),
        CONSTRAINT FK_federal_delito_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.federal_catalogo_modalidad_delito(id_modalidad_delito),
        CONSTRAINT FK_federal_delito_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
        CONSTRAINT FK_federal_delito_municipio FOREIGN KEY (id_municipio) REFERENCES dbo.catalogo_municipio(id_municipio),
        CONSTRAINT FK_federal_delito_cp FOREIGN KEY (id_codigo_postal) REFERENCES dbo.catalogo_codigo_postal(id_codigo_postal),
        CONSTRAINT FK_federal_delito_usuario FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_delito_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga)
    );

    CREATE TABLE dbo.federal_delito_historico
    (
        id_federal_delito_historico BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_delito BIGINT NOT NULL,
        id_federal_carpeta_investigacion BIGINT NOT NULL,
        identificador_delito_fiscalia NVARCHAR(250) NOT NULL,
        delito_fiscalia NVARCHAR(2000) NOT NULL,
        modalidad_delito_fiscalia NVARCHAR(2000) NULL,
        id_forma_accion TINYINT NOT NULL,
        fecha_hechos DATETIME2(0) NULL,
        id_instrumento_comision TINYINT NOT NULL,
        id_grado_consumacion TINYINT NOT NULL,
        id_modalidad_delito INT NOT NULL,
        id_entidad_federativa TINYINT NOT NULL,
        id_municipio INT NOT NULL,
        id_localidad_fiscalia NVARCHAR(250) NULL,
        localidad_fiscalia_nombre NVARCHAR(250) NULL,
        id_colonia_fiscalia NVARCHAR(250) NULL,
        colonia_fiscalia_nombre NVARCHAR(250) NULL,
        id_codigo_postal INT NULL,
        codigo_postal_fiscalia NVARCHAR(50) NULL,
        coordenada_x DECIMAL(10,6) NULL,
        coordenada_y DECIMAL(10,6) NULL,
        domicilio_hechos NVARCHAR(MAX) NULL,
        id_usuario_registro INT NOT NULL,
        fecha_registro DATETIME2(0) NOT NULL,
        id_federal_carga BIGINT NOT NULL,
        id_usuario_modificacion INT NULL,
        id_federal_carga_nueva BIGINT NOT NULL,
        tipo_movimiento NVARCHAR(20) NOT NULL CONSTRAINT DF_federal_delito_hist_tipo DEFAULT (N'MODIFICADO'),
        fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_federal_delito_hist_fecha DEFAULT (SYSDATETIME()),
        activo BIT NOT NULL CONSTRAINT DF_federal_delito_hist_activo DEFAULT (1),
        CONSTRAINT PK_federal_delito_historico PRIMARY KEY (id_federal_delito_historico),
        CONSTRAINT FK_federal_delito_hist_delito FOREIGN KEY (id_federal_delito) REFERENCES dbo.federal_delito(id_federal_delito),
        CONSTRAINT FK_federal_delito_hist_carpeta FOREIGN KEY (id_federal_carpeta_investigacion) REFERENCES dbo.federal_carpeta_investigacion(id_federal_carpeta_investigacion),
        CONSTRAINT FK_federal_delito_hist_forma FOREIGN KEY (id_forma_accion) REFERENCES dbo.catalogo_forma_accion(id_forma_accion),
        CONSTRAINT FK_federal_delito_hist_instrumento FOREIGN KEY (id_instrumento_comision) REFERENCES dbo.catalogo_instrumento_comision(id_instrumento_comision),
        CONSTRAINT FK_federal_delito_hist_grado FOREIGN KEY (id_grado_consumacion) REFERENCES dbo.catalogo_grado_consumacion(id_grado_consumacion),
        CONSTRAINT FK_federal_delito_hist_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.federal_catalogo_modalidad_delito(id_modalidad_delito),
        CONSTRAINT FK_federal_delito_hist_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
        CONSTRAINT FK_federal_delito_hist_municipio FOREIGN KEY (id_municipio) REFERENCES dbo.catalogo_municipio(id_municipio),
        CONSTRAINT FK_federal_delito_hist_cp FOREIGN KEY (id_codigo_postal) REFERENCES dbo.catalogo_codigo_postal(id_codigo_postal),
        CONSTRAINT FK_federal_delito_hist_usuario FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_delito_hist_modificador FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_delito_hist_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga),
        CONSTRAINT FK_federal_delito_hist_carga_nueva FOREIGN KEY (id_federal_carga_nueva) REFERENCES dbo.federal_carga(id_federal_carga),
        CONSTRAINT CK_federal_delito_hist_tipo CHECK (tipo_movimiento IN (N'MODIFICADO', N'ELIMINADO'))
    );

    CREATE TABLE dbo.federal_victima
    (
        id_federal_victima BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_delito BIGINT NOT NULL,
        identificador_victima_fiscalia NVARCHAR(250) NOT NULL,
        id_tipo_victima TINYINT NOT NULL,
        id_tipo_victima_moral TINYINT NULL,
        id_sexo TINYINT NULL,
        id_genero TINYINT NULL,
        id_nacionalidad INT NULL,
        id_pertenece_poblacion_indigena TINYINT NULL,
        id_presenta_discapacidad TINYINT NULL,
        fecha_nacimiento DATE NULL,
        edad SMALLINT NULL,
        id_usuario_registro INT NOT NULL,
        fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_federal_victima_fecha DEFAULT (SYSDATETIME()),
        id_federal_carga BIGINT NOT NULL,
        activo BIT NOT NULL CONSTRAINT DF_federal_victima_activo DEFAULT (1),
        CONSTRAINT PK_federal_victima PRIMARY KEY (id_federal_victima),
        CONSTRAINT FK_federal_victima_delito FOREIGN KEY (id_federal_delito) REFERENCES dbo.federal_delito(id_federal_delito),
        CONSTRAINT FK_federal_victima_tipo FOREIGN KEY (id_tipo_victima) REFERENCES dbo.catalogo_tipo_victima(id_tipo_victima),
        CONSTRAINT FK_federal_victima_tipo_moral FOREIGN KEY (id_tipo_victima_moral) REFERENCES dbo.catalogo_tipo_victima_moral(id_tipo_victima_moral),
        CONSTRAINT FK_federal_victima_sexo FOREIGN KEY (id_sexo) REFERENCES dbo.catalogo_sexo(id_sexo),
        CONSTRAINT FK_federal_victima_genero FOREIGN KEY (id_genero) REFERENCES dbo.catalogo_genero(id_genero),
        CONSTRAINT FK_federal_victima_nacionalidad FOREIGN KEY (id_nacionalidad) REFERENCES dbo.catalogo_nacionalidad(id_nacionalidad),
        CONSTRAINT FK_federal_victima_poblacion FOREIGN KEY (id_pertenece_poblacion_indigena) REFERENCES dbo.catalogo_pertenece_poblacion_indigena(id_pertenece_poblacion_indigena),
        CONSTRAINT FK_federal_victima_discapacidad FOREIGN KEY (id_presenta_discapacidad) REFERENCES dbo.catalogo_presenta_discapacidad(id_presenta_discapacidad),
        CONSTRAINT FK_federal_victima_usuario FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_victima_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga)
    );

    CREATE TABLE dbo.federal_victima_historico
    (
        id_federal_victima_historico BIGINT IDENTITY(1,1) NOT NULL,
        id_federal_victima BIGINT NOT NULL,
        id_federal_delito BIGINT NOT NULL,
        identificador_victima_fiscalia NVARCHAR(250) NOT NULL,
        id_tipo_victima TINYINT NOT NULL,
        id_tipo_victima_moral TINYINT NULL,
        id_sexo TINYINT NULL,
        id_genero TINYINT NULL,
        id_nacionalidad INT NULL,
        id_pertenece_poblacion_indigena TINYINT NULL,
        id_presenta_discapacidad TINYINT NULL,
        fecha_nacimiento DATE NULL,
        edad SMALLINT NULL,
        id_usuario_registro INT NOT NULL,
        fecha_registro DATETIME2(0) NOT NULL,
        id_federal_carga BIGINT NOT NULL,
        id_usuario_modificacion INT NULL,
        id_federal_carga_nueva BIGINT NOT NULL,
        tipo_movimiento NVARCHAR(20) NOT NULL CONSTRAINT DF_federal_victima_hist_tipo DEFAULT (N'MODIFICADO'),
        fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_federal_victima_hist_fecha DEFAULT (SYSDATETIME()),
        activo BIT NOT NULL CONSTRAINT DF_federal_victima_hist_activo DEFAULT (1),
        CONSTRAINT PK_federal_victima_historico PRIMARY KEY (id_federal_victima_historico),
        CONSTRAINT FK_federal_victima_hist_victima FOREIGN KEY (id_federal_victima) REFERENCES dbo.federal_victima(id_federal_victima),
        CONSTRAINT FK_federal_victima_hist_delito FOREIGN KEY (id_federal_delito) REFERENCES dbo.federal_delito(id_federal_delito),
        CONSTRAINT FK_federal_victima_hist_tipo FOREIGN KEY (id_tipo_victima) REFERENCES dbo.catalogo_tipo_victima(id_tipo_victima),
        CONSTRAINT FK_federal_victima_hist_tipo_moral FOREIGN KEY (id_tipo_victima_moral) REFERENCES dbo.catalogo_tipo_victima_moral(id_tipo_victima_moral),
        CONSTRAINT FK_federal_victima_hist_sexo FOREIGN KEY (id_sexo) REFERENCES dbo.catalogo_sexo(id_sexo),
        CONSTRAINT FK_federal_victima_hist_genero FOREIGN KEY (id_genero) REFERENCES dbo.catalogo_genero(id_genero),
        CONSTRAINT FK_federal_victima_hist_nacionalidad FOREIGN KEY (id_nacionalidad) REFERENCES dbo.catalogo_nacionalidad(id_nacionalidad),
        CONSTRAINT FK_federal_victima_hist_poblacion FOREIGN KEY (id_pertenece_poblacion_indigena) REFERENCES dbo.catalogo_pertenece_poblacion_indigena(id_pertenece_poblacion_indigena),
        CONSTRAINT FK_federal_victima_hist_discapacidad FOREIGN KEY (id_presenta_discapacidad) REFERENCES dbo.catalogo_presenta_discapacidad(id_presenta_discapacidad),
        CONSTRAINT FK_federal_victima_hist_usuario FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_victima_hist_modificador FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT FK_federal_victima_hist_carga FOREIGN KEY (id_federal_carga) REFERENCES dbo.federal_carga(id_federal_carga),
        CONSTRAINT FK_federal_victima_hist_carga_nueva FOREIGN KEY (id_federal_carga_nueva) REFERENCES dbo.federal_carga(id_federal_carga),
        CONSTRAINT CK_federal_victima_hist_tipo CHECK (tipo_movimiento IN (N'MODIFICADO', N'ELIMINADO'))
    );

    CREATE INDEX IX_federal_sabana_modalidad ON dbo.federal_catalogo_delito_sabana(id_modalidad_delito);
    CREATE INDEX IX_federal_sabana_busqueda ON dbo.federal_catalogo_delito_sabana(id_modalidad_delito, id_grado_consumacion, id_instrumento_comision, id_forma_accion, activo);
    CREATE INDEX IX_federal_carga_periodo_estado ON dbo.federal_carga(anio_corte, mes_corte, estado, activo) INCLUDE (id_federal_carga, id_usuario_carga, codigo_referencia, tipo_carga, fecha_confirmacion);
    CREATE INDEX IX_federal_carga_usuario ON dbo.federal_carga(id_usuario_carga, anio_corte, mes_corte, activo);
    CREATE INDEX IX_federal_tmp_carpeta_carga_ci ON dbo.federal_carga_tmp_carpeta(id_federal_carga, activo, id_ci);
    CREATE INDEX IX_federal_tmp_delito_carga_llave ON dbo.federal_carga_tmp_delito(id_federal_carga, activo, id_ci, id_delito);
    CREATE INDEX IX_federal_tmp_victima_carga_llave ON dbo.federal_carga_tmp_victima(id_federal_carga, activo, id_ci, id_delito, id_vicf);
    CREATE INDEX IX_federal_advertencia_carga ON dbo.federal_carga_advertencia(id_federal_carga, activo);
    CREATE INDEX IX_federal_bitacora_carga_fecha ON dbo.federal_carga_bitacora_estado(id_federal_carga, fecha, id_federal_carga_bitacora_estado);
    CREATE INDEX IX_federal_carpeta_carga_ci ON dbo.federal_carpeta_investigacion(id_federal_carga, activo, identificador_carpeta_fiscalia);
    CREATE INDEX IX_federal_delito_carpeta ON dbo.federal_delito(id_federal_carpeta_investigacion, activo);
    CREATE INDEX IX_federal_delito_carga_llave ON dbo.federal_delito(id_federal_carga, activo, identificador_delito_fiscalia);
    CREATE INDEX IX_federal_delito_modalidad ON dbo.federal_delito(id_modalidad_delito);
    CREATE INDEX IX_federal_delito_entidad_municipio ON dbo.federal_delito(id_entidad_federativa, id_municipio);
    CREATE INDEX IX_federal_victima_delito ON dbo.federal_victima(id_federal_delito, activo);
    CREATE INDEX IX_federal_victima_carga ON dbo.federal_victima(id_federal_carga, activo);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT id_modulo, clave, nombre, activo
FROM dbo.catalogo_modulo
WHERE clave = N'FEDERAL';

SELECT
    t.name AS tabla_federal,
    SUM(p.rows) AS registros
FROM sys.tables t
INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE s.name = N'dbo'
  AND t.name LIKE N'federal[_]%'
GROUP BY t.name
ORDER BY t.name;
GO
