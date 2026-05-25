USE master;
GO

IF DB_ID(N'siiid2') IS NOT NULL
BEGIN
    ALTER DATABASE [siiid2]
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    DROP DATABASE [siiid2];
END
GO

CREATE DATABASE [siiid2];
GO

USE [siiid2];
GO

IF DB_ID(N'siiid2') IS NULL CREATE DATABASE [siiid2];

GO
USE [siiid2];
GO

CREATE TABLE [roles] (
  id_rol INT NOT NULL IDENTITY(1,1),
  rol NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_roles] PRIMARY KEY (id_rol),
  CONSTRAINT [uk_roles_rol] UNIQUE (rol)
);
GO

CREATE TABLE [catalogo_asentamiento] (
  id_asentamiento INT NOT NULL,
  descripcion NVARCHAR(100) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_asentamiento] PRIMARY KEY (id_asentamiento)
);
GO

CREATE TABLE [catalogo_oficina] (
  id_oficina INT NOT NULL,
  clave NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_oficina] PRIMARY KEY (id_oficina),
  CONSTRAINT [uk_catalogo_oficina_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_tipo_asentamiento] (
  id_tipo_asentamiento TINYINT NOT NULL,
  clave NVARCHAR(5) NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_tipo_asentamiento] PRIMARY KEY (id_tipo_asentamiento),
  CONSTRAINT [uk_catalogo_tipo_asentamiento_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_tipo_zona] (
  id_tipo_zona TINYINT NOT NULL,
  descripcion NVARCHAR(15) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_tipo_zona] PRIMARY KEY (id_tipo_zona)
);
GO

CREATE TABLE [catalogo_ciudad] (
  id_ciudad INT NOT NULL,
  clave NVARCHAR(5) NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_ciudad] PRIMARY KEY (id_ciudad)
);
GO

CREATE TABLE [catalogo_entidad_federativa] (
  id_entidad_federativa TINYINT NOT NULL,
  clave NVARCHAR(3) NOT NULL,
  nombre NVARCHAR(50) NOT NULL,
  siglas NVARCHAR(10) NOT NULL,
  siglas_renapo NVARCHAR(10) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_entidad_federativa] PRIMARY KEY (id_entidad_federativa),
  CONSTRAINT [uk_catalogo_entidad_federativa_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_municipio] (
  id_municipio INT NOT NULL,
  id_entidad_federativa TINYINT NOT NULL,
  clave NVARCHAR(5) NOT NULL,
  nombre NVARCHAR(150) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_municipio] PRIMARY KEY (id_municipio),
  CONSTRAINT [uk_catalogo_municipio_entidad_clave] UNIQUE (id_entidad_federativa, clave),
  CONSTRAINT [fk_catalogo_municipio_entidad]
    FOREIGN KEY (id_entidad_federativa) REFERENCES catalogo_entidad_federativa (id_entidad_federativa)
);
GO

CREATE TABLE [catalogo_localidad] (
  id_localidad INT NOT NULL,
  id_municipio INT NOT NULL,
  clave NVARCHAR(5) NOT NULL,
  nombre NVARCHAR(150) NOT NULL,
  id_tipo_zona TINYINT NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_localidad] PRIMARY KEY (id_localidad),
  CONSTRAINT [fk_catalogo_localidad_municipio]
    FOREIGN KEY (id_municipio) REFERENCES catalogo_municipio (id_municipio),
  CONSTRAINT [fk_catalogo_localidad_tipo_zona]
    FOREIGN KEY (id_tipo_zona) REFERENCES catalogo_tipo_zona (id_tipo_zona)
);
GO

CREATE TABLE [catalogo_codigo_postal] (
  id_codigo_postal INT NOT NULL,
  codigo_postal NVARCHAR(5) NOT NULL,
  clave_asentamiento_cp_consecutivo NVARCHAR(5) NULL,
  id_asentamiento INT NOT NULL,
  id_oficina INT NOT NULL,
  id_tipo_asentamiento TINYINT NOT NULL,
  id_municipio INT NOT NULL,
  id_tipo_zona TINYINT NULL,
  id_ciudad INT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_codigo_postal] PRIMARY KEY (id_codigo_postal),
  CONSTRAINT [fk_catalogo_codigo_postal_asentamiento]
    FOREIGN KEY (id_asentamiento) REFERENCES catalogo_asentamiento (id_asentamiento),
  CONSTRAINT [fk_catalogo_codigo_postal_oficina]
    FOREIGN KEY (id_oficina) REFERENCES catalogo_oficina (id_oficina),
  CONSTRAINT [fk_catalogo_codigo_postal_tipo_asentamiento]
    FOREIGN KEY (id_tipo_asentamiento) REFERENCES catalogo_tipo_asentamiento (id_tipo_asentamiento),
  CONSTRAINT [fk_catalogo_codigo_postal_municipio]
    FOREIGN KEY (id_municipio) REFERENCES catalogo_municipio (id_municipio),
  CONSTRAINT [fk_catalogo_codigo_postal_tipo_zona]
    FOREIGN KEY (id_tipo_zona) REFERENCES catalogo_tipo_zona (id_tipo_zona),
  CONSTRAINT [fk_catalogo_codigo_postal_ciudad]
    FOREIGN KEY (id_ciudad) REFERENCES catalogo_ciudad (id_ciudad)
);
GO

