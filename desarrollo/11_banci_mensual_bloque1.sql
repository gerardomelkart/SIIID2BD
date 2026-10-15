-- BLOQUE 1: sustituir exclusivamente el modelo de pruebas BANCI.
-- Publicar con la API/Front del bloque 1, primero en desarrollo/QA.
-- Detener la API correspondiente mientras se ejecuta. No ejecutar versiones antiguas de desarrollo/.
-- No procesa mensual, semanal ni federal, ni elimina usuarios/catálogos compartidos.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF DB_NAME() IN (N'master',N'model',N'msdb',N'tempdb') THROW 52910,'Seleccione la base SIIID2 correspondiente.',1;
IF @@TRANCOUNT<>0 THROW 52910,'Ejecute sin transacción abierta.',1;
IF COL_LENGTH(N'dbo.banci_carga',N'mes_corte') IS NOT NULL
BEGIN
    IF EXISTS(SELECT 1 FROM(VALUES (N'banci_carga'),(N'banci_carga_archivo'),(N'banci_carga_bitacora_estado'),(N'banci_carga_observacion'),(N'banci_carga_tmp_carpeta'),(N'banci_carga_tmp_delito'),(N'banci_carga_tmp_victima'),(N'banci_consecutivo_carpeta'),(N'banci_carpeta_investigacion'),(N'banci_delito'),(N'banci_victima'),(N'banci_historial_cambio'),(N'banci_reclasificado'),(N'banci_operacion_vinculada'))v(nombre) WHERE OBJECT_ID(N'dbo.'+v.nombre,N'U') IS NULL)
        OR EXISTS(SELECT 1 FROM(VALUES (N'sp_banci_confirmar_carga_v2'),(N'sp_banci_procesar_carga'),(N'sp_banci_vista_previa_v2'),(N'sp_banci_vista_previa'),(N'banci_vw_victimas_v2'),(N'sp_banci_confirmar_carga'),(N'sp_banci_confirmar_actualizacion_v2'),(N'sp_banci_calcular_actualizacion_v2'),(N'sp_banci_vista_previa_actualizacion_v2'),(N'sp_banci_asignar_folios_v2'),(N'sp_banci_procesar_carga_v2'),(N'sp_banci_buscar_victimas_v2'),(N'sp_banci_preparar_actualizacion_v2'),(N'fn_banci_es_usuario_federal'),(N'fn_banci_puede_actualizar_victima'),(N'banci_cruce_federal'),(N'banci_cruce_mensual'),(N'banci_actualizacion_v2'),(N'banci_catalogo_voluntaria'),(N'banci_catalogo_fue_delito'),(N'banci_catalogo_motivo_localizacion'))v(nombre) WHERE OBJECT_ID(N'dbo.'+v.nombre) IS NOT NULL)
        THROW 52910,'Instalación mensual parcial: revisar antes de continuar.',1;
    SELECT N'El bloque 1 ya está instalado; no se borró información.' AS resultado;
    RETURN;
