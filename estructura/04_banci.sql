-- Contrato mensual BANCI. Requiere catálogos compartidos y los particulares vigentes.
-- Para sustituir una instalación anterior usar desarrollo/11_banci_mensual_bloque1.sql.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
CREATE TABLE dbo.banci_carga(
 id_banci_carga BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
 codigo_referencia UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() UNIQUE,
 id_entidad_federativa TINYINT NOT NULL REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
 mes_corte TINYINT NOT NULL CHECK(mes_corte BETWEEN 1 AND 12), anio_corte SMALLINT NOT NULL,
 tipo_carga NVARCHAR(30) NOT NULL, estado NVARCHAR(40) NOT NULL,
 id_usuario_carga INT NOT NULL REFERENCES dbo.usuario(id_usuario),
 id_usuario_aprobacion INT NULL REFERENCES dbo.usuario(id_usuario),
 id_carga_consolidado BIGINT NULL REFERENCES dbo.carga(id_carga),
 es_historica BIT NOT NULL DEFAULT(0),
 snapshot_origen NVARCHAR(MAX) NULL CHECK(snapshot_origen IS NULL OR ISJSON(snapshot_origen)=1),
 huella_origen VARCHAR(64) NULL,
 fecha_validacion DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
 fecha_confirmacion DATETIME2(7) NULL, fecha_aprobacion DATETIME2(7) NULL,
 motivo_resolucion NVARCHAR(2000) NULL, activo BIT NOT NULL DEFAULT(1)
);
CREATE TABLE dbo.banci_carga_archivo(
 id_banci_carga_archivo BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 nombre_original NVARCHAR(260) NOT NULL, ruta_relativa NVARCHAR(1000) NOT NULL,
 huella_sha256 VARCHAR(64) NOT NULL, longitud_bytes BIGINT NOT NULL CHECK(longitud_bytes>=0),
 fecha_registro DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.banci_carga_bitacora_estado(
 id_banci_bitacora BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 estado_anterior NVARCHAR(40) NULL, estado_nuevo NVARCHAR(40) NOT NULL,
 id_usuario INT NOT NULL REFERENCES dbo.usuario(id_usuario),
 comentario NVARCHAR(2000) NULL, fecha_utc DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.banci_carga_observacion(
 id_banci_observacion BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 archivo NVARCHAR(30) NOT NULL, fila INT NULL, campo NVARCHAR(100) NULL,
 codigo NVARCHAR(100) NOT NULL, mensaje NVARCHAR(2000) NOT NULL, es_error BIT NOT NULL
);
CREATE TABLE dbo.banci_carga_tmp_carpeta(
 id_banci_tmp_carpeta BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 numero_fila INT NOT NULL CHECK(numero_fila>0),
 datos_origen NVARCHAR(MAX) NULL CHECK(datos_origen IS NULL OR ISJSON(datos_origen)=1),
 datos_propuestos NVARCHAR(MAX) NOT NULL CHECK(ISJSON(datos_propuestos)=1),
 UNIQUE(id_banci_carga,numero_fila)
);
CREATE TABLE dbo.banci_carga_tmp_delito(
 id_banci_tmp_delito BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 numero_fila INT NOT NULL CHECK(numero_fila>0),
 datos_origen NVARCHAR(MAX) NULL CHECK(datos_origen IS NULL OR ISJSON(datos_origen)=1),
 datos_propuestos NVARCHAR(MAX) NOT NULL CHECK(ISJSON(datos_propuestos)=1),
 UNIQUE(id_banci_carga,numero_fila)
);
CREATE TABLE dbo.banci_carga_tmp_victima(
 id_banci_tmp_victima BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 numero_fila INT NOT NULL CHECK(numero_fila>0),
 datos_origen NVARCHAR(MAX) NULL CHECK(datos_origen IS NULL OR ISJSON(datos_origen)=1),
 datos_propuestos NVARCHAR(MAX) NOT NULL CHECK(ISJSON(datos_propuestos)=1),
 UNIQUE(id_banci_carga,numero_fila)
);
CREATE TABLE dbo.banci_consecutivo_carpeta(
 id_entidad_federativa TINYINT NOT NULL REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
 anio SMALLINT NOT NULL, ultimo_consecutivo BIGINT NOT NULL CHECK(ultimo_consecutivo>=0),
 PRIMARY KEY(id_entidad_federativa,anio)
);
CREATE TABLE dbo.banci_carpeta_investigacion(
 id_banci_carpeta_investigacion BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 id_entidad_federativa TINYINT NOT NULL REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
 mes_corte TINYINT NOT NULL CHECK(mes_corte BETWEEN 1 AND 12), anio_corte SMALLINT NOT NULL,
 id_ci NVARCHAR(250) NOT NULL, ntra_ci NVARCHAR(250) NOT NULL,
 no_banci NVARCHAR(40) NOT NULL UNIQUE,
 fha_de_ini DATE NOT NULL, hra_de_ini TIME(0) NULL, rmen_de_hchos NVARCHAR(MAX) NULL,
 id_carpeta_consolidado BIGINT NULL,
 activo BIT NOT NULL DEFAULT(1),
 UNIQUE(id_entidad_federativa,id_ci,ntra_ci)
);
CREATE TABLE dbo.banci_delito(
 id_banci_delito BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carpeta_investigacion BIGINT NOT NULL REFERENCES dbo.banci_carpeta_investigacion(id_banci_carpeta_investigacion),
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 id_delito NVARCHAR(250) NOT NULL, dto NVARCHAR(2000) NULL, moda_dto NVARCHAR(2000) NULL,
 forma_acc TINYINT NULL REFERENCES dbo.catalogo_forma_accion(clave),
 fha_de_hchos DATE NULL, hra_de_hchos TIME(0) NULL,
 emto_com_dto TINYINT NULL REFERENCES dbo.catalogo_instrumento_comision(clave),
 grdo_cons TINYINT NULL REFERENCES dbo.catalogo_grado_consumacion(clave),
 clasf_de_dto NVARCHAR(20) NOT NULL,
 nom_ent_hchos NVARCHAR(250) NULL, id_ent_hchos TINYINT NULL REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
 nom_mun_hchos NVARCHAR(250) NULL, id_mun_hchos NVARCHAR(5) NULL,
 nom_loc_hchos NVARCHAR(250) NULL, id_loc_hchos NVARCHAR(250) NULL,
 nom_col_hchos NVARCHAR(250) NULL, id_col_hchos NVARCHAR(250) NULL,
 cp NVARCHAR(100) NULL, coord_x DECIMAL(18,10) NULL, coord_y DECIMAL(18,10) NULL, dom_hchos NVARCHAR(MAX) NULL,
 id_delito_consolidado BIGINT NULL, activo BIT NOT NULL DEFAULT(1),
 FOREIGN KEY(id_ent_hchos,id_mun_hchos) REFERENCES dbo.catalogo_municipio(id_entidad_federativa,clave),
 UNIQUE(id_banci_carpeta_investigacion,id_delito)
);
CREATE TABLE dbo.banci_victima(
 id_banci_victima BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_delito BIGINT NOT NULL REFERENCES dbo.banci_delito(id_banci_delito),
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 id_vicf NVARCHAR(250) NOT NULL,
 id_tv TINYINT NOT NULL REFERENCES dbo.catalogo_tipo_victima(clave),
 id_tpm TINYINT NULL REFERENCES dbo.catalogo_tipo_victima_moral(clave),
 sexo TINYINT NULL REFERENCES dbo.catalogo_sexo(clave), genero TINYINT NULL REFERENCES dbo.catalogo_genero(clave),
 pob TINYINT NULL REFERENCES dbo.catalogo_pertenece_poblacion_indigena(clave),
 disc TINYINT NULL REFERENCES dbo.catalogo_presenta_discapacidad(clave),
 fha_nac DATE NULL, edad INT NULL, nacional NVARCHAR(5) NULL REFERENCES dbo.catalogo_nacionalidad(clave),
 nombre_vicfem NVARCHAR(500) NULL, primer_apellido_vicfem NVARCHAR(250) NULL,
 segundo_apellido_vicfem NVARCHAR(250) NULL, curp_vicfem NVARCHAR(250) NULL,
 fub NVARCHAR(250) NULL, pro_apellido NVARCHAR(250) NULL, sdo_apellido NVARCHAR(250) NULL, nomb NVARCHAR(500) NULL,
 entidad_nacimiento NVARCHAR(250) NULL, estado_migratorio NVARCHAR(500) NULL, curp NVARCHAR(18) NULL, rfc NVARCHAR(13) NULL,
 localizado_o_no_localizado TINYINT NULL REFERENCES dbo.banci_catalogo_localizacion(clave),
 con_o_sin_vida TINYINT NULL REFERENCES dbo.banci_catalogo_condicion_vida(clave), fecha_localizacion DATE NULL,
 constitutiva_delito TINYINT NULL REFERENCES dbo.banci_catalogo_constitutiva_delito(clave),
 motivo_desaparicion NVARCHAR(1000) NULL, acciones_busqueda NVARCHAR(MAX) NULL, obs NVARCHAR(MAX) NULL,
 id_victima_consolidado BIGINT NULL, activo BIT NOT NULL DEFAULT(1), reclasificada BIT NOT NULL DEFAULT(0),
 UNIQUE(id_banci_delito,id_vicf)
);
CREATE TABLE dbo.banci_historial_cambio(
 id_banci_historial_cambio BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 tipo_registro NVARCHAR(30) NOT NULL, identificador_registro BIGINT NOT NULL,
 campo NVARCHAR(100) NOT NULL, valor_anterior NVARCHAR(MAX) NULL, valor_nuevo NVARCHAR(MAX) NULL,
 id_usuario INT NOT NULL REFERENCES dbo.usuario(id_usuario), fecha_utc DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.banci_reclasificado(
 id_banci_reclasificado BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_banci_victima BIGINT NULL REFERENCES dbo.banci_victima(id_banci_victima),
 es_reclasificacion BIT NOT NULL DEFAULT(1),
 id_banci_delito BIGINT NOT NULL REFERENCES dbo.banci_delito(id_banci_delito),
 id_banci_carga BIGINT NOT NULL REFERENCES dbo.banci_carga(id_banci_carga),
 constitutiva_delito TINYINT NOT NULL REFERENCES dbo.banci_catalogo_constitutiva_delito(clave),
 motivo NVARCHAR(1000) NOT NULL,
 snapshot_previo NVARCHAR(MAX) NOT NULL CHECK(ISJSON(snapshot_previo)=1),
 fecha_utc DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
 id_usuario INT NOT NULL REFERENCES dbo.usuario(id_usuario)
);
CREATE TABLE dbo.banci_operacion_vinculada(
 id_banci_operacion_vinculada BIGINT IDENTITY(1,1) PRIMARY KEY,
 id_carga_consolidado BIGINT NOT NULL UNIQUE REFERENCES dbo.carga(id_carga),
 id_banci_carga BIGINT NOT NULL UNIQUE REFERENCES dbo.banci_carga(id_banci_carga),
 huella_origen VARCHAR(64) NOT NULL, fecha_utc DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE INDEX IX_banci_carga_periodo ON dbo.banci_carga(id_entidad_federativa,anio_corte,mes_corte,estado);
CREATE INDEX IX_banci_carpeta_corte ON dbo.banci_carpeta_investigacion(id_entidad_federativa,anio_corte,mes_corte,activo);
CREATE INDEX IX_banci_delito_carga ON dbo.banci_delito(id_banci_carga);
CREATE INDEX IX_banci_victima_carga ON dbo.banci_victima(id_banci_carga);
CREATE INDEX IX_banci_reclasificado_victima ON dbo.banci_reclasificado(id_banci_victima,fecha_utc);
CREATE INDEX IX_banci_reclasificado_delito ON dbo.banci_reclasificado(id_banci_delito);

COMMIT;