CREATE TABLE [catalogo_bien_juridico] (
  id_bien_juridico INT NOT NULL,
  clave1 NVARCHAR(10) NOT NULL,
  bien_juridico NVARCHAR(200) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_bien_juridico] PRIMARY KEY (id_bien_juridico),
  CONSTRAINT [uk_catalogo_bien_juridico_clave1] UNIQUE (clave1)
);
GO

CREATE TABLE [catalogo_delito] (
  id_delito INT NOT NULL,
  id_bien_juridico INT NOT NULL,
  clave2 NVARCHAR(10) NOT NULL,
  delito NVARCHAR(200) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_delito] PRIMARY KEY (id_delito),
  CONSTRAINT [fk_catalogo_delito_bien_juridico]
    FOREIGN KEY (id_bien_juridico) REFERENCES catalogo_bien_juridico (id_bien_juridico)
);
GO

CREATE TABLE [catalogo_subtipo_delito] (
  id_subtipo_delito INT NOT NULL,
  id_delito INT NOT NULL,
  clave3 NVARCHAR(20) NOT NULL,
  subtipo_delito NVARCHAR(200) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_subtipo_delito] PRIMARY KEY (id_subtipo_delito),
  CONSTRAINT [fk_catalogo_subtipo_delito_delito]
    FOREIGN KEY (id_delito) REFERENCES catalogo_delito (id_delito)
);
GO

CREATE TABLE [catalogo_admite_tentativa] (
  id_admite_tentativa TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(100) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_admite_tentativa] PRIMARY KEY (id_admite_tentativa),
  CONSTRAINT [uk_catalogo_admite_tentativa_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_modalidad_delito] (
  id_modalidad_delito INT NOT NULL,
  id_subtipo_delito INT NOT NULL,
  clave4 NVARCHAR(20) NOT NULL,
  modalidad_delito NVARCHAR(250) NOT NULL,
  id_admite_tentativa TINYINT NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_modalidad_delito] PRIMARY KEY (id_modalidad_delito),
  CONSTRAINT [fk_catalogo_modalidad_delito_subtipo]
    FOREIGN KEY (id_subtipo_delito) REFERENCES catalogo_subtipo_delito (id_subtipo_delito),
  CONSTRAINT [fk_catalogo_modalidad_delito_admite_tentativa]
    FOREIGN KEY (id_admite_tentativa) REFERENCES catalogo_admite_tentativa (id_admite_tentativa)
);
GO

CREATE TABLE [catalogo_grado_consumacion] (
  id_grado_consumacion TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_grado_consumacion] PRIMARY KEY (id_grado_consumacion),
  CONSTRAINT [uk_catalogo_grado_consumacion_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_forma_accion] (
  id_forma_accion TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_forma_accion] PRIMARY KEY (id_forma_accion),
  CONSTRAINT [uk_catalogo_forma_accion_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_instrumento_comision] (
  id_instrumento_comision TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_instrumento_comision] PRIMARY KEY (id_instrumento_comision),
  CONSTRAINT [uk_catalogo_instrumento_comision_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_delito_sabana] (
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
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_delito_sabana] PRIMARY KEY (id_delito_sabana),
  CONSTRAINT [uk_sabana_combinacion] UNIQUE (id_modalidad_delito, id_grado_consumacion, id_instrumento_comision, id_forma_accion, clave2_sabana, clave3_sabana),
  CONSTRAINT [fk_sabana_modalidad]
    FOREIGN KEY (id_modalidad_delito)
    REFERENCES catalogo_modalidad_delito (id_modalidad_delito),
  CONSTRAINT [fk_sabana_grado]
    FOREIGN KEY (id_grado_consumacion)
    REFERENCES catalogo_grado_consumacion (id_grado_consumacion),
  CONSTRAINT [fk_sabana_instrumento]
    FOREIGN KEY (id_instrumento_comision)
    REFERENCES catalogo_instrumento_comision (id_instrumento_comision),
  CONSTRAINT [fk_sabana_forma]
    FOREIGN KEY (id_forma_accion)
    REFERENCES catalogo_forma_accion (id_forma_accion)
);
GO

CREATE TABLE [catalogo_tipo_expediente] (
  id_tipo_expediente TINYINT NOT NULL,
  clave NVARCHAR(5) NOT NULL,
  descripcion NVARCHAR(25) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_tipo_expediente] PRIMARY KEY (id_tipo_expediente),
  CONSTRAINT [uk_catalogo_tipo_expediente_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_tipo_relacion] (
  id_tipo_relacion TINYINT NOT NULL,
  clave NVARCHAR(5) NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_tipo_relacion] PRIMARY KEY (id_tipo_relacion),
  CONSTRAINT [uk_catalogo_tipo_relacion_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_nacionalidad] (
  id_nacionalidad INT NOT NULL,
  clave NVARCHAR(5) NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_nacionalidad] PRIMARY KEY (id_nacionalidad),
  CONSTRAINT [uk_catalogo_nacionalidad_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_genero] (
  id_genero TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_genero] PRIMARY KEY (id_genero),
  CONSTRAINT [uk_catalogo_genero_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_sexo] (
  id_sexo TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_sexo] PRIMARY KEY (id_sexo),
  CONSTRAINT [uk_catalogo_sexo_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_pertenece_poblacion_indigena] (
  id_pertenece_poblacion_indigena TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_pertenece_poblacion_indigena] PRIMARY KEY (id_pertenece_poblacion_indigena),
  CONSTRAINT [uk_catalogo_pertenece_poblacion_indigena_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_presenta_discapacidad] (
  id_presenta_discapacidad TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_presenta_discapacidad] PRIMARY KEY (id_presenta_discapacidad),
  CONSTRAINT [uk_catalogo_presenta_discapacidad_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_tipo_victima] (
  id_tipo_victima TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_tipo_victima] PRIMARY KEY (id_tipo_victima),
  CONSTRAINT [uk_catalogo_tipo_victima_clave] UNIQUE (clave)
);
GO