END;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @Lock INT;
EXEC @Lock=sys.sp_getapplock @Resource=N'SIIID2:CONFIGURACION',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000;
IF @Lock<0 THROW 52910,'No se pudo bloquear la configuración.',1;
IF OBJECT_ID(N'dbo.banci_historial_cambio',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_historial_cambio) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_actualizacion_v2',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_actualizacion_v2) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_victima',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_victima) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_delito',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_delito) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_carpeta_investigacion',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_carpeta_investigacion) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_carga_tmp_victima',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_carga_tmp_victima) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_carga_tmp_delito',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_carga_tmp_delito) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_carga_tmp_carpeta',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_carga_tmp_carpeta) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_carga_observacion',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_carga_observacion) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_carga_archivo',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_carga_archivo) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_carga_bitacora_estado',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_carga_bitacora_estado) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_carga',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_carga) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
IF OBJECT_ID(N'dbo.banci_consecutivo_carpeta',N'U') IS NOT NULL EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_consecutivo_carpeta) THROW 52911, ''Hay datos BANCI posteriores al inventario. Revise y retire las pruebas antes de sustituir.'',1;');
DECLARE @Retirar TABLE(id INT PRIMARY KEY);
INSERT @Retirar SELECT DISTINCT id FROM (VALUES (OBJECT_ID(N'dbo.banci_cruce_federal')),(OBJECT_ID(N'dbo.banci_cruce_mensual')),(OBJECT_ID(N'dbo.banci_historial_cambio')),(OBJECT_ID(N'dbo.banci_actualizacion_v2')),(OBJECT_ID(N'dbo.banci_victima')),(OBJECT_ID(N'dbo.banci_delito')),(OBJECT_ID(N'dbo.banci_carpeta_investigacion')),(OBJECT_ID(N'dbo.banci_carga_tmp_victima')),(OBJECT_ID(N'dbo.banci_carga_tmp_delito')),(OBJECT_ID(N'dbo.banci_carga_tmp_carpeta')),(OBJECT_ID(N'dbo.banci_carga_observacion')),(OBJECT_ID(N'dbo.banci_carga_archivo')),(OBJECT_ID(N'dbo.banci_carga_bitacora_estado')),(OBJECT_ID(N'dbo.banci_carga')),(OBJECT_ID(N'dbo.banci_consecutivo_carpeta')),(OBJECT_ID(N'dbo.banci_catalogo_voluntaria')),(OBJECT_ID(N'dbo.banci_catalogo_fue_delito')),(OBJECT_ID(N'dbo.banci_catalogo_motivo_localizacion')),(OBJECT_ID(N'dbo.sp_banci_confirmar_carga_v2')),(OBJECT_ID(N'dbo.sp_banci_procesar_carga')),(OBJECT_ID(N'dbo.fn_banci_es_usuario_federal')),(OBJECT_ID(N'dbo.sp_banci_vista_previa_v2')),(OBJECT_ID(N'dbo.sp_banci_vista_previa')),(OBJECT_ID(N'dbo.banci_vw_victimas_v2')),(OBJECT_ID(N'dbo.sp_banci_confirmar_carga')),(OBJECT_ID(N'dbo.fn_banci_puede_actualizar_victima')),(OBJECT_ID(N'dbo.sp_banci_confirmar_actualizacion_v2')),(OBJECT_ID(N'dbo.sp_banci_calcular_actualizacion_v2')),(OBJECT_ID(N'dbo.sp_banci_vista_previa_actualizacion_v2')),(OBJECT_ID(N'dbo.sp_banci_asignar_folios_v2')),(OBJECT_ID(N'dbo.sp_banci_procesar_carga_v2')),(OBJECT_ID(N'dbo.sp_banci_buscar_victimas_v2')),(OBJECT_ID(N'dbo.sp_banci_preparar_actualizacion_v2'))) t(id) WHERE id IS NOT NULL;
-- Restricciones y triggers propios desaparecen junto con su tabla; no son dependencias externas.
INSERT @Retirar SELECT DISTINCT o.object_id FROM sys.objects o JOIN @Retirar r ON r.id=o.parent_object_id
WHERE NOT EXISTS(SELECT 1 FROM @Retirar x WHERE x.id=o.object_id);
IF EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN @Retirar r ON r.id=f.referenced_object_id WHERE NOT EXISTS(SELECT 1 FROM @Retirar x WHERE x.id=f.parent_object_id))
    THROW 52912,'Hay una FK externa al modelo BANCI; actualizar el inventario antes de retirar objetos.',1;
IF EXISTS(SELECT 1 FROM sys.sql_expression_dependencies d JOIN @Retirar r ON r.id=d.referenced_id
    WHERE d.referencing_id NOT IN (ISNULL(OBJECT_ID(N'dbo.usp_mantenimiento_banci'),0),ISNULL(OBJECT_ID(N'dbo.sp_sistema_configuracion_cambiar'),0))
    AND NOT EXISTS(SELECT 1 FROM @Retirar x WHERE x.id=d.referencing_id))
    THROW 52912,'Hay una dependencia externa no prevista; actualizar el inventario antes de retirar objetos.',1;
