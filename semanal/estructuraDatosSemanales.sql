USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.catalogo_modulo', N'U') IS NULL
       OR OBJECT_ID(N'dbo.usuario_modulo', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_configuracion_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga_delito_configurado', N'U') IS NULL
    BEGIN
        THROW 50010, 'Primero deben ejecutarse los scripts base del módulo semanal.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_carpeta_investigacion', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carpeta_investigacion
        (
            id_semanal_carpeta_investigacion BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            identificador_carpeta_fiscalia NVARCHAR(250) NOT NULL,
            nomenclatura_carpeta_fiscalia NVARCHAR(250) NOT NULL,
            fecha_inicio DATETIME2(0) NOT NULL,
            resumen_hechos NVARCHAR(MAX) NULL,
            id_usuario_registro INT NOT NULL,
            fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_carpeta_fecha_registro DEFAULT (SYSDATETIME()),
            activo BIT NOT NULL CONSTRAINT DF_semanal_carpeta_activo DEFAULT (1),
            CONSTRAINT PK_semanal_carpeta_investigacion PRIMARY KEY (id_semanal_carpeta_investigacion),
            CONSTRAINT FK_semanal_carpeta_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_carpeta_usuario_registro FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario)
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_carpeta_investigacion_historico', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carpeta_investigacion_historico
        (
            id_semanal_carpeta_investigacion_historico BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carpeta_investigacion BIGINT NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            identificador_carpeta_fiscalia NVARCHAR(250) NOT NULL,
            nomenclatura_carpeta_fiscalia NVARCHAR(250) NOT NULL,
            fecha_inicio DATETIME2(0) NOT NULL,
            resumen_hechos NVARCHAR(MAX) NULL,
            id_usuario_registro INT NOT NULL,
            fecha_registro DATETIME2(0) NOT NULL,
            id_usuario_modificacion INT NULL,
            id_semanal_carga_nueva BIGINT NOT NULL,
            tipo_movimiento NVARCHAR(20) NOT NULL CONSTRAINT DF_semanal_carpeta_historico_tipo_movimiento DEFAULT (N'MODIFICADO'),
            fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_carpeta_historico_fecha_modificacion DEFAULT (SYSDATETIME()),
            activo BIT NOT NULL CONSTRAINT DF_semanal_carpeta_historico_activo DEFAULT (1),
            CONSTRAINT PK_semanal_carpeta_investigacion_historico PRIMARY KEY (id_semanal_carpeta_investigacion_historico),
            CONSTRAINT FK_semanal_carpeta_historico_carpeta FOREIGN KEY (id_semanal_carpeta_investigacion) REFERENCES dbo.semanal_carpeta_investigacion(id_semanal_carpeta_investigacion),
            CONSTRAINT FK_semanal_carpeta_historico_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_carpeta_historico_usuario_registro FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_carpeta_historico_usuario_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_carpeta_historico_carga_nueva FOREIGN KEY (id_semanal_carga_nueva) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT CK_semanal_carpeta_historico_tipo_movimiento CHECK (tipo_movimiento IN (N'MODIFICADO', N'ELIMINADO'))
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_delito', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_delito
        (
            id_semanal_delito BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carpeta_investigacion BIGINT NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            identificador_delito_fiscalia NVARCHAR(50) NOT NULL,
            delito_fiscalia NVARCHAR(2000) NOT NULL,
            modalidad_delito_fiscalia NVARCHAR(2000) NULL,
            id_catalogo_delito INT NOT NULL,
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
            coordenada_x DECIMAL(10,6) NULL,
            coordenada_y DECIMAL(10,6) NULL,
            domicilio_hechos NVARCHAR(MAX) NULL,
            id_usuario_registro INT NOT NULL,
            fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_delito_fecha_registro DEFAULT (SYSDATETIME()),
            activo BIT NOT NULL CONSTRAINT DF_semanal_delito_activo DEFAULT (1),
            CONSTRAINT PK_semanal_delito PRIMARY KEY (id_semanal_delito),
            CONSTRAINT FK_semanal_delito_carpeta FOREIGN KEY (id_semanal_carpeta_investigacion) REFERENCES dbo.semanal_carpeta_investigacion(id_semanal_carpeta_investigacion),
            CONSTRAINT FK_semanal_delito_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_delito_catalogo_delito FOREIGN KEY (id_catalogo_delito) REFERENCES dbo.catalogo_delito(id_delito),
            CONSTRAINT FK_semanal_delito_forma_accion FOREIGN KEY (id_forma_accion) REFERENCES dbo.catalogo_forma_accion(id_forma_accion),
            CONSTRAINT FK_semanal_delito_instrumento FOREIGN KEY (id_instrumento_comision) REFERENCES dbo.catalogo_instrumento_comision(id_instrumento_comision),
            CONSTRAINT FK_semanal_delito_grado FOREIGN KEY (id_grado_consumacion) REFERENCES dbo.catalogo_grado_consumacion(id_grado_consumacion),
            CONSTRAINT FK_semanal_delito_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.catalogo_modalidad_delito(id_modalidad_delito),
            CONSTRAINT FK_semanal_delito_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
            CONSTRAINT FK_semanal_delito_municipio FOREIGN KEY (id_municipio) REFERENCES dbo.catalogo_municipio(id_municipio),
            CONSTRAINT FK_semanal_delito_codigo_postal FOREIGN KEY (id_codigo_postal) REFERENCES dbo.catalogo_codigo_postal(id_codigo_postal),
            CONSTRAINT FK_semanal_delito_usuario_registro FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_delito_configurado FOREIGN KEY (id_semanal_carga, id_catalogo_delito) REFERENCES dbo.semanal_carga_delito_configurado(id_semanal_carga, id_delito)
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_delito_historico', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_delito_historico
        (
            id_semanal_delito_historico BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_delito BIGINT NOT NULL,
            id_semanal_carpeta_investigacion BIGINT NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            identificador_delito_fiscalia NVARCHAR(50) NOT NULL,
            delito_fiscalia NVARCHAR(2000) NOT NULL,
            modalidad_delito_fiscalia NVARCHAR(2000) NULL,
            id_catalogo_delito INT NOT NULL,
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
            coordenada_x DECIMAL(10,6) NULL,
            coordenada_y DECIMAL(10,6) NULL,
            domicilio_hechos NVARCHAR(MAX) NULL,
            id_usuario_registro INT NOT NULL,
            fecha_registro DATETIME2(0) NOT NULL,
            id_usuario_modificacion INT NULL,
            id_semanal_carga_nueva BIGINT NOT NULL,
            tipo_movimiento NVARCHAR(20) NOT NULL CONSTRAINT DF_semanal_delito_historico_tipo_movimiento DEFAULT (N'MODIFICADO'),
            fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_delito_historico_fecha_modificacion DEFAULT (SYSDATETIME()),
            activo BIT NOT NULL CONSTRAINT DF_semanal_delito_historico_activo DEFAULT (1),
            CONSTRAINT PK_semanal_delito_historico PRIMARY KEY (id_semanal_delito_historico),
            CONSTRAINT FK_semanal_delito_historico_delito FOREIGN KEY (id_semanal_delito) REFERENCES dbo.semanal_delito(id_semanal_delito),
            CONSTRAINT FK_semanal_delito_historico_carpeta FOREIGN KEY (id_semanal_carpeta_investigacion) REFERENCES dbo.semanal_carpeta_investigacion(id_semanal_carpeta_investigacion),
            CONSTRAINT FK_semanal_delito_historico_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_delito_historico_catalogo_delito FOREIGN KEY (id_catalogo_delito) REFERENCES dbo.catalogo_delito(id_delito),
            CONSTRAINT FK_semanal_delito_historico_forma FOREIGN KEY (id_forma_accion) REFERENCES dbo.catalogo_forma_accion(id_forma_accion),
            CONSTRAINT FK_semanal_delito_historico_instrumento FOREIGN KEY (id_instrumento_comision) REFERENCES dbo.catalogo_instrumento_comision(id_instrumento_comision),
            CONSTRAINT FK_semanal_delito_historico_grado FOREIGN KEY (id_grado_consumacion) REFERENCES dbo.catalogo_grado_consumacion(id_grado_consumacion),
            CONSTRAINT FK_semanal_delito_historico_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.catalogo_modalidad_delito(id_modalidad_delito),
            CONSTRAINT FK_semanal_delito_historico_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
            CONSTRAINT FK_semanal_delito_historico_municipio FOREIGN KEY (id_municipio) REFERENCES dbo.catalogo_municipio(id_municipio),
            CONSTRAINT FK_semanal_delito_historico_codigo_postal FOREIGN KEY (id_codigo_postal) REFERENCES dbo.catalogo_codigo_postal(id_codigo_postal),
            CONSTRAINT FK_semanal_delito_historico_usuario_registro FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_delito_historico_usuario_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_delito_historico_carga_nueva FOREIGN KEY (id_semanal_carga_nueva) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_delito_historico_configurado FOREIGN KEY (id_semanal_carga, id_catalogo_delito) REFERENCES dbo.semanal_carga_delito_configurado(id_semanal_carga, id_delito),
            CONSTRAINT CK_semanal_delito_historico_tipo_movimiento CHECK (tipo_movimiento IN (N'MODIFICADO', N'ELIMINADO'))
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_victima', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_victima
        (
            id_semanal_victima BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_delito BIGINT NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
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
            fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_victima_fecha_registro DEFAULT (SYSDATETIME()),
            activo BIT NOT NULL CONSTRAINT DF_semanal_victima_activo DEFAULT (1),
            CONSTRAINT PK_semanal_victima PRIMARY KEY (id_semanal_victima),
            CONSTRAINT FK_semanal_victima_delito FOREIGN KEY (id_semanal_delito) REFERENCES dbo.semanal_delito(id_semanal_delito),
            CONSTRAINT FK_semanal_victima_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_victima_tipo_victima FOREIGN KEY (id_tipo_victima) REFERENCES dbo.catalogo_tipo_victima(id_tipo_victima),
            CONSTRAINT FK_semanal_victima_tipo_victima_moral FOREIGN KEY (id_tipo_victima_moral) REFERENCES dbo.catalogo_tipo_victima_moral(id_tipo_victima_moral),
            CONSTRAINT FK_semanal_victima_sexo FOREIGN KEY (id_sexo) REFERENCES dbo.catalogo_sexo(id_sexo),
            CONSTRAINT FK_semanal_victima_genero FOREIGN KEY (id_genero) REFERENCES dbo.catalogo_genero(id_genero),
            CONSTRAINT FK_semanal_victima_nacionalidad FOREIGN KEY (id_nacionalidad) REFERENCES dbo.catalogo_nacionalidad(id_nacionalidad),
            CONSTRAINT FK_semanal_victima_poblacion_indigena FOREIGN KEY (id_pertenece_poblacion_indigena) REFERENCES dbo.catalogo_pertenece_poblacion_indigena(id_pertenece_poblacion_indigena),
            CONSTRAINT FK_semanal_victima_discapacidad FOREIGN KEY (id_presenta_discapacidad) REFERENCES dbo.catalogo_presenta_discapacidad(id_presenta_discapacidad),
            CONSTRAINT FK_semanal_victima_usuario_registro FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario)
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_victima_historico', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_victima_historico
        (
            id_semanal_victima_historico BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_victima BIGINT NOT NULL,
            id_semanal_delito BIGINT NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
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
            id_usuario_modificacion INT NULL,
            id_semanal_carga_nueva BIGINT NOT NULL,
            tipo_movimiento NVARCHAR(20) NOT NULL CONSTRAINT DF_semanal_victima_historico_tipo_movimiento DEFAULT (N'MODIFICADO'),
            fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_victima_historico_fecha_modificacion DEFAULT (SYSDATETIME()),
            activo BIT NOT NULL CONSTRAINT DF_semanal_victima_historico_activo DEFAULT (1),
            CONSTRAINT PK_semanal_victima_historico PRIMARY KEY (id_semanal_victima_historico),
            CONSTRAINT FK_semanal_victima_historico_victima FOREIGN KEY (id_semanal_victima) REFERENCES dbo.semanal_victima(id_semanal_victima),
            CONSTRAINT FK_semanal_victima_historico_delito FOREIGN KEY (id_semanal_delito) REFERENCES dbo.semanal_delito(id_semanal_delito),
            CONSTRAINT FK_semanal_victima_historico_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_victima_historico_tipo_victima FOREIGN KEY (id_tipo_victima) REFERENCES dbo.catalogo_tipo_victima(id_tipo_victima),
            CONSTRAINT FK_semanal_victima_historico_tipo_victima_moral FOREIGN KEY (id_tipo_victima_moral) REFERENCES dbo.catalogo_tipo_victima_moral(id_tipo_victima_moral),
            CONSTRAINT FK_semanal_victima_historico_sexo FOREIGN KEY (id_sexo) REFERENCES dbo.catalogo_sexo(id_sexo),
            CONSTRAINT FK_semanal_victima_historico_genero FOREIGN KEY (id_genero) REFERENCES dbo.catalogo_genero(id_genero),
            CONSTRAINT FK_semanal_victima_historico_nacionalidad FOREIGN KEY (id_nacionalidad) REFERENCES dbo.catalogo_nacionalidad(id_nacionalidad),
            CONSTRAINT FK_semanal_victima_historico_poblacion_indigena FOREIGN KEY (id_pertenece_poblacion_indigena) REFERENCES dbo.catalogo_pertenece_poblacion_indigena(id_pertenece_poblacion_indigena),
            CONSTRAINT FK_semanal_victima_historico_discapacidad FOREIGN KEY (id_presenta_discapacidad) REFERENCES dbo.catalogo_presenta_discapacidad(id_presenta_discapacidad),
            CONSTRAINT FK_semanal_victima_historico_usuario_registro FOREIGN KEY (id_usuario_registro) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_victima_historico_usuario_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_victima_historico_carga_nueva FOREIGN KEY (id_semanal_carga_nueva) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT CK_semanal_victima_historico_tipo_movimiento CHECK (tipo_movimiento IN (N'MODIFICADO', N'ELIMINADO'))
        );
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_carpeta_investigacion') AND name = N'IX_semanal_carpeta_carga_activo_identificador')
    BEGIN
        CREATE INDEX IX_semanal_carpeta_carga_activo_identificador ON dbo.semanal_carpeta_investigacion (id_semanal_carga, activo, identificador_carpeta_fiscalia) INCLUDE (id_semanal_carpeta_investigacion, fecha_inicio);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_carpeta_investigacion') AND name = N'IX_semanal_carpeta_identificador_activo')
    BEGIN
        CREATE INDEX IX_semanal_carpeta_identificador_activo ON dbo.semanal_carpeta_investigacion (identificador_carpeta_fiscalia, activo, id_semanal_carga) INCLUDE (id_semanal_carpeta_investigacion, fecha_inicio);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_carpeta_investigacion_historico') AND name = N'IX_semanal_carpeta_historico_carpeta_carga')
    BEGIN
        CREATE INDEX IX_semanal_carpeta_historico_carpeta_carga ON dbo.semanal_carpeta_investigacion_historico (id_semanal_carpeta_investigacion, id_semanal_carga_nueva, fecha_modificacion);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_delito') AND name = N'IX_semanal_delito_carga_carpeta_identificador')
    BEGIN
        CREATE INDEX IX_semanal_delito_carga_carpeta_identificador ON dbo.semanal_delito (id_semanal_carga, activo, id_semanal_carpeta_investigacion, identificador_delito_fiscalia) INCLUDE (id_semanal_delito, id_catalogo_delito);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_delito') AND name = N'IX_semanal_delito_carpeta_identificador_activo')
    BEGIN
        CREATE INDEX IX_semanal_delito_carpeta_identificador_activo ON dbo.semanal_delito (id_semanal_carpeta_investigacion, identificador_delito_fiscalia, activo, id_semanal_carga) INCLUDE (id_semanal_delito, id_catalogo_delito);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_delito') AND name = N'IX_semanal_delito_catalogo_activo_carga')
    BEGIN
        CREATE INDEX IX_semanal_delito_catalogo_activo_carga ON dbo.semanal_delito (id_catalogo_delito, activo, id_semanal_carga) INCLUDE (id_semanal_delito, id_semanal_carpeta_investigacion);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_delito_historico') AND name = N'IX_semanal_delito_historico_delito_carga')
    BEGIN
        CREATE INDEX IX_semanal_delito_historico_delito_carga ON dbo.semanal_delito_historico (id_semanal_delito, id_semanal_carga_nueva, fecha_modificacion);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_victima') AND name = N'IX_semanal_victima_carga_delito_identificador')
    BEGIN
        CREATE INDEX IX_semanal_victima_carga_delito_identificador ON dbo.semanal_victima (id_semanal_carga, activo, id_semanal_delito, identificador_victima_fiscalia) INCLUDE (id_semanal_victima);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_victima') AND name = N'IX_semanal_victima_delito_identificador_activo')
    BEGIN
        CREATE INDEX IX_semanal_victima_delito_identificador_activo ON dbo.semanal_victima (id_semanal_delito, identificador_victima_fiscalia, activo, id_semanal_carga) INCLUDE (id_semanal_victima);
    END;

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.semanal_victima_historico') AND name = N'IX_semanal_victima_historico_victima_carga')
    BEGIN
        CREATE INDEX IX_semanal_victima_historico_victima_carga ON dbo.semanal_victima_historico (id_semanal_victima, id_semanal_carga_nueva, fecha_modificacion);
    END;

    COMMIT TRANSACTION;

    PRINT 'Tablas finales e históricas del módulo semanal creadas correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
GO