CREATE TABLE [catalogo_tipo_victima_moral] (
  id_tipo_victima_moral TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion NVARCHAR(50) NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_catalogo_tipo_victima_moral] PRIMARY KEY (id_tipo_victima_moral),
  CONSTRAINT [uk_catalogo_tipo_victima_moral_clave] UNIQUE (clave)
);
GO

CREATE TABLE [usuario] (
  id_usuario INT NOT NULL IDENTITY(1,1),
  usuario NVARCHAR(50) NOT NULL,
  [password] NVARCHAR(255) NOT NULL,
  nombre NVARCHAR(50) NOT NULL,
  primer_apellido NVARCHAR(50) NOT NULL,
  segundo_apellido NVARCHAR(50) NULL,
  correo_electronico NVARCHAR(100) NOT NULL,
  rfc NVARCHAR(13) NOT NULL,
  curp NVARCHAR(18) NOT NULL,
  telefono_contacto NVARCHAR(15) NULL,
  id_entidad_federativa TINYINT NULL,
  fecha_alta DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
  fecha_modificacion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
  id_usuario_alta INT NULL,
  id_usuario_modificacion INT NULL,
  id_rol INT NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_usuario] PRIMARY KEY (id_usuario),
  CONSTRAINT [uk_usuario_usuario] UNIQUE (usuario),
  CONSTRAINT [uk_usuario_correo] UNIQUE (correo_electronico),
  CONSTRAINT [uk_usuario_rfc] UNIQUE (rfc),
  CONSTRAINT [uk_usuario_curp] UNIQUE (curp),
  CONSTRAINT [fk_usuario_entidad]
    FOREIGN KEY (id_entidad_federativa) REFERENCES catalogo_entidad_federativa (id_entidad_federativa),
  CONSTRAINT [fk_usuario_usuario_alta]
    FOREIGN KEY (id_usuario_alta) REFERENCES usuario (id_usuario),
  CONSTRAINT [fk_usuario_usuario_modificacion]
    FOREIGN KEY (id_usuario_modificacion) REFERENCES usuario (id_usuario),
  CONSTRAINT [fk_usuario_rol]
    FOREIGN KEY (id_rol) REFERENCES roles (id_rol)
);
GO

CREATE TABLE carga (
    id_carga BIGINT IDENTITY(1,1) NOT NULL,
    id_usuario_carga INT NOT NULL,
    id_entidad_federativa TINYINT NULL,
    codigo_referencia NVARCHAR(50) NOT NULL,
    tipo_carga NVARCHAR(20) NOT NULL
        CONSTRAINT DF_carga_tipo_carga DEFAULT 'CARGA_INICIAL',
    mes_corte TINYINT NOT NULL,
    anio_corte SMALLINT NOT NULL,
    fecha_carga DATETIME2 NOT NULL
        CONSTRAINT DF_carga_fecha_carga DEFAULT SYSDATETIME(),
    total_carpetas_investigacion INT NOT NULL,
    total_delitos INT NOT NULL,
    total_victimas INT NOT NULL,
    estado NVARCHAR(50) NOT NULL
        CONSTRAINT DF_carga_estado DEFAULT 'VALIDADO_PENDIENTE',
    fecha_validacion DATETIME2 NOT NULL
        CONSTRAINT DF_carga_fecha_validacion DEFAULT SYSDATETIME(),
    fecha_confirmacion DATETIME2 NULL,
    fecha_expiracion DATETIME2 NULL,
    id_usuario_confirmacion INT NULL,
    mensaje_error NVARCHAR(MAX) NULL,
    activo BIT NOT NULL
        CONSTRAINT DF_carga_activo DEFAULT 1,

    CONSTRAINT PK_carga PRIMARY KEY (id_carga),

    CONSTRAINT FK_carga_usuario_carga
        FOREIGN KEY (id_usuario_carga)
        REFERENCES usuario(id_usuario),

    CONSTRAINT FK_carga_usuario_confirmacion
        FOREIGN KEY (id_usuario_confirmacion)
        REFERENCES usuario(id_usuario),

    CONSTRAINT FK_carga_entidad_federativa
        FOREIGN KEY (id_entidad_federativa)
        REFERENCES catalogo_entidad_federativa(id_entidad_federativa),

    CONSTRAINT UQ_carga_codigo_referencia
        UNIQUE (codigo_referencia),

    CONSTRAINT CK_carga_tipo_carga
        CHECK (tipo_carga IN ('CARGA_INICIAL', 'ACTUALIZACION'))
);
GO

CREATE INDEX idx_carga_usuario_carga
ON carga(id_usuario_carga);
GO

CREATE INDEX idx_carga_usuario_confirmacion
ON carga(id_usuario_confirmacion);
GO

CREATE INDEX idx_carga_estado
ON carga(estado);
GO

