CREATE DATABASE IF NOT EXISTS siiid2
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE siiid2;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE roles (
  id_rol INT NOT NULL AUTO_INCREMENT,
  rol VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_rol),
  UNIQUE KEY uk_roles_rol (rol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_asentamiento (
  id_asentamiento INT NOT NULL,
  descripcion VARCHAR(100) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_asentamiento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_oficina (
  id_oficina INT NOT NULL,
  clave VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_oficina),
  UNIQUE KEY uk_catalogo_oficina_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_tipo_asentamiento (
  id_tipo_asentamiento TINYINT NOT NULL,
  clave VARCHAR(5) NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_tipo_asentamiento),
  UNIQUE KEY uk_catalogo_tipo_asentamiento_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_tipo_zona (
  id_tipo_zona TINYINT NOT NULL,
  descripcion VARCHAR(15) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_tipo_zona)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_ciudad (
  id_ciudad INT NOT NULL,
  clave VARCHAR(5) NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_ciudad),
  UNIQUE KEY uk_catalogo_ciudad_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_entidad_federativa (
  id_entidad_federativa TINYINT NOT NULL,
  clave VARCHAR(3) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  siglas VARCHAR(10) NOT NULL,
  siglas_renapo VARCHAR(10) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_entidad_federativa),
  UNIQUE KEY uk_catalogo_entidad_federativa_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_municipio (
  id_municipio INT NOT NULL,
  id_entidad_federativa TINYINT NOT NULL,
  clave VARCHAR(5) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_municipio),
  UNIQUE KEY uk_catalogo_municipio_entidad_clave (id_entidad_federativa, clave),
  CONSTRAINT fk_catalogo_municipio_entidad
    FOREIGN KEY (id_entidad_federativa) REFERENCES catalogo_entidad_federativa (id_entidad_federativa)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_localidad (
  id_localidad INT NOT NULL,
  id_municipio INT NOT NULL,
  clave VARCHAR(5) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  id_tipo_zona TINYINT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_localidad),
  UNIQUE KEY uk_catalogo_localidad_municipio_clave (id_municipio, clave),
  CONSTRAINT fk_catalogo_localidad_municipio
    FOREIGN KEY (id_municipio) REFERENCES catalogo_municipio (id_municipio),
  CONSTRAINT fk_catalogo_localidad_tipo_zona
    FOREIGN KEY (id_tipo_zona) REFERENCES catalogo_tipo_zona (id_tipo_zona)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_codigo_postal (
  id_codigo_postal INT NOT NULL,
  codigo_postal VARCHAR(5) NOT NULL,
  clave_asentamiento_cp_consecutivo VARCHAR(5) NULL,
  id_asentamiento INT NOT NULL,
  id_oficina INT NOT NULL,
  id_tipo_asentamiento TINYINT NOT NULL,
  id_municipio INT NOT NULL,
  id_tipo_zona TINYINT NULL,
  id_ciudad INT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_codigo_postal),
  CONSTRAINT fk_catalogo_codigo_postal_asentamiento
    FOREIGN KEY (id_asentamiento) REFERENCES catalogo_asentamiento (id_asentamiento),
  CONSTRAINT fk_catalogo_codigo_postal_oficina
    FOREIGN KEY (id_oficina) REFERENCES catalogo_oficina (id_oficina),
  CONSTRAINT fk_catalogo_codigo_postal_tipo_asentamiento
    FOREIGN KEY (id_tipo_asentamiento) REFERENCES catalogo_tipo_asentamiento (id_tipo_asentamiento),
  CONSTRAINT fk_catalogo_codigo_postal_municipio
    FOREIGN KEY (id_municipio) REFERENCES catalogo_municipio (id_municipio),
  CONSTRAINT fk_catalogo_codigo_postal_tipo_zona
    FOREIGN KEY (id_tipo_zona) REFERENCES catalogo_tipo_zona (id_tipo_zona),
  CONSTRAINT fk_catalogo_codigo_postal_ciudad
    FOREIGN KEY (id_ciudad) REFERENCES catalogo_ciudad (id_ciudad)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_bien_juridico (
  id_bien_juridico INT NOT NULL,
  clave1 VARCHAR(10) NOT NULL,
  bien_juridico VARCHAR(200) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_bien_juridico),
  UNIQUE KEY uk_catalogo_bien_juridico_clave1 (clave1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_delito (
  id_delito INT NOT NULL,
  id_bien_juridico INT NOT NULL,
  clave2 VARCHAR(10) NOT NULL,
  delito VARCHAR(200) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_delito),
  CONSTRAINT fk_catalogo_delito_bien_juridico
    FOREIGN KEY (id_bien_juridico) REFERENCES catalogo_bien_juridico (id_bien_juridico)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_subtipo_delito (
  id_subtipo_delito INT NOT NULL,
  id_delito INT NOT NULL,
  clave3 VARCHAR(20) NOT NULL,
  subtipo_delito VARCHAR(200) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_subtipo_delito),
  CONSTRAINT fk_catalogo_subtipo_delito_delito
    FOREIGN KEY (id_delito) REFERENCES catalogo_delito (id_delito)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_admite_tentativa (
  id_admite_tentativa TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(100) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_admite_tentativa),
  UNIQUE KEY uk_catalogo_admite_tentativa_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_modalidad_delito (
  id_modalidad_delito INT NOT NULL,
  id_subtipo_delito INT NOT NULL,
  clave4 VARCHAR(20) NOT NULL,
  modalidad_delito VARCHAR(250) NOT NULL,
  id_admite_tentativa TINYINT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_modalidad_delito),
  CONSTRAINT fk_catalogo_modalidad_delito_subtipo
    FOREIGN KEY (id_subtipo_delito) REFERENCES catalogo_subtipo_delito (id_subtipo_delito),
  CONSTRAINT fk_catalogo_modalidad_delito_admite_tentativa
    FOREIGN KEY (id_admite_tentativa) REFERENCES catalogo_admite_tentativa (id_admite_tentativa)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_grado_consumacion (
  id_grado_consumacion TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_grado_consumacion),
  UNIQUE KEY uk_catalogo_grado_consumacion_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_forma_accion (
  id_forma_accion TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_forma_accion),
  UNIQUE KEY uk_catalogo_forma_accion_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_instrumento_comision (
  id_instrumento_comision TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_instrumento_comision),
  UNIQUE KEY uk_catalogo_instrumento_comision_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_delito_sabana (
  id_delito_sabana INT NOT NULL,
  id_modalidad_delito INT NOT NULL,
  id_grado_consumacion TINYINT NOT NULL,
  id_instrumento_comision TINYINT NOT NULL,
  id_forma_accion TINYINT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_delito_sabana),
  UNIQUE KEY uk_catalogo_delito_sabana_combinacion (
    id_modalidad_delito,
    id_grado_consumacion,
    id_instrumento_comision,
    id_forma_accion
  ),
  CONSTRAINT fk_catalogo_delito_sabana_modalidad
    FOREIGN KEY (id_modalidad_delito) REFERENCES catalogo_modalidad_delito (id_modalidad_delito),
  CONSTRAINT fk_catalogo_delito_sabana_grado
    FOREIGN KEY (id_grado_consumacion) REFERENCES catalogo_grado_consumacion (id_grado_consumacion),
  CONSTRAINT fk_catalogo_delito_sabana_instrumento
    FOREIGN KEY (id_instrumento_comision) REFERENCES catalogo_instrumento_comision (id_instrumento_comision),
  CONSTRAINT fk_catalogo_delito_sabana_forma
    FOREIGN KEY (id_forma_accion) REFERENCES catalogo_forma_accion (id_forma_accion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_tipo_expediente (
  id_tipo_expediente TINYINT NOT NULL,
  descripcion VARCHAR(25) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_tipo_expediente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_tipo_relacion (
  id_tipo_relacion TINYINT NOT NULL,
  clave VARCHAR(5) NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_tipo_relacion),
  UNIQUE KEY uk_catalogo_tipo_relacion_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_nacionalidad (
  id_nacionalidad TINYINT NOT NULL,
  clave VARCHAR(5) NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_nacionalidad),
  UNIQUE KEY uk_catalogo_nacionalidad_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_genero (
  id_genero TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_genero),
  UNIQUE KEY uk_catalogo_genero_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_sexo (
  id_sexo TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_sexo),
  UNIQUE KEY uk_catalogo_sexo_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_pertenece_poblacion_indigena (
  id_pertenece_poblacion_indigena TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_pertenece_poblacion_indigena),
  UNIQUE KEY uk_catalogo_pertenece_poblacion_indigena_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_presenta_discapacidad (
  id_presenta_discapacidad TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_presenta_discapacidad),
  UNIQUE KEY uk_catalogo_presenta_discapacidad_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_tipo_victima (
  id_tipo_victima TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_tipo_victima),
  UNIQUE KEY uk_catalogo_tipo_victima_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE catalogo_tipo_victima_moral (
  id_tipo_victima_moral TINYINT NOT NULL,
  clave TINYINT NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_tipo_victima_moral),
  UNIQUE KEY uk_catalogo_tipo_victima_moral_clave (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usuario (
  id_usuario INT NOT NULL AUTO_INCREMENT,
  usuario VARCHAR(50) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  primer_apellido VARCHAR(50) NOT NULL,
  segundo_apellido VARCHAR(50) NULL,
  correo_electronico VARCHAR(100) NOT NULL,
  rfc VARCHAR(13) NOT NULL,
  curp VARCHAR(18) NOT NULL,
  telefono_contacto VARCHAR(15) NULL,
  id_entidad_federativa TINYINT NULL,
  fecha_alta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  id_usuario_alta INT NULL,
  id_usuario_modificacion INT NULL,
  id_rol INT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_usuario),
  UNIQUE KEY uk_usuario_usuario (usuario),
  UNIQUE KEY uk_usuario_correo (correo_electronico),
  UNIQUE KEY uk_usuario_rfc (rfc),
  UNIQUE KEY uk_usuario_curp (curp),
  CONSTRAINT fk_usuario_entidad
    FOREIGN KEY (id_entidad_federativa) REFERENCES catalogo_entidad_federativa (id_entidad_federativa),
  CONSTRAINT fk_usuario_usuario_alta
    FOREIGN KEY (id_usuario_alta) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_usuario_usuario_modificacion
    FOREIGN KEY (id_usuario_modificacion) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_usuario_rol
    FOREIGN KEY (id_rol) REFERENCES roles (id_rol)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE carga (
  id_carga BIGINT NOT NULL AUTO_INCREMENT,
  id_usuario_carga INT NOT NULL,
  codigo_referencia VARCHAR(50) NOT NULL,
  mes_corte TINYINT NOT NULL,
  anio_corte SMALLINT NOT NULL,
  fecha_carga DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  total_carpetas_investigacion INT NOT NULL,
  total_delitos INT NOT NULL,
  total_victimas INT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_carga),
  UNIQUE KEY uk_carga_codigo_referencia (codigo_referencia),
  CONSTRAINT fk_carga_usuario
    FOREIGN KEY (id_usuario_carga) REFERENCES usuario (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE habilita_carga_modificacion (
  id_habilita_carga_modificacion INT NOT NULL AUTO_INCREMENT,
  habilita_carga BOOLEAN NOT NULL DEFAULT FALSE,
  habilita_modificacion BOOLEAN NOT NULL DEFAULT FALSE,
  id_usuario INT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_habilita_carga_modificacion),
  UNIQUE KEY uk_habilita_carga_modificacion_usuario (id_usuario),
  CONSTRAINT fk_habilita_carga_modificacion_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE carpeta_investigacion (
  id_carpeta_investigacion BIGINT NOT NULL AUTO_INCREMENT,
  identificador_carpeta_fiscalia VARCHAR(50) NOT NULL,
  nomenclatura_carpeta_fiscalia VARCHAR(50) NOT NULL,
  fecha_inicio DATETIME NOT NULL,
  resumen_hechos TEXT NULL,
  id_usuario_registro INT NOT NULL,
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_carga BIGINT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_carpeta_investigacion),
  CONSTRAINT fk_carpeta_investigacion_usuario_registro
    FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_carpeta_investigacion_carga
    FOREIGN KEY (id_carga) REFERENCES carga (id_carga)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE carpeta_investigacion_historico (
  id_carpeta_investigacion_historico BIGINT NOT NULL AUTO_INCREMENT,
  id_carpeta_investigacion BIGINT NOT NULL,
  identificador_carpeta_fiscalia VARCHAR(50) NOT NULL,
  nomenclatura_carpeta_fiscalia VARCHAR(50) NOT NULL,
  fecha_inicio DATETIME NOT NULL,
  resumen_hechos TEXT NULL,
  id_usuario_registro INT NOT NULL,
  fecha_registro DATETIME NOT NULL,
  id_carga BIGINT NOT NULL,
  id_usuario_modificacion INT NULL,
  id_carga_nueva BIGINT NOT NULL,
  fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_carpeta_investigacion_historico),
  CONSTRAINT fk_carpeta_investigacion_historico_carpeta
    FOREIGN KEY (id_carpeta_investigacion) REFERENCES carpeta_investigacion (id_carpeta_investigacion),
  CONSTRAINT fk_carpeta_investigacion_historico_usuario_registro
    FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_carpeta_investigacion_historico_carga
    FOREIGN KEY (id_carga) REFERENCES carga (id_carga),
  CONSTRAINT fk_carpeta_investigacion_historico_usuario_modificacion
    FOREIGN KEY (id_usuario_modificacion) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_carpeta_investigacion_historico_carga_nueva
    FOREIGN KEY (id_carga_nueva) REFERENCES carga (id_carga)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE delito (
  id_delito BIGINT NOT NULL AUTO_INCREMENT,
  id_carpeta_investigacion BIGINT NOT NULL,
  identificador_delito_carpeta_fiscalia VARCHAR(50) NOT NULL,
  id_modalidad_delito INT NOT NULL,
  id_forma_accion TINYINT NOT NULL,
  fecha_hechos DATETIME NOT NULL,
  id_instrumento_comision TINYINT NOT NULL,
  id_grado_consumacion TINYINT NOT NULL,
  id_localidad INT NOT NULL,
  id_codigo_postal INT NOT NULL,
  coordenada_x DECIMAL(10,6) NOT NULL,
  coordenada_y DECIMAL(10,6) NOT NULL,
  domicilio_hechos TEXT NULL,
  id_usuario_registro INT NOT NULL,
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_carga BIGINT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_delito),
  CONSTRAINT fk_delito_carpeta
    FOREIGN KEY (id_carpeta_investigacion) REFERENCES carpeta_investigacion (id_carpeta_investigacion),
  CONSTRAINT fk_delito_modalidad
    FOREIGN KEY (id_modalidad_delito) REFERENCES catalogo_modalidad_delito (id_modalidad_delito),
  CONSTRAINT fk_delito_forma_accion
    FOREIGN KEY (id_forma_accion) REFERENCES catalogo_forma_accion (id_forma_accion),
  CONSTRAINT fk_delito_instrumento
    FOREIGN KEY (id_instrumento_comision) REFERENCES catalogo_instrumento_comision (id_instrumento_comision),
  CONSTRAINT fk_delito_grado
    FOREIGN KEY (id_grado_consumacion) REFERENCES catalogo_grado_consumacion (id_grado_consumacion),
  CONSTRAINT fk_delito_localidad
    FOREIGN KEY (id_localidad) REFERENCES catalogo_localidad (id_localidad),
  CONSTRAINT fk_delito_codigo_postal
    FOREIGN KEY (id_codigo_postal) REFERENCES catalogo_codigo_postal (id_codigo_postal),
  CONSTRAINT fk_delito_usuario_registro
    FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_delito_carga
    FOREIGN KEY (id_carga) REFERENCES carga (id_carga)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE delito_historico (
  id_delito_historico BIGINT NOT NULL AUTO_INCREMENT,
  id_delito BIGINT NOT NULL,
  id_carpeta_investigacion BIGINT NOT NULL,
  identificador_delito_carpeta_fiscalia VARCHAR(50) NOT NULL,
  id_modalidad_delito INT NOT NULL,
  id_forma_accion TINYINT NOT NULL,
  fecha_hechos DATETIME NOT NULL,
  id_instrumento_comision TINYINT NOT NULL,
  id_grado_consumacion TINYINT NOT NULL,
  id_localidad INT NOT NULL,
  id_codigo_postal INT NOT NULL,
  coordenada_x DECIMAL(10,6) NOT NULL,
  coordenada_y DECIMAL(10,6) NOT NULL,
  domicilio_hechos TEXT NULL,
  id_usuario_registro INT NOT NULL,
  fecha_registro DATETIME NOT NULL,
  id_carga BIGINT NOT NULL,
  id_usuario_modificacion INT NULL,
  id_carga_nueva BIGINT NOT NULL,
  fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_delito_historico),
  CONSTRAINT fk_delito_historico_delito
    FOREIGN KEY (id_delito) REFERENCES delito (id_delito),
  CONSTRAINT fk_delito_historico_carpeta
    FOREIGN KEY (id_carpeta_investigacion) REFERENCES carpeta_investigacion (id_carpeta_investigacion),
  CONSTRAINT fk_delito_historico_modalidad
    FOREIGN KEY (id_modalidad_delito) REFERENCES catalogo_modalidad_delito (id_modalidad_delito),
  CONSTRAINT fk_delito_historico_forma_accion
    FOREIGN KEY (id_forma_accion) REFERENCES catalogo_forma_accion (id_forma_accion),
  CONSTRAINT fk_delito_historico_instrumento
    FOREIGN KEY (id_instrumento_comision) REFERENCES catalogo_instrumento_comision (id_instrumento_comision),
  CONSTRAINT fk_delito_historico_grado
    FOREIGN KEY (id_grado_consumacion) REFERENCES catalogo_grado_consumacion (id_grado_consumacion),
  CONSTRAINT fk_delito_historico_localidad
    FOREIGN KEY (id_localidad) REFERENCES catalogo_localidad (id_localidad),
  CONSTRAINT fk_delito_historico_codigo_postal
    FOREIGN KEY (id_codigo_postal) REFERENCES catalogo_codigo_postal (id_codigo_postal),
  CONSTRAINT fk_delito_historico_usuario_registro
    FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_delito_historico_carga
    FOREIGN KEY (id_carga) REFERENCES carga (id_carga),
  CONSTRAINT fk_delito_historico_usuario_modificacion
    FOREIGN KEY (id_usuario_modificacion) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_delito_historico_carga_nueva
    FOREIGN KEY (id_carga_nueva) REFERENCES carga (id_carga)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE victima (
  id_victima BIGINT NOT NULL AUTO_INCREMENT,
  id_delito BIGINT NOT NULL,
  identificador_victima_fiscalia VARCHAR(50) NOT NULL,
  id_tipo_victima TINYINT NOT NULL,
  id_tipo_victima_moral TINYINT NULL,
  id_sexo TINYINT NULL,
  id_genero TINYINT NULL,
  id_nacionalidad TINYINT NULL,
  id_pertenece_poblacion_indigena TINYINT NULL,
  id_presenta_discapacidad TINYINT NULL,
  fecha_nacimiento DATE NULL,
  edad TINYINT NULL,
  id_usuario_registro INT NOT NULL,
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_carga BIGINT NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_victima),
  CONSTRAINT fk_victima_delito
    FOREIGN KEY (id_delito) REFERENCES delito (id_delito),
  CONSTRAINT fk_victima_tipo_victima
    FOREIGN KEY (id_tipo_victima) REFERENCES catalogo_tipo_victima (id_tipo_victima),
  CONSTRAINT fk_victima_tipo_victima_moral
    FOREIGN KEY (id_tipo_victima_moral) REFERENCES catalogo_tipo_victima_moral (id_tipo_victima_moral),
  CONSTRAINT fk_victima_sexo
    FOREIGN KEY (id_sexo) REFERENCES catalogo_sexo (id_sexo),
  CONSTRAINT fk_victima_genero
    FOREIGN KEY (id_genero) REFERENCES catalogo_genero (id_genero),
  CONSTRAINT fk_victima_nacionalidad
    FOREIGN KEY (id_nacionalidad) REFERENCES catalogo_nacionalidad (id_nacionalidad),
  CONSTRAINT fk_victima_poblacion_indigena
    FOREIGN KEY (id_pertenece_poblacion_indigena) REFERENCES catalogo_pertenece_poblacion_indigena (id_pertenece_poblacion_indigena),
  CONSTRAINT fk_victima_discapacidad
    FOREIGN KEY (id_presenta_discapacidad) REFERENCES catalogo_presenta_discapacidad (id_presenta_discapacidad),
  CONSTRAINT fk_victima_usuario_registro
    FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_victima_carga
    FOREIGN KEY (id_carga) REFERENCES carga (id_carga)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE victima_historico (
  id_victima_historico BIGINT NOT NULL AUTO_INCREMENT,
  id_victima BIGINT NOT NULL,
  id_delito BIGINT NOT NULL,
  identificador_victima_fiscalia VARCHAR(50) NOT NULL,
  id_tipo_victima TINYINT NOT NULL,
  id_tipo_victima_moral TINYINT NULL,
  id_sexo TINYINT NULL,
  id_genero TINYINT NULL,
  id_nacionalidad TINYINT NULL,
  id_pertenece_poblacion_indigena TINYINT NULL,
  id_presenta_discapacidad TINYINT NULL,
  fecha_nacimiento DATE NULL,
  edad TINYINT NULL,
  id_usuario_registro INT NOT NULL,
  fecha_registro DATETIME NOT NULL,
  id_carga BIGINT NOT NULL,
  id_usuario_modificacion INT NULL,
  id_carga_nueva BIGINT NOT NULL,
  fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id_victima_historico),
  CONSTRAINT fk_victima_historico_victima
    FOREIGN KEY (id_victima) REFERENCES victima (id_victima),
  CONSTRAINT fk_victima_historico_delito
    FOREIGN KEY (id_delito) REFERENCES delito (id_delito),
  CONSTRAINT fk_victima_historico_tipo_victima
    FOREIGN KEY (id_tipo_victima) REFERENCES catalogo_tipo_victima (id_tipo_victima),
  CONSTRAINT fk_victima_historico_tipo_victima_moral
    FOREIGN KEY (id_tipo_victima_moral) REFERENCES catalogo_tipo_victima_moral (id_tipo_victima_moral),
  CONSTRAINT fk_victima_historico_sexo
    FOREIGN KEY (id_sexo) REFERENCES catalogo_sexo (id_sexo),
  CONSTRAINT fk_victima_historico_genero
    FOREIGN KEY (id_genero) REFERENCES catalogo_genero (id_genero),
  CONSTRAINT fk_victima_historico_nacionalidad
    FOREIGN KEY (id_nacionalidad) REFERENCES catalogo_nacionalidad (id_nacionalidad),
  CONSTRAINT fk_victima_historico_poblacion_indigena
    FOREIGN KEY (id_pertenece_poblacion_indigena) REFERENCES catalogo_pertenece_poblacion_indigena (id_pertenece_poblacion_indigena),
  CONSTRAINT fk_victima_historico_discapacidad
    FOREIGN KEY (id_presenta_discapacidad) REFERENCES catalogo_presenta_discapacidad (id_presenta_discapacidad),
  CONSTRAINT fk_victima_historico_usuario_registro
    FOREIGN KEY (id_usuario_registro) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_victima_historico_carga
    FOREIGN KEY (id_carga) REFERENCES carga (id_carga),
  CONSTRAINT fk_victima_historico_usuario_modificacion
    FOREIGN KEY (id_usuario_modificacion) REFERENCES usuario (id_usuario),
  CONSTRAINT fk_victima_historico_carga_nueva
    FOREIGN KEY (id_carga_nueva) REFERENCES carga (id_carga)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