DROP PROCEDURE IF EXISTS dbo.sp_banci_confirmar_carga_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_procesar_carga;
DROP PROCEDURE IF EXISTS dbo.sp_banci_vista_previa_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_vista_previa;
DROP VIEW IF EXISTS dbo.banci_vw_victimas_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_confirmar_carga;
DROP PROCEDURE IF EXISTS dbo.sp_banci_confirmar_actualizacion_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_calcular_actualizacion_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_vista_previa_actualizacion_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_asignar_folios_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_procesar_carga_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_buscar_victimas_v2;
DROP PROCEDURE IF EXISTS dbo.sp_banci_preparar_actualizacion_v2;
DROP FUNCTION IF EXISTS dbo.fn_banci_es_usuario_federal;
DROP FUNCTION IF EXISTS dbo.fn_banci_puede_actualizar_victima;
DROP TABLE IF EXISTS dbo.banci_cruce_federal;
DROP TABLE IF EXISTS dbo.banci_cruce_mensual;
DROP TABLE IF EXISTS dbo.banci_historial_cambio;
DROP TABLE IF EXISTS dbo.banci_actualizacion_v2;
DROP TABLE IF EXISTS dbo.banci_victima;
DROP TABLE IF EXISTS dbo.banci_delito;
DROP TABLE IF EXISTS dbo.banci_carpeta_investigacion;
DROP TABLE IF EXISTS dbo.banci_carga_tmp_victima;
DROP TABLE IF EXISTS dbo.banci_carga_tmp_delito;
DROP TABLE IF EXISTS dbo.banci_carga_tmp_carpeta;
DROP TABLE IF EXISTS dbo.banci_carga_observacion;
DROP TABLE IF EXISTS dbo.banci_carga_archivo;
DROP TABLE IF EXISTS dbo.banci_carga_bitacora_estado;
DROP TABLE IF EXISTS dbo.banci_carga;
DROP TABLE IF EXISTS dbo.banci_consecutivo_carpeta;
DROP TABLE IF EXISTS dbo.banci_catalogo_voluntaria;
DROP TABLE IF EXISTS dbo.banci_catalogo_fue_delito;
DROP TABLE IF EXISTS dbo.banci_catalogo_motivo_localizacion;
EXEC sys.sp_executesql N'CREATE TABLE dbo.banci_carga(
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
 id_delito NVARCHAR(250) NOT NULL, dto NVARCHAR(500) NULL, moda_dto NVARCHAR(500) NULL,
 forma_acc TINYINT NULL REFERENCES dbo.catalogo_forma_accion(clave),
 fha_de_hchos DATE NULL, hra_de_hchos TIME(0) NULL,
 emto_com_dto TINYINT NULL REFERENCES dbo.catalogo_instrumento_comision(clave),
 grdo_cons TINYINT NULL REFERENCES dbo.catalogo_grado_consumacion(clave),
 clasf_de_dto NVARCHAR(20) NOT NULL,
 nom_ent_hchos NVARCHAR(250) NULL, id_ent_hchos TINYINT NULL REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
 nom_mun_hchos NVARCHAR(250) NULL, id_mun_hchos NVARCHAR(5) NULL,
 nom_loc_hchos NVARCHAR(250) NULL, id_loc_hchos NVARCHAR(100) NULL,
 nom_col_hchos NVARCHAR(250) NULL, id_col_hchos NVARCHAR(100) NULL,
 cp NVARCHAR(100) NULL, coord_x DECIMAL(18,10) NULL, coord_y DECIMAL(18,10) NULL, dom_hchos NVARCHAR(2000) NULL,
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
 segundo_apellido_vicfem NVARCHAR(250) NULL, curp_vicfem NVARCHAR(18) NULL,
 fub NVARCHAR(250) NULL, pro_apellido NVARCHAR(250) NULL, sdo_apellido NVARCHAR(250) NULL, nomb NVARCHAR(500) NULL,
 entidad_nacimiento NVARCHAR(250) NULL, estado_migratorio NVARCHAR(500) NULL, curp NVARCHAR(18) NULL, rfc NVARCHAR(13) NULL,
 localizado_o_no_localizado TINYINT NULL REFERENCES dbo.banci_catalogo_localizacion(clave),
 con_o_sin_vida TINYINT NULL REFERENCES dbo.banci_catalogo_condicion_vida(clave), fecha_localizacion DATE NULL,
 constitutiva_delito TINYINT NULL REFERENCES dbo.banci_catalogo_constitutiva_delito(clave),
 motivo_desaparicion NVARCHAR(1000) NULL, acciones_busqueda NVARCHAR(MAX) NULL, obs NVARCHAR(MAX) NULL,
 id_victima_consolidado BIGINT NULL, activo BIT NOT NULL DEFAULT(1),
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
CREATE INDEX IX_banci_reclasificado_delito ON dbo.banci_reclasificado(id_banci_delito);
';
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_sistema_configuracion_cambiar
    @IdUsuario INT, @Modulo NVARCHAR(20), @Clave NVARCHAR(60), @Habilitado BIT, @VersionEsperada BIGINT, @Motivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 52600, ''Ejecute sin transacciones abiertas.'', 1;
    IF @Habilitado IS NULL OR @VersionEsperada IS NULL OR NULLIF(LTRIM(RTRIM(@Motivo)), N'''') IS NULL THROW 52602, ''Valor, versión y motivo son obligatorios.'', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Lock INT, @Version BIGINT, @IdModulo TINYINT, @Anterior BIT, @Disponible BIT;
        EXEC @Lock = sys.sp_getapplock @Resource = N''SIIID2:CONFIGURACION'', @LockMode = N''Exclusive'', @LockOwner = N''Transaction'', @LockTimeout = 10000;
        IF @Lock < 0 THROW 52601, ''No se pudo bloquear la configuración.'', 1;
        IF NOT EXISTS (
            SELECT 1 FROM dbo.sistema_administrador a WITH (HOLDLOCK)
            JOIN dbo.usuario u WITH (HOLDLOCK) ON u.id_usuario = a.id_usuario
            JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol
            WHERE a.id_usuario = @IdUsuario AND a.activo = 1 AND u.activo = 1 AND r.activo = 1 AND r.rol = N''SUPER_USUARIO''
        ) THROW 52603, ''No tiene permiso de administración del sistema.'', 1;
        SELECT @Version = version FROM dbo.sistema_configuracion_version WITH (UPDLOCK, HOLDLOCK) WHERE id = 1;
        IF @Version IS NULL OR @Version <> @VersionEsperada THROW 52604, ''La configuración cambió. Actualice la pantalla antes de guardar.'', 1;
        SELECT @IdModulo = id_modulo FROM dbo.catalogo_modulo WITH (UPDLOCK, HOLDLOCK) WHERE clave = @Modulo;
        IF @IdModulo IS NULL OR @Modulo NOT IN (N''MENSUAL'', N''SEMANAL'', N''FEDERAL'', N''BANCI'') THROW 52605, ''Módulo no administrable.'', 1;

        DECLARE @Dependientes TABLE (modulo NVARCHAR(20), clave NVARCHAR(60), anterior BIT);
        IF @Habilitado = 1 AND @Clave = N''RENAPO'' AND @Modulo IN (N''MENSUAL'', N''FEDERAL'') AND NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion WHERE id_modulo=@IdModulo AND clave=N''FEMINICIDIO_DATOS_ADICIONALES'' AND habilitado=1 AND disponible=1)
            THROW 52606, ''Active las reglas de feminicidio antes de habilitar RENAPO.'', 1;

        IF @Clave = N''MODULO_ACTIVO''
        BEGIN
            SELECT @Anterior = activo FROM dbo.catalogo_modulo WHERE id_modulo = @IdModulo;
            IF @Modulo=N''BANCI'' AND @Habilitado=1 AND COL_LENGTH(N''dbo.banci_carga'',N''mes_corte'') IS NULL THROW 52606,''Complete la instalación mensual BANCI antes de activarlo.'',1;
            IF @Anterior <> @Habilitado UPDATE dbo.catalogo_modulo SET activo = @Habilitado WHERE id_modulo = @IdModulo;
        END
        ELSE
        BEGIN
            SELECT @Anterior = habilitado, @Disponible = disponible FROM dbo.sistema_configuracion WITH (UPDLOCK, HOLDLOCK) WHERE id_modulo = @IdModulo AND clave = @Clave;
            IF @Anterior IS NULL THROW 52605, ''Opción de configuración inexistente.'', 1;
            IF @Disponible = 0 THROW 52606, ''Esta funcionalidad todavía no está implementada.'', 1;
            IF @Anterior <> @Habilitado UPDATE dbo.sistema_configuracion SET habilitado = @Habilitado WHERE id_modulo = @IdModulo AND clave = @Clave;
        END;
        IF @Habilitado=0
        BEGIN
            UPDATE c SET habilitado=0
            OUTPUT m.clave, inserted.clave, deleted.habilitado INTO @Dependientes
            FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo
            WHERE c.habilitado=1 AND (
                (@Modulo IN (N''MENSUAL'',N''FEDERAL'') AND @Clave=N''FEMINICIDIO_DATOS_ADICIONALES'' AND m.clave=@Modulo AND c.clave=N''RENAPO'')
            );
        END;
        IF @Anterior <> @Habilitado OR EXISTS (SELECT 1 FROM @Dependientes)
        BEGIN
            UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
            SELECT @Version = version FROM dbo.sistema_configuracion_version WHERE id = 1;
            IF @Anterior <> @Habilitado
            INSERT dbo.sistema_configuracion_bitacora (id_usuario, modulo, clave, valor_anterior, valor_nuevo, motivo, version)
            VALUES (@IdUsuario, @Modulo, @Clave, @Anterior, @Habilitado, LTRIM(RTRIM(@Motivo)), @Version);
        END;
        INSERT dbo.sistema_configuracion_bitacora (id_usuario, modulo, clave, valor_anterior, valor_nuevo, motivo, version)
        SELECT @IdUsuario, modulo, clave, anterior, 0, LEFT(N''Desactivación por dependencia: ''+@Modulo+N''/''+@Clave+N''. ''+@Motivo,500), @Version FROM @Dependientes;
        COMMIT;
        SELECT @Version AS version, CAST(CASE WHEN @Anterior <> @Habilitado OR EXISTS (SELECT 1 FROM @Dependientes) THEN 1 ELSE 0 END AS BIT) AS modificado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH;
END;';
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_mantenimiento_banci
 @EjecutarMantenimiento BIT=0, @ActualizarEstadisticas BIT=1, @DiasRetencion INT=90
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 OR (2 & @@OPTIONS)=2 THROW 51070,''Ejecute sin transacciones abiertas ni IMPLICIT_TRANSACTIONS.'',1;
 IF @EjecutarMantenimiento IS NULL OR @ActualizarEstadisticas IS NULL OR @DiasRetencion IS NULL OR @DiasRetencion NOT BETWEEN 90 AND 36500
    THROW 51071,''Parámetros de mantenimiento inválidos.'',1;
 DECLARE @Limite DATETIME2(7)=DATEADD(DAY,-@DiasRetencion,SYSUTCDATETIME());
 BEGIN TRY
 BEGIN TRANSACTION;
 SELECT id_banci_carga INTO #Rechazadas FROM dbo.banci_carga WITH(UPDLOCK,HOLDLOCK)
 WHERE estado IN(N''RECHAZADO_VALIDACION'',N''RECHAZADO_ADMIN'',N''RECHAZADO_USUARIO'') AND fecha_validacion<@Limite;
 DELETE t FROM dbo.banci_carga_tmp_victima t JOIN #Rechazadas c ON c.id_banci_carga=t.id_banci_carga;
 DELETE t FROM dbo.banci_carga_tmp_delito t JOIN #Rechazadas c ON c.id_banci_carga=t.id_banci_carga;
 DELETE t FROM dbo.banci_carga_tmp_carpeta t JOIN #Rechazadas c ON c.id_banci_carga=t.id_banci_carga;
 IF @EjecutarMantenimiento=1 COMMIT; ELSE ROLLBACK;
 IF @EjecutarMantenimiento=1 AND @ActualizarEstadisticas=1
 BEGIN
  UPDATE STATISTICS dbo.banci_carga;
  UPDATE STATISTICS dbo.banci_carga_tmp_carpeta;
  UPDATE STATISTICS dbo.banci_carga_tmp_delito;
  UPDATE STATISTICS dbo.banci_carga_tmp_victima;
 END;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
END;
';
DELETE c FROM dbo.sistema_configuracion c WHERE c.clave=N'CRUCE_BANCI';
DECLARE @Banci TINYINT=(SELECT id_modulo FROM dbo.catalogo_modulo WHERE clave=N'BANCI');
IF @Banci IS NULL THROW 52913,'No existe el módulo BANCI.',1;
INSERT dbo.sistema_configuracion(id_modulo,clave,descripcion,habilitado,disponible)
SELECT @Banci,v.clave,v.descripcion,v.habilitado,v.disponible FROM (VALUES
 (N'PERMITIR_CORTES_ANTERIORES',N'Permitir cargas de cortes anteriores (se habilita con el bloque de carga)',CONVERT(BIT,0),CONVERT(BIT,0)),
 (N'VALIDACIONES_CAMPOS',N'Validaciones de contenido de campos BANCI; integridad y origen siempre protegidos',CONVERT(BIT,1),CONVERT(BIT,1)),
 (N'CRUCE_ACTUALIZACION_CONSOLIDADO',N'Cruce de actualizaciones del consolidado (se habilita con su bloque)',CONVERT(BIT,0),CONVERT(BIT,0))
) v(clave,descripcion,habilitado,disponible)
WHERE NOT EXISTS(SELECT 1 FROM dbo.sistema_configuracion c WHERE c.id_modulo=@Banci AND c.clave=v.clave);
UPDATE dbo.sistema_configuracion_version SET version=version+1,fecha_modificacion=SYSUTCDATETIME() WHERE id=1;
COMMIT;
SELECT N'Bloque 1 instalado: esquema mensual preparado, operaciones antiguas retiradas.' AS resultado;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