CREATE INDEX idx_carga_entidad_periodo_estado
ON carga(id_entidad_federativa, mes_corte, anio_corte, estado, activo);
GO

CREATE INDEX idx_carga_usuario_carga
ON carga (id_usuario_carga);

CREATE INDEX idx_carga_usuario_confirmacion
ON carga (id_usuario_confirmacion);

CREATE INDEX idx_carga_estado
ON carga (estado);

CREATE INDEX idx_carga_entidad_periodo_estado
ON carga (
    id_entidad_federativa,
    mes_corte,
    anio_corte,
    estado,
    activo
);
GO


CREATE TABLE [carga_tmp_carpeta] (
  id_carga_tmp_carpeta BIGINT NOT NULL IDENTITY(1,1),
  id_carga BIGINT NOT NULL,
  numero_fila INT NOT NULL,
  id_ci NVARCHAR(250) NOT NULL,
  ntra_ci NVARCHAR(250) NOT NULL,
  fha_de_ini NVARCHAR(50) NOT NULL,
  hra_de_ini NVARCHAR(50) NULL,
  rmen_de_hchos NVARCHAR(MAX) NULL,
  estado NVARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
  fecha_procesamiento DATETIME2(0) NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_carga_tmp_carpeta] PRIMARY KEY (id_carga_tmp_carpeta),
  CONSTRAINT [fk_carga_tmp_carpeta_carga]
  FOREIGN KEY (id_carga)
  REFERENCES carga(id_carga)
);
GO

CREATE TABLE [carga_tmp_delito] (
  id_carga_tmp_delito BIGINT NOT NULL IDENTITY(1,1),
  id_carga BIGINT NOT NULL,
  numero_fila INT NOT NULL,
  id_ci NVARCHAR(250) NOT NULL,
  id_delito NVARCHAR(50) NOT NULL,
  dto NVARCHAR(MAX) NOT NULL,
  moda_dto NVARCHAR(MAX) NULL,
  forma_acc NVARCHAR(50) NOT NULL,
  fha_de_hchos NVARCHAR(50) NOT NULL,
  hra_de_hchos NVARCHAR(50) NULL,
  emto_com_dto NVARCHAR(50) NOT NULL,
  grdo_cons NVARCHAR(50) NOT NULL,
  clasf_de_dto NVARCHAR(100) NOT NULL,
  id_ent_hchos NVARCHAR(50) NOT NULL,
  id_mun_hchos NVARCHAR(50) NOT NULL,
  id_loc_hchos NVARCHAR(50) NULL,
  nom_loc_hchos NVARCHAR(250) NULL,
  id_col_hchos NVARCHAR(50) NULL,
  nom_col_hchos NVARCHAR(250) NULL,
  cp NVARCHAR(20) NULL,
  coord_x NVARCHAR(50) NULL,
  coord_y NVARCHAR(50) NULL,
  dom_hchos NVARCHAR(MAX) NULL,
  estado NVARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
  fecha_procesamiento DATETIME2(0) NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_carga_tmp_delito] PRIMARY KEY (id_carga_tmp_delito),
  CONSTRAINT [fk_carga_tmp_delito_carga]
  FOREIGN KEY (id_carga)
  REFERENCES carga(id_carga)
);
GO

CREATE TABLE [carga_tmp_victima] (
  id_carga_tmp_victima BIGINT NOT NULL IDENTITY(1,1),
  id_carga BIGINT NOT NULL,
  numero_fila INT NOT NULL,
  id_ci NVARCHAR(250) NOT NULL,
  id_delito NVARCHAR(50) NOT NULL,
  id_vicf NVARCHAR(50) NOT NULL,
  id_tv NVARCHAR(50) NOT NULL,
  id_tpm NVARCHAR(50) NULL,
  sexo NVARCHAR(50) NULL,
  genero NVARCHAR(50) NULL,
  pob NVARCHAR(50) NULL,
  disc NVARCHAR(50) NULL,
  fha_nac NVARCHAR(50) NULL,
  edad NVARCHAR(50) NULL,
  nacional NVARCHAR(50) NULL,
  estado NVARCHAR(30) NOT NULL DEFAULT 'PENDIENTE',
  fecha_procesamiento DATETIME2(0) NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_carga_tmp_victima] PRIMARY KEY (id_carga_tmp_victima),
  CONSTRAINT [fk_carga_tmp_victima_carga]
  FOREIGN KEY (id_carga)
  REFERENCES carga(id_carga)
);
GO

CREATE TABLE [habilita_carga_modificacion] (
  id_habilita_carga_modificacion INT NOT NULL IDENTITY(1,1),
  habilita_carga BIT NOT NULL DEFAULT 0,
  habilita_modificacion BIT NOT NULL DEFAULT 0,
  id_usuario INT NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_habilita_carga_modificacion] PRIMARY KEY (id_habilita_carga_modificacion),
  CONSTRAINT [uk_habilita_carga_modificacion_usuario] UNIQUE (id_usuario),
  CONSTRAINT [fk_habilita_carga_modificacion_usuario]
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);
GO

CREATE TABLE [carpeta_investigacion] (
  id_carpeta_investigacion BIGINT NOT NULL IDENTITY(1,1),
  identificador_carpeta_fiscalia NVARCHAR(250) NOT NULL,
  nomenclatura_carpeta_fiscalia NVARCHAR(250) NOT NULL,
  fecha_inicio DATETIME2(0) NOT NULL,
  resumen_hechos NVARCHAR(MAX) NULL,
  id_usuario_registro INT NOT NULL,
  fecha_registro DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
  id_carga BIGINT NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_carpeta_investigacion] PRIMARY KEY (id_carpeta_investigacion),
  CONSTRAINT [fk_carpeta_investigacion_usuario_registro]
    FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario),
  CONSTRAINT [fk_carpeta_investigacion_carga]
    FOREIGN KEY (id_carga) REFERENCES carga (id_carga)
);
GO

CREATE TABLE carpeta_investigacion_historico (
    id_carpeta_investigacion_historico BIGINT IDENTITY(1,1) NOT NULL,
    id_carpeta_investigacion BIGINT NOT NULL,
    identificador_carpeta_fiscalia NVARCHAR(250) NOT NULL,
    nomenclatura_carpeta_fiscalia NVARCHAR(250) NOT NULL,
    fecha_inicio DATETIME2 NOT NULL,
    resumen_hechos NVARCHAR(MAX) NULL,
    id_usuario_registro INT NOT NULL,
    fecha_registro DATETIME2 NOT NULL,
    id_carga BIGINT NOT NULL,
    id_usuario_modificacion INT NULL,
    id_carga_nueva BIGINT NOT NULL,
    tipo_movimiento NVARCHAR(20) NOT NULL
        CONSTRAINT DF_carpeta_investigacion_historico_tipo_movimiento DEFAULT 'MODIFICADO',
    fecha_modificacion DATETIME2 NOT NULL
        CONSTRAINT DF_carpeta_investigacion_historico_fecha_modificacion DEFAULT SYSDATETIME(),
    activo BIT NOT NULL
        CONSTRAINT DF_carpeta_investigacion_historico_activo DEFAULT 1,

    CONSTRAINT PK_carpeta_investigacion_historico
        PRIMARY KEY (id_carpeta_investigacion_historico),

    CONSTRAINT FK_carpeta_investigacion_historico_carpeta
        FOREIGN KEY (id_carpeta_investigacion)
        REFERENCES carpeta_investigacion(id_carpeta_investigacion),

    CONSTRAINT FK_carpeta_investigacion_historico_usuario_registro
        FOREIGN KEY (id_usuario_registro)
        REFERENCES usuario(id_usuario),

    CONSTRAINT FK_carpeta_investigacion_historico_usuario_modificacion
        FOREIGN KEY (id_usuario_modificacion)
        REFERENCES usuario(id_usuario),

    CONSTRAINT FK_carpeta_investigacion_historico_carga
        FOREIGN KEY (id_carga)
        REFERENCES carga(id_carga),

    CONSTRAINT FK_carpeta_investigacion_historico_carga_nueva
        FOREIGN KEY (id_carga_nueva)
        REFERENCES carga(id_carga),

    CONSTRAINT CK_carpeta_investigacion_historico_tipo_movimiento
        CHECK (tipo_movimiento IN ('MODIFICADO', 'ELIMINADO'))
);
GO

CREATE TABLE delito (
    id_delito BIGINT IDENTITY(1,1) NOT NULL,
    id_carpeta_investigacion BIGINT NOT NULL,

    identificador_delito_fiscalia VARCHAR(50) NOT NULL,
    delito_fiscalia VARCHAR(250) NOT NULL,
    modalidad_delito_fiscalia VARCHAR(250) NULL,

    id_forma_accion TINYINT NOT NULL,
    fecha_hechos DATETIME NOT NULL,
    id_instrumento_comision TINYINT NOT NULL,
    id_grado_consumacion TINYINT NOT NULL,
    id_modalidad_delito INT NOT NULL,

    id_entidad_federativa TINYINT NOT NULL,
    id_municipio INT NOT NULL,

    id_localidad_fiscalia VARCHAR(250) NULL,
    localidad_fiscalia_nombre VARCHAR(250) NULL,
    id_colonia_fiscalia VARCHAR(250) NULL,
    colonia_fiscalia_nombre VARCHAR(250) NULL,

    id_codigo_postal INT NULL,

    coordenada_x DECIMAL(10,6) NOT NULL,
    coordenada_y DECIMAL(10,6) NOT NULL,
    domicilio_hechos VARCHAR(MAX) NULL,

    id_usuario_registro INT NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_carga BIGINT NOT NULL,
    activo BIT NOT NULL DEFAULT 1,

    CONSTRAINT pk_delito
        PRIMARY KEY (id_delito),

    CONSTRAINT fk_delito_carpeta_investigacion
        FOREIGN KEY (id_carpeta_investigacion)
        REFERENCES carpeta_investigacion(id_carpeta_investigacion),

    CONSTRAINT fk_delito_forma_accion
        FOREIGN KEY (id_forma_accion)
        REFERENCES catalogo_forma_accion(id_forma_accion),

    CONSTRAINT fk_delito_instrumento_comision
        FOREIGN KEY (id_instrumento_comision)
        REFERENCES catalogo_instrumento_comision(id_instrumento_comision),

    CONSTRAINT fk_delito_grado_consumacion
        FOREIGN KEY (id_grado_consumacion)
        REFERENCES catalogo_grado_consumacion(id_grado_consumacion),

    CONSTRAINT fk_delito_modalidad_delito
        FOREIGN KEY (id_modalidad_delito)
        REFERENCES catalogo_modalidad_delito(id_modalidad_delito),

    CONSTRAINT fk_delito_entidad_federativa
        FOREIGN KEY (id_entidad_federativa)
        REFERENCES catalogo_entidad_federativa(id_entidad_federativa),

    CONSTRAINT fk_delito_municipio
        FOREIGN KEY (id_municipio)
        REFERENCES catalogo_municipio(id_municipio),

    CONSTRAINT fk_delito_codigo_postal
        FOREIGN KEY (id_codigo_postal)
        REFERENCES catalogo_codigo_postal(id_codigo_postal),

    CONSTRAINT fk_delito_usuario_registro
        FOREIGN KEY (id_usuario_registro)
        REFERENCES usuario(id_usuario),

    CONSTRAINT fk_delito_carga
        FOREIGN KEY (id_carga)
        REFERENCES carga(id_carga)
);
GO

CREATE TABLE delito_historico (
    id_delito_historico BIGINT IDENTITY(1,1) NOT NULL,
    id_delito BIGINT NOT NULL,
    id_carpeta_investigacion BIGINT NOT NULL,
    identificador_delito_fiscalia NVARCHAR(50) NOT NULL,
    delito_fiscalia VARCHAR(250) NOT NULL,
    modalidad_delito_fiscalia VARCHAR(250) NULL,
    id_forma_accion TINYINT NOT NULL,
    fecha_hechos DATETIME2 NOT NULL,
    id_instrumento_comision TINYINT NOT NULL,
    id_grado_consumacion TINYINT NOT NULL,
    id_modalidad_delito INT NOT NULL,
    id_entidad_federativa TINYINT NOT NULL,
    id_municipio INT NOT NULL,
    id_localidad_fiscalia NVARCHAR(50) NULL,
    localidad_fiscalia_nombre NVARCHAR(250) NULL,
    id_colonia_fiscalia NVARCHAR(50) NULL,
    colonia_fiscalia_nombre NVARCHAR(250) NULL,
    id_codigo_postal INT NULL,
    coordenada_x DECIMAL(10,6) NOT NULL,
    coordenada_y DECIMAL(10,6) NOT NULL,
    domicilio_hechos NVARCHAR(MAX) NULL,
    id_usuario_registro INT NOT NULL,
    fecha_registro DATETIME2 NOT NULL,
    id_carga BIGINT NOT NULL,
    id_usuario_modificacion INT NULL,
    id_carga_nueva BIGINT NOT NULL,
    tipo_movimiento NVARCHAR(20) NOT NULL
        CONSTRAINT DF_delito_historico_tipo_movimiento DEFAULT 'MODIFICADO',
    fecha_modificacion DATETIME2 NOT NULL
        CONSTRAINT DF_delito_historico_fecha_modificacion DEFAULT SYSDATETIME(),
    activo BIT NOT NULL
        CONSTRAINT DF_delito_historico_activo DEFAULT 1,

    CONSTRAINT PK_delito_historico
        PRIMARY KEY (id_delito_historico),

    CONSTRAINT FK_delito_historico_delito
        FOREIGN KEY (id_delito)
        REFERENCES delito(id_delito),

    CONSTRAINT FK_delito_historico_carpeta
        FOREIGN KEY (id_carpeta_investigacion)
        REFERENCES carpeta_investigacion(id_carpeta_investigacion),

    CONSTRAINT FK_delito_historico_forma_accion
        FOREIGN KEY (id_forma_accion)
        REFERENCES catalogo_forma_accion(id_forma_accion),

    CONSTRAINT FK_delito_historico_instrumento_comision
        FOREIGN KEY (id_instrumento_comision)
        REFERENCES catalogo_instrumento_comision(id_instrumento_comision),

    CONSTRAINT FK_delito_historico_grado_consumacion
        FOREIGN KEY (id_grado_consumacion)
        REFERENCES catalogo_grado_consumacion(id_grado_consumacion),

    CONSTRAINT FK_delito_historico_modalidad_delito
        FOREIGN KEY (id_modalidad_delito)
        REFERENCES catalogo_modalidad_delito(id_modalidad_delito),

    CONSTRAINT FK_delito_historico_entidad_federativa
        FOREIGN KEY (id_entidad_federativa)
        REFERENCES catalogo_entidad_federativa(id_entidad_federativa),

    CONSTRAINT FK_delito_historico_municipio
        FOREIGN KEY (id_municipio)
        REFERENCES catalogo_municipio(id_municipio),

    CONSTRAINT FK_delito_historico_codigo_postal
        FOREIGN KEY (id_codigo_postal)
        REFERENCES catalogo_codigo_postal(id_codigo_postal),

    CONSTRAINT FK_delito_historico_usuario_registro
        FOREIGN KEY (id_usuario_registro)
        REFERENCES usuario(id_usuario),

    CONSTRAINT FK_delito_historico_usuario_modificacion
        FOREIGN KEY (id_usuario_modificacion)
        REFERENCES usuario(id_usuario),

    CONSTRAINT FK_delito_historico_carga
        FOREIGN KEY (id_carga)
        REFERENCES carga(id_carga),

    CONSTRAINT FK_delito_historico_carga_nueva
        FOREIGN KEY (id_carga_nueva)
        REFERENCES carga(id_carga),

    CONSTRAINT CK_delito_historico_tipo_movimiento
        CHECK (tipo_movimiento IN ('MODIFICADO', 'ELIMINADO'))
);
GO

CREATE TABLE [victima] (
  id_victima BIGINT NOT NULL IDENTITY(1,1),
  id_delito BIGINT NOT NULL,
  identificador_victima_fiscalia NVARCHAR(50) NOT NULL,
  id_tipo_victima TINYINT NOT NULL,
  id_tipo_victima_moral TINYINT NULL,
  id_sexo TINYINT NULL,
  id_genero TINYINT NULL,
  id_nacionalidad INT NULL,
  id_pertenece_poblacion_indigena TINYINT NULL,
  id_presenta_discapacidad TINYINT NULL,
  fecha_nacimiento DATE NULL,
  edad TINYINT NULL,
  id_usuario_registro INT NOT NULL,
  fecha_registro DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
  id_carga BIGINT NOT NULL,
  activo BIT NOT NULL DEFAULT 1,
  CONSTRAINT [pk_victima] PRIMARY KEY (id_victima),
  CONSTRAINT [fk_victima_delito]
    FOREIGN KEY (id_delito) REFERENCES delito (id_delito),
  CONSTRAINT [fk_victima_tipo_victima]
    FOREIGN KEY (id_tipo_victima) REFERENCES catalogo_tipo_victima (id_tipo_victima),
  CONSTRAINT [fk_victima_tipo_victima_moral]
    FOREIGN KEY (id_tipo_victima_moral) REFERENCES catalogo_tipo_victima_moral (id_tipo_victima_moral),
  CONSTRAINT [fk_victima_sexo]
    FOREIGN KEY (id_sexo) REFERENCES catalogo_sexo (id_sexo),
  CONSTRAINT [fk_victima_genero]
    FOREIGN KEY (id_genero) REFERENCES catalogo_genero (id_genero),
  CONSTRAINT [fk_victima_nacionalidad]
    FOREIGN KEY (id_nacionalidad) REFERENCES catalogo_nacionalidad (id_nacionalidad),
  CONSTRAINT [fk_victima_poblacion_indigena]
    FOREIGN KEY (id_pertenece_poblacion_indigena) REFERENCES catalogo_pertenece_poblacion_indigena (id_pertenece_poblacion_indigena),
  CONSTRAINT [fk_victima_discapacidad]
    FOREIGN KEY (id_presenta_discapacidad) REFERENCES catalogo_presenta_discapacidad (id_presenta_discapacidad),
  CONSTRAINT [fk_victima_usuario_registro]
    FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario),
  CONSTRAINT [fk_victima_carga]
    FOREIGN KEY (id_carga) REFERENCES carga (id_carga)
);
GO

CREATE TABLE victima_historico (
    id_victima_historico BIGINT IDENTITY(1,1) NOT NULL,
    id_victima BIGINT NOT NULL,
    id_delito BIGINT NOT NULL,
    identificador_victima_fiscalia NVARCHAR(50) NOT NULL,
    id_tipo_victima TINYINT NOT NULL,
    id_tipo_victima_moral TINYINT NULL,
    id_sexo TINYINT NULL,
    id_genero TINYINT NULL,
    id_nacionalidad INT NULL,
    id_pertenece_poblacion_indigena TINYINT NULL,
    id_presenta_discapacidad TINYINT NULL,
    fecha_nacimiento DATE NULL,
    edad TINYINT NULL,
    id_usuario_registro INT NOT NULL,
    fecha_registro DATETIME2 NOT NULL,
    id_carga BIGINT NOT NULL,
    id_usuario_modificacion INT NULL,
    id_carga_nueva BIGINT NOT NULL,
    tipo_movimiento NVARCHAR(20) NOT NULL
        CONSTRAINT DF_victima_historico_tipo_movimiento DEFAULT 'MODIFICADO',
    fecha_modificacion DATETIME2 NOT NULL
        CONSTRAINT DF_victima_historico_fecha_modificacion DEFAULT SYSDATETIME(),
    activo BIT NOT NULL
        CONSTRAINT DF_victima_historico_activo DEFAULT 1,

    CONSTRAINT PK_victima_historico
        PRIMARY KEY (id_victima_historico),

    CONSTRAINT FK_victima_historico_victima
        FOREIGN KEY (id_victima)
        REFERENCES victima(id_victima),

    CONSTRAINT FK_victima_historico_delito
        FOREIGN KEY (id_delito)
        REFERENCES delito(id_delito),

    CONSTRAINT FK_victima_historico_tipo_victima
        FOREIGN KEY (id_tipo_victima)
        REFERENCES catalogo_tipo_victima(id_tipo_victima),

    CONSTRAINT FK_victima_historico_tipo_victima_moral
        FOREIGN KEY (id_tipo_victima_moral)
        REFERENCES catalogo_tipo_victima_moral(id_tipo_victima_moral),

    CONSTRAINT FK_victima_historico_sexo
        FOREIGN KEY (id_sexo)
        REFERENCES catalogo_sexo(id_sexo),

    CONSTRAINT FK_victima_historico_genero
        FOREIGN KEY (id_genero)
        REFERENCES catalogo_genero(id_genero),

    CONSTRAINT FK_victima_historico_nacionalidad
        FOREIGN KEY (id_nacionalidad)
        REFERENCES catalogo_nacionalidad(id_nacionalidad),

    CONSTRAINT FK_victima_historico_poblacion_indigena
        FOREIGN KEY (id_pertenece_poblacion_indigena)
        REFERENCES catalogo_pertenece_poblacion_indigena(id_pertenece_poblacion_indigena),

    CONSTRAINT FK_victima_historico_discapacidad
        FOREIGN KEY (id_presenta_discapacidad)
        REFERENCES catalogo_presenta_discapacidad(id_presenta_discapacidad),

    CONSTRAINT FK_victima_historico_usuario_registro
        FOREIGN KEY (id_usuario_registro)
        REFERENCES usuario(id_usuario),

    CONSTRAINT FK_victima_historico_usuario_modificacion
        FOREIGN KEY (id_usuario_modificacion)
        REFERENCES usuario(id_usuario),

    CONSTRAINT FK_victima_historico_carga
        FOREIGN KEY (id_carga)
        REFERENCES carga(id_carga),

    CONSTRAINT FK_victima_historico_carga_nueva
        FOREIGN KEY (id_carga_nueva)
        REFERENCES carga(id_carga),

    CONSTRAINT CK_victima_historico_tipo_movimiento
        CHECK (tipo_movimiento IN ('MODIFICADO', 'ELIMINADO'))
);
GO

-- Índices no únicos convertidos desde KEY de MySQL
CREATE INDEX [idx_catalogo_localidad_id_municipio] ON [catalogo_localidad] (id_municipio);
CREATE INDEX [idx_sabana_modalidad] ON [catalogo_delito_sabana] (id_modalidad_delito);
CREATE INDEX [idx_sabana_grado] ON [catalogo_delito_sabana] (id_grado_consumacion);
CREATE INDEX [idx_sabana_instrumento] ON [catalogo_delito_sabana] (id_instrumento_comision);
CREATE INDEX [idx_sabana_forma] ON [catalogo_delito_sabana] (id_forma_accion);
CREATE INDEX [idx_sabana_clave2] ON [catalogo_delito_sabana] (clave2_sabana);
CREATE INDEX [idx_sabana_clave3] ON [catalogo_delito_sabana] (clave3_sabana);
CREATE INDEX [idx_carga_usuario_carga] ON [carga] (id_usuario_carga);
CREATE INDEX [idx_carga_usuario_confirmacion] ON [carga] (id_usuario_confirmacion);
CREATE INDEX [idx_carga_codigo_referencia] ON [carga] (codigo_referencia);
CREATE INDEX [idx_carga_estado] ON [carga] (estado);
CREATE INDEX [idx_carga_tmp_carpeta_id_carga] ON [carga_tmp_carpeta] (id_carga);
CREATE INDEX [idx_carga_tmp_delito_id_carga] ON [carga_tmp_delito] (id_carga);
CREATE INDEX [idx_carga_tmp_delito_id_ci_id_delito] ON [carga_tmp_delito] (id_carga, id_ci, id_delito);
CREATE INDEX [idx_carga_tmp_victima_id_carga] ON [carga_tmp_victima] (id_carga);
CREATE INDEX [idx_carga_tmp_victima_id_ci_id_delito] ON [carga_tmp_victima] (id_carga, id_ci, id_delito);
CREATE INDEX [idx_delito_carpeta] ON [delito] (id_carpeta_investigacion);
CREATE INDEX [idx_delito_forma_accion] ON [delito] (id_forma_accion);
CREATE INDEX [idx_delito_instrumento] ON [delito] (id_instrumento_comision);
CREATE INDEX [idx_delito_grado_consumacion] ON [delito] (id_grado_consumacion);
CREATE INDEX [idx_delito_modalidad] ON [delito] (id_modalidad_delito);
CREATE INDEX [idx_delito_entidad_federativa] ON [delito] (id_entidad_federativa);
CREATE INDEX [idx_delito_municipio] ON [delito] (id_municipio);
CREATE INDEX [idx_delito_codigo_postal] ON [delito] (id_codigo_postal);
CREATE INDEX [idx_delito_usuario_registro] ON [delito] (id_usuario_registro);
CREATE INDEX [idx_delito_carga] ON [delito] (id_carga);
CREATE INDEX [idx_delito_historico_delito] ON [delito_historico] (id_delito);
CREATE INDEX [idx_delito_historico_carpeta] ON [delito_historico] (id_carpeta_investigacion);
CREATE INDEX [idx_delito_historico_forma_accion] ON [delito_historico] (id_forma_accion);
CREATE INDEX [idx_delito_historico_instrumento] ON [delito_historico] (id_instrumento_comision);
CREATE INDEX [idx_delito_historico_grado_consumacion] ON [delito_historico] (id_grado_consumacion);
CREATE INDEX [idx_delito_historico_modalidad] ON [delito_historico] (id_modalidad_delito);
CREATE INDEX [idx_delito_historico_entidad_federativa] ON [delito_historico] (id_entidad_federativa);
CREATE INDEX [idx_delito_historico_municipio] ON [delito_historico] (id_municipio);
CREATE INDEX [idx_delito_historico_codigo_postal] ON [delito_historico] (id_codigo_postal);
CREATE INDEX [idx_delito_historico_usuario_registro] ON [delito_historico] (id_usuario_registro);
CREATE INDEX [idx_delito_historico_carga] ON [delito_historico] (id_carga);
CREATE INDEX [idx_delito_historico_usuario_modificacion] ON [delito_historico] (id_usuario_modificacion);
CREATE INDEX [idx_delito_historico_carga_nueva] ON [delito_historico] (id_carga_nueva);