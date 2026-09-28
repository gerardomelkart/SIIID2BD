-- REFERENCIA TECNICA: base y ajustes en secuencia; no ejecutar sobre una BD publicada.
-- No sustituye una exportación del esquema real. Revisar dependencias indicadas en README.

-- Fuente: semanal/baseSemanal.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.catalogo_modulo', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.catalogo_modulo
        (
            id_modulo TINYINT IDENTITY(1,1) NOT NULL,
            clave NVARCHAR(20) NOT NULL,
            nombre NVARCHAR(100) NOT NULL,
            activo BIT NOT NULL CONSTRAINT DF_catalogo_modulo_activo DEFAULT (1),
            CONSTRAINT PK_catalogo_modulo PRIMARY KEY (id_modulo),
            CONSTRAINT UQ_catalogo_modulo_clave UNIQUE (clave)
        );
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.catalogo_modulo WHERE clave = N'MENSUAL')
    BEGIN
        INSERT INTO dbo.catalogo_modulo (clave, nombre, activo) VALUES (N'MENSUAL', N'SIIID2 Mensual', 1);
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.catalogo_modulo WHERE clave = N'SEMANAL')
    BEGIN
        INSERT INTO dbo.catalogo_modulo (clave, nombre, activo) VALUES (N'SEMANAL', N'SIIID2 Semanal', 1);
    END;

    IF OBJECT_ID(N'dbo.usuario_modulo', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.usuario_modulo
        (
            id_usuario_modulo INT IDENTITY(1,1) NOT NULL,
            id_usuario INT NOT NULL,
            id_modulo TINYINT NOT NULL,
            habilitado BIT NOT NULL CONSTRAINT DF_usuario_modulo_habilitado DEFAULT (0),
            habilita_carga BIT NOT NULL CONSTRAINT DF_usuario_modulo_habilita_carga DEFAULT (0),
            habilita_modificacion BIT NOT NULL CONSTRAINT DF_usuario_modulo_habilita_modificacion DEFAULT (0),
            administra_delitos BIT NOT NULL CONSTRAINT DF_usuario_modulo_administra_delitos DEFAULT (0),
            fecha_alta DATETIME2(0) NOT NULL CONSTRAINT DF_usuario_modulo_fecha_alta DEFAULT (SYSDATETIME()),
            fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_usuario_modulo_fecha_modificacion DEFAULT (SYSDATETIME()),
            id_usuario_modificacion INT NULL,
            activo BIT NOT NULL CONSTRAINT DF_usuario_modulo_activo DEFAULT (1),
            CONSTRAINT PK_usuario_modulo PRIMARY KEY (id_usuario_modulo),
            CONSTRAINT UQ_usuario_modulo_usuario_modulo UNIQUE (id_usuario, id_modulo),
            CONSTRAINT FK_usuario_modulo_usuario FOREIGN KEY (id_usuario) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_usuario_modulo_modulo FOREIGN KEY (id_modulo) REFERENCES dbo.catalogo_modulo(id_modulo),
            CONSTRAINT FK_usuario_modulo_usuario_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario)
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_configuracion_delito', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_configuracion_delito
        (
            id_semanal_configuracion_delito INT IDENTITY(1,1) NOT NULL,
            id_delito INT NOT NULL,
            es_obligatorio BIT NOT NULL CONSTRAINT DF_semanal_configuracion_delito_es_obligatorio DEFAULT (0),
            conservar_entre_periodos BIT NOT NULL CONSTRAINT DF_semanal_configuracion_delito_conservar DEFAULT (0),
            orden SMALLINT NOT NULL CONSTRAINT DF_semanal_configuracion_delito_orden DEFAULT (0),
            fecha_alta DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_configuracion_delito_fecha_alta DEFAULT (SYSDATETIME()),
            fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_configuracion_delito_fecha_modificacion DEFAULT (SYSDATETIME()),
            id_usuario_modificacion INT NULL,
            activo BIT NOT NULL CONSTRAINT DF_semanal_configuracion_delito_activo DEFAULT (1),
            CONSTRAINT PK_semanal_configuracion_delito PRIMARY KEY (id_semanal_configuracion_delito),
            CONSTRAINT UQ_semanal_configuracion_delito_delito UNIQUE (id_delito),
            CONSTRAINT FK_semanal_configuracion_delito_delito FOREIGN KEY (id_delito) REFERENCES dbo.catalogo_delito(id_delito),
            CONSTRAINT FK_semanal_configuracion_delito_usuario_modificacion FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT CK_semanal_configuracion_delito_obligatorio_activo CHECK (es_obligatorio = 0 OR activo = 1)
        );
    END;

    DECLARE @IdModuloMensual TINYINT = (SELECT id_modulo FROM dbo.catalogo_modulo WHERE clave = N'MENSUAL');
    DECLARE @IdModuloSemanal TINYINT = (SELECT id_modulo FROM dbo.catalogo_modulo WHERE clave = N'SEMANAL');

    IF @IdModuloMensual IS NULL OR @IdModuloSemanal IS NULL
    BEGIN
        THROW 50001, 'No fue posible resolver los módulos MENSUAL y SEMANAL.', 1;
    END;

    INSERT INTO dbo.usuario_modulo (id_usuario, id_modulo, habilitado, habilita_carga, habilita_modificacion, administra_delitos, activo)
    SELECT u.id_usuario, @IdModuloMensual, 1, ISNULL(h.habilita_carga, 0), ISNULL(h.habilita_modificacion, 0), 0, 1
    FROM dbo.usuario u
    LEFT JOIN dbo.habilita_carga_modificacion h ON h.id_usuario = u.id_usuario AND h.activo = 1
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.usuario_modulo um
        WHERE um.id_usuario = u.id_usuario
          AND um.id_modulo = @IdModuloMensual
    );

    INSERT INTO dbo.usuario_modulo (id_usuario, id_modulo, habilitado, habilita_carga, habilita_modificacion, administra_delitos, activo)
    SELECT u.id_usuario, @IdModuloSemanal, 0, 0, 0, 0, 1
    FROM dbo.usuario u
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.usuario_modulo um
        WHERE um.id_usuario = u.id_usuario
          AND um.id_modulo = @IdModuloSemanal
    );

    IF (SELECT COUNT(*) FROM dbo.catalogo_delito WHERE clave2 = N'4.04') <> 1
    BEGIN
        THROW 50002, 'No se encontró una única definición del delito Extorsión con clave 4.04.', 1;
    END;

    DECLARE @IdDelitoExtorsion INT = (SELECT id_delito FROM dbo.catalogo_delito WHERE clave2 = N'4.04');

    IF EXISTS (SELECT 1 FROM dbo.semanal_configuracion_delito WHERE id_delito = @IdDelitoExtorsion)
    BEGIN
        UPDATE dbo.semanal_configuracion_delito
        SET es_obligatorio = 1,
            conservar_entre_periodos = 1,
            orden = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_delito = @IdDelitoExtorsion;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.semanal_configuracion_delito (id_delito, es_obligatorio, conservar_entre_periodos, orden, activo)
        VALUES (@IdDelitoExtorsion, 1, 1, 1, 1);
    END;

    COMMIT TRANSACTION;

    PRINT 'Base del módulo semanal creada correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
GO

GO

-- Fuente: semanal/baseModuloSemanal.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga
        (
            id_semanal_carga BIGINT IDENTITY(1,1) NOT NULL,
            id_usuario_carga INT NOT NULL,
            id_entidad_federativa TINYINT NULL,
            codigo_referencia NVARCHAR(50) NOT NULL,
            tipo_carga NVARCHAR(20) NOT NULL CONSTRAINT DF_semanal_carga_tipo_carga DEFAULT (N'CARGA_INICIAL'),
            tipo_contenido NVARCHAR(20) NOT NULL,
            anio_semana SMALLINT NOT NULL,
            numero_semana TINYINT NOT NULL,
            fecha_inicio_semana DATE NOT NULL,
            fecha_fin_semana DATE NOT NULL,
            fecha_inicio_tramo DATE NOT NULL,
            fecha_fin_tramo DATE NOT NULL,
            mes_corte TINYINT NOT NULL,
            anio_corte SMALLINT NOT NULL,
            total_carpetas_incluidas INT NOT NULL CONSTRAINT DF_semanal_carga_carpetas_incluidas DEFAULT (0),
            total_delitos_incluidos INT NOT NULL CONSTRAINT DF_semanal_carga_delitos_incluidos DEFAULT (0),
            total_victimas_incluidas INT NOT NULL CONSTRAINT DF_semanal_carga_victimas_incluidas DEFAULT (0),
            total_carpetas_excluidas INT NOT NULL CONSTRAINT DF_semanal_carga_carpetas_excluidas DEFAULT (0),
            total_delitos_excluidos INT NOT NULL CONSTRAINT DF_semanal_carga_delitos_excluidos DEFAULT (0),
            total_victimas_excluidas INT NOT NULL CONSTRAINT DF_semanal_carga_victimas_excluidas DEFAULT (0),
            estado NVARCHAR(50) NOT NULL CONSTRAINT DF_semanal_carga_estado DEFAULT (N'VALIDADO_PENDIENTE'),
            fecha_carga DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_carga_fecha_carga DEFAULT (SYSDATETIME()),
            fecha_validacion DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_carga_fecha_validacion DEFAULT (SYSDATETIME()),
            fecha_confirmacion DATETIME2(0) NULL,
            fecha_expiracion DATETIME2(0) NULL,
            id_usuario_confirmacion INT NULL,
            mensaje_error NVARCHAR(MAX) NULL,
            rechazo_visto BIT NOT NULL CONSTRAINT DF_semanal_carga_rechazo_visto DEFAULT (1),
            fecha_rechazo_visto DATETIME2(0) NULL,
            activo BIT NOT NULL CONSTRAINT DF_semanal_carga_activo DEFAULT (1),
            CONSTRAINT PK_semanal_carga PRIMARY KEY (id_semanal_carga),
            CONSTRAINT UQ_semanal_carga_codigo_referencia UNIQUE (codigo_referencia),
            CONSTRAINT FK_semanal_carga_usuario_carga FOREIGN KEY (id_usuario_carga) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_carga_usuario_confirmacion FOREIGN KEY (id_usuario_confirmacion) REFERENCES dbo.usuario(id_usuario),
            CONSTRAINT FK_semanal_carga_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
            CONSTRAINT CK_semanal_carga_tipo_carga CHECK (tipo_carga IN (N'CARGA_INICIAL', N'ACTUALIZACION')),
            CONSTRAINT CK_semanal_carga_tipo_contenido CHECK (tipo_contenido IN (N'SOLO_SEMANA', N'ACUMULADO_MES')),
            CONSTRAINT CK_semanal_carga_numero_semana CHECK (numero_semana BETWEEN 1 AND 53),
            CONSTRAINT CK_semanal_carga_mes_corte CHECK (mes_corte BETWEEN 1 AND 12),
            CONSTRAINT CK_semanal_carga_anio_semana CHECK (anio_semana BETWEEN 2000 AND 9999),
            CONSTRAINT CK_semanal_carga_anio_corte CHECK (anio_corte BETWEEN 2000 AND 9999),
            CONSTRAINT CK_semanal_carga_fechas_semana CHECK (DATEDIFF(DAY, fecha_inicio_semana, fecha_fin_semana) = 6),
            CONSTRAINT CK_semanal_carga_fechas_tramo CHECK
            (
                fecha_inicio_tramo <= fecha_fin_tramo
                AND MONTH(fecha_inicio_tramo) = mes_corte
                AND MONTH(fecha_fin_tramo) = mes_corte
                AND YEAR(fecha_inicio_tramo) = anio_corte
                AND YEAR(fecha_fin_tramo) = anio_corte
            )
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_delito_configurado', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga_delito_configurado
        (
            id_semanal_carga_delito_configurado BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            id_delito INT NOT NULL,
            es_obligatorio BIT NOT NULL,
            conservar_entre_periodos BIT NOT NULL,
            orden SMALLINT NOT NULL,
            fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_carga_delito_configurado_fecha DEFAULT (SYSDATETIME()),
            CONSTRAINT PK_semanal_carga_delito_configurado PRIMARY KEY (id_semanal_carga_delito_configurado),
            CONSTRAINT UQ_semanal_carga_delito_configurado UNIQUE (id_semanal_carga, id_delito),
            CONSTRAINT FK_semanal_carga_delito_configurado_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_carga_delito_configurado_delito FOREIGN KEY (id_delito) REFERENCES dbo.catalogo_delito(id_delito)
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_carpeta', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga_tmp_carpeta
        (
            id_semanal_carga_tmp_carpeta BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            numero_fila INT NOT NULL,
            id_ci NVARCHAR(250) NOT NULL,
            ntra_ci NVARCHAR(250) NOT NULL,
            fha_de_ini NVARCHAR(50) NOT NULL,
            hra_de_ini NVARCHAR(50) NULL,
            rmen_de_hchos NVARCHAR(MAX) NULL,
            incluido BIT NOT NULL CONSTRAINT DF_semanal_tmp_carpeta_incluido DEFAULT (1),
            codigo_exclusion NVARCHAR(100) NULL,
            estado NVARCHAR(50) NOT NULL CONSTRAINT DF_semanal_tmp_carpeta_estado DEFAULT (N'PENDIENTE'),
            fecha_procesamiento DATETIME2(0) NULL,
            activo BIT NOT NULL CONSTRAINT DF_semanal_tmp_carpeta_activo DEFAULT (1),
            CONSTRAINT PK_semanal_carga_tmp_carpeta PRIMARY KEY (id_semanal_carga_tmp_carpeta),
            CONSTRAINT FK_semanal_carga_tmp_carpeta_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT CK_semanal_tmp_carpeta_exclusion CHECK
            (
                (incluido = 1 AND codigo_exclusion IS NULL)
                OR (incluido = 0 AND codigo_exclusion IS NOT NULL)
            )
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_delito', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga_tmp_delito
        (
            id_semanal_carga_tmp_delito BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
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
            id_loc_hchos NVARCHAR(150) NULL,
            nom_loc_hchos NVARCHAR(250) NULL,
            id_col_hchos NVARCHAR(150) NULL,
            nom_col_hchos NVARCHAR(250) NULL,
            cp NVARCHAR(250) NULL,
            coord_x NVARCHAR(50) NULL,
            coord_y NVARCHAR(50) NULL,
            dom_hchos NVARCHAR(MAX) NULL,
            incluido BIT NOT NULL CONSTRAINT DF_semanal_tmp_delito_incluido DEFAULT (1),
            codigo_exclusion NVARCHAR(100) NULL,
            estado NVARCHAR(50) NOT NULL CONSTRAINT DF_semanal_tmp_delito_estado DEFAULT (N'PENDIENTE'),
            fecha_procesamiento DATETIME2(0) NULL,
            activo BIT NOT NULL CONSTRAINT DF_semanal_tmp_delito_activo DEFAULT (1),
            CONSTRAINT PK_semanal_carga_tmp_delito PRIMARY KEY (id_semanal_carga_tmp_delito),
            CONSTRAINT FK_semanal_carga_tmp_delito_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT CK_semanal_tmp_delito_exclusion CHECK
            (
                (incluido = 1 AND codigo_exclusion IS NULL)
                OR (incluido = 0 AND codigo_exclusion IS NOT NULL)
            )
        );
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_victima', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga_tmp_victima
        (
            id_semanal_carga_tmp_victima BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
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
            incluido BIT NOT NULL CONSTRAINT DF_semanal_tmp_victima_incluido DEFAULT (1),
            codigo_exclusion NVARCHAR(100) NULL,
            estado NVARCHAR(50) NOT NULL CONSTRAINT DF_semanal_tmp_victima_estado DEFAULT (N'PENDIENTE'),
            fecha_procesamiento DATETIME2(0) NULL,
            activo BIT NOT NULL CONSTRAINT DF_semanal_tmp_victima_activo DEFAULT (1),
            CONSTRAINT PK_semanal_carga_tmp_victima PRIMARY KEY (id_semanal_carga_tmp_victima),
            CONSTRAINT FK_semanal_carga_tmp_victima_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT CK_semanal_tmp_victima_exclusion CHECK
            (
                (incluido = 1 AND codigo_exclusion IS NULL)
                OR (incluido = 0 AND codigo_exclusion IS NOT NULL)
            )
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
          AND name = N'IX_semanal_carga_entidad_periodo_estado'
    )
    BEGIN
        CREATE INDEX IX_semanal_carga_entidad_periodo_estado
        ON dbo.semanal_carga
        (
            id_entidad_federativa,
            anio_corte,
            mes_corte,
            fecha_inicio_semana,
            estado,
            activo
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_tmp_carpeta')
          AND name = N'IX_semanal_tmp_carpeta_carga_ci'
    )
    BEGIN
        CREATE INDEX IX_semanal_tmp_carpeta_carga_ci
        ON dbo.semanal_carga_tmp_carpeta
        (
            id_semanal_carga,
            id_ci,
            incluido
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_tmp_delito')
          AND name = N'IX_semanal_tmp_delito_carga_ci_delito'
    )
    BEGIN
        CREATE INDEX IX_semanal_tmp_delito_carga_ci_delito
        ON dbo.semanal_carga_tmp_delito
        (
            id_semanal_carga,
            id_ci,
            id_delito,
            incluido
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_tmp_victima')
          AND name = N'IX_semanal_tmp_victima_carga_ci_delito'
    )
    BEGIN
        CREATE INDEX IX_semanal_tmp_victima_carga_ci_delito
        ON dbo.semanal_carga_tmp_victima
        (
            id_semanal_carga,
            id_ci,
            id_delito,
            incluido
        );
    END;

    COMMIT TRANSACTION;

    PRINT 'Encabezado y temporales del módulo semanal creados correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
GO

GO

-- Fuente: semanal/estructuraDatosSemanales.sql
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

GO

-- Fuente: semanal/ampliarIdDelitoSemanal.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_delito', N'U') IS NULL
        THROW 50001, 'No existe la tabla dbo.semanal_delito.', 1;

    IF OBJECT_ID(N'dbo.semanal_delito_historico', N'U') IS NULL
        THROW 50002, 'No existe la tabla dbo.semanal_delito_historico.', 1;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_delito', N'U') IS NULL
        THROW 50003, 'No existe la tabla dbo.semanal_carga_tmp_delito.', 1;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_victima', N'U') IS NULL
        THROW 50004, 'No existe la tabla dbo.semanal_carga_tmp_victima.', 1;

    IF COL_LENGTH(N'dbo.semanal_delito', N'identificador_delito_fiscalia') < 500
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.semanal_delito')
              AND name = N'IX_semanal_delito_carga_carpeta_identificador'
        )
        BEGIN
            DROP INDEX IX_semanal_delito_carga_carpeta_identificador
            ON dbo.semanal_delito;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.semanal_delito')
              AND name = N'IX_semanal_delito_carpeta_identificador_activo'
        )
        BEGIN
            DROP INDEX IX_semanal_delito_carpeta_identificador_activo
            ON dbo.semanal_delito;
        END;

        ALTER TABLE dbo.semanal_delito
        ALTER COLUMN identificador_delito_fiscalia NVARCHAR(250) NOT NULL;

        CREATE INDEX IX_semanal_delito_carga_carpeta_identificador
        ON dbo.semanal_delito
        (
            id_semanal_carga,
            activo,
            id_semanal_carpeta_investigacion,
            identificador_delito_fiscalia
        )
        INCLUDE
        (
            id_semanal_delito,
            id_catalogo_delito
        );

        CREATE INDEX IX_semanal_delito_carpeta_identificador_activo
        ON dbo.semanal_delito
        (
            id_semanal_carpeta_investigacion,
            identificador_delito_fiscalia,
            activo,
            id_semanal_carga
        )
        INCLUDE
        (
            id_semanal_delito,
            id_catalogo_delito
        );
    END;

    IF COL_LENGTH(N'dbo.semanal_delito_historico', N'identificador_delito_fiscalia') < 500
    BEGIN
        ALTER TABLE dbo.semanal_delito_historico
        ALTER COLUMN identificador_delito_fiscalia NVARCHAR(250) NOT NULL;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga_tmp_delito', N'id_delito') < 500
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_tmp_delito')
              AND name = N'IX_semanal_tmp_delito_carga_ci_delito'
        )
        BEGIN
            DROP INDEX IX_semanal_tmp_delito_carga_ci_delito
            ON dbo.semanal_carga_tmp_delito;
        END;

        ALTER TABLE dbo.semanal_carga_tmp_delito
        ALTER COLUMN id_delito NVARCHAR(250) NOT NULL;

        CREATE INDEX IX_semanal_tmp_delito_carga_ci_delito
        ON dbo.semanal_carga_tmp_delito
        (
            id_semanal_carga,
            id_ci,
            id_delito,
            incluido
        );
    END;

    IF COL_LENGTH(N'dbo.semanal_carga_tmp_victima', N'id_delito') < 500
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM sys.indexes
            WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_tmp_victima')
              AND name = N'IX_semanal_tmp_victima_carga_ci_delito'
        )
        BEGIN
            DROP INDEX IX_semanal_tmp_victima_carga_ci_delito
            ON dbo.semanal_carga_tmp_victima;
        END;

        ALTER TABLE dbo.semanal_carga_tmp_victima
        ALTER COLUMN id_delito NVARCHAR(250) NOT NULL;

        CREATE INDEX IX_semanal_tmp_victima_carga_ci_delito
        ON dbo.semanal_carga_tmp_victima
        (
            id_semanal_carga,
            id_ci,
            id_delito,
            incluido
        );
    END;

    COMMIT TRANSACTION;

    PRINT 'El campo id_delito semanal fue ampliado correctamente a 250 caracteres.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

GO

-- Fuente: semanal/aprobacionAdministrativaSemanal.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 50001, 'No existe dbo.semanal_carga. Ejecute primero la base del módulo semanal.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_advertencia', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga_advertencia
        (
            id_semanal_carga_advertencia BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            codigo NVARCHAR(150) NOT NULL,
            archivo NVARCHAR(50) NOT NULL,
            numero_fila INT NULL,
            columna NVARCHAR(150) NULL,
            campo NVARCHAR(150) NULL,
            valor NVARCHAR(1000) NULL,
            descripcion_resumen NVARCHAR(500) NOT NULL,
            mensaje NVARCHAR(2000) NOT NULL,
            aceptada_usuario BIT NOT NULL CONSTRAINT DF_semanal_carga_advertencia_aceptada DEFAULT (0),
            id_usuario_aceptacion INT NULL,
            fecha_aceptacion DATETIME2(0) NULL,
            activo BIT NOT NULL CONSTRAINT DF_semanal_carga_advertencia_activo DEFAULT (1),
            CONSTRAINT PK_semanal_carga_advertencia PRIMARY KEY (id_semanal_carga_advertencia),
            CONSTRAINT FK_semanal_carga_advertencia_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
            CONSTRAINT FK_semanal_carga_advertencia_usuario FOREIGN KEY (id_usuario_aceptacion) REFERENCES dbo.usuario(id_usuario)
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_advertencia')
          AND name = N'IX_semanal_carga_advertencia_carga'
    )
    BEGIN
        CREATE INDEX IX_semanal_carga_advertencia_carga
        ON dbo.semanal_carga_advertencia
        (
            id_semanal_carga,
            activo
        );
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_advertencia')
          AND name = N'IX_semanal_carga_advertencia_codigo'
    )
    BEGIN
        CREATE INDEX IX_semanal_carga_advertencia_codigo
        ON dbo.semanal_carga_advertencia(codigo);
    END;

    COMMIT TRANSACTION;

    SELECT
        OBJECT_SCHEMA_NAME(t.object_id) AS esquema,
        t.name AS tabla,
        i.name AS indice,
        i.type_desc AS tipo_indice
    FROM sys.tables t
    LEFT JOIN sys.indexes i
        ON i.object_id = t.object_id
       AND i.index_id > 0
    WHERE t.object_id = OBJECT_ID(N'dbo.semanal_carga_advertencia')
    ORDER BY i.index_id;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
GO

GO

-- Fuente: semanal/ajustePeriodoMensualAcumulativo.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 53100, 'No existe dbo.semanal_carga.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.semanal_carga')
          AND name = N'CK_semanal_carga_fechas_tramo'
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga
        DROP CONSTRAINT CK_semanal_carga_fechas_tramo;
    END;

    ALTER TABLE dbo.semanal_carga WITH CHECK
    ADD CONSTRAINT CK_semanal_carga_fechas_tramo
    CHECK
    (
        fecha_inicio_tramo <= fecha_fin_tramo
        AND MONTH(fecha_inicio_tramo) = mes_corte
        AND MONTH(fecha_fin_tramo) = mes_corte
        AND YEAR(fecha_inicio_tramo) = anio_corte
        AND YEAR(fecha_fin_tramo) = anio_corte
    );

    ALTER TABLE dbo.semanal_carga
    CHECK CONSTRAINT CK_semanal_carga_fechas_tramo;

    COMMIT TRANSACTION;

    PRINT N'Periodo mensual acumulativo habilitado correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

GO

-- Fuente: semanal/cargaAcumulativaPorBloque.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 52200, 'No existe dbo.semanal_carga. Ejecute primero la estructura del módulo semanal.', 1;
    END;

    IF OBJECT_ID(N'dbo.catalogo_entidad_federativa', N'U') IS NULL
    BEGIN
        THROW 52201, 'No existe dbo.catalogo_entidad_federativa.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga_bloque
        (
            id_semanal_carga_bloque BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            id_entidad_federativa TINYINT NOT NULL,
            anio_semana SMALLINT NOT NULL,
            numero_semana TINYINT NOT NULL,
            fecha_inicio_semana DATE NOT NULL,
            fecha_fin_semana DATE NOT NULL,
            anio_corte SMALLINT NOT NULL,
            mes_corte TINYINT NOT NULL,
            fecha_inicio_tramo DATE NOT NULL,
            fecha_fin_tramo DATE NOT NULL,
            total_carpetas INT NOT NULL CONSTRAINT DF_semanal_carga_bloque_carpetas DEFAULT (0),
            total_delitos INT NOT NULL CONSTRAINT DF_semanal_carga_bloque_delitos DEFAULT (0),
            total_victimas INT NOT NULL CONSTRAINT DF_semanal_carga_bloque_victimas DEFAULT (0),
            reemplaza_informacion BIT NOT NULL CONSTRAINT DF_semanal_carga_bloque_reemplaza DEFAULT (0),
            estado NVARCHAR(50) NOT NULL CONSTRAINT DF_semanal_carga_bloque_estado DEFAULT (N'VALIDADO_PENDIENTE'),
            fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_carga_bloque_fecha DEFAULT (SYSDATETIME()),
            activo BIT NOT NULL CONSTRAINT DF_semanal_carga_bloque_activo DEFAULT (1),

            CONSTRAINT PK_semanal_carga_bloque
                PRIMARY KEY (id_semanal_carga_bloque),

            CONSTRAINT UQ_semanal_carga_bloque_carga_periodo
                UNIQUE
                (
                    id_semanal_carga,
                    anio_semana,
                    numero_semana,
                    anio_corte,
                    mes_corte
                ),

            CONSTRAINT FK_semanal_carga_bloque_carga
                FOREIGN KEY (id_semanal_carga)
                REFERENCES dbo.semanal_carga(id_semanal_carga),

            CONSTRAINT FK_semanal_carga_bloque_entidad
                FOREIGN KEY (id_entidad_federativa)
                REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),

            CONSTRAINT CK_semanal_carga_bloque_anio_semana
                CHECK (anio_semana BETWEEN 2000 AND 9999),

            CONSTRAINT CK_semanal_carga_bloque_numero_semana
                CHECK (numero_semana BETWEEN 1 AND 53),

            CONSTRAINT CK_semanal_carga_bloque_anio_corte
                CHECK (anio_corte BETWEEN 2000 AND 9999),

            CONSTRAINT CK_semanal_carga_bloque_mes_corte
                CHECK (mes_corte BETWEEN 1 AND 12),

            CONSTRAINT CK_semanal_carga_bloque_totales
                CHECK
                (
                    total_carpetas >= 0
                    AND total_delitos >= 0
                    AND total_victimas >= 0
                ),

            CONSTRAINT CK_semanal_carga_bloque_fechas
                CHECK
                (
                    DATEDIFF(DAY, fecha_inicio_semana, fecha_fin_semana) = 6
                    AND fecha_inicio_tramo BETWEEN fecha_inicio_semana AND fecha_fin_semana
                    AND fecha_fin_tramo BETWEEN fecha_inicio_semana AND fecha_fin_semana
                    AND fecha_inicio_tramo <= fecha_fin_tramo
                    AND YEAR(fecha_inicio_tramo) = anio_corte
                    AND YEAR(fecha_fin_tramo) = anio_corte
                    AND MONTH(fecha_inicio_tramo) = mes_corte
                    AND MONTH(fecha_fin_tramo) = mes_corte
                )
        );
    END;

    INSERT INTO dbo.semanal_carga_bloque
    (
        id_semanal_carga,
        id_entidad_federativa,
        anio_semana,
        numero_semana,
        fecha_inicio_semana,
        fecha_fin_semana,
        anio_corte,
        mes_corte,
        fecha_inicio_tramo,
        fecha_fin_tramo,
        total_carpetas,
        total_delitos,
        total_victimas,
        reemplaza_informacion,
        estado,
        fecha_registro,
        activo
    )
    SELECT
        sc.id_semanal_carga,
        sc.id_entidad_federativa,
        sc.anio_semana,
        sc.numero_semana,
        sc.fecha_inicio_semana,
        sc.fecha_fin_semana,
        sc.anio_corte,
        sc.mes_corte,
        sc.fecha_inicio_tramo,
        sc.fecha_fin_tramo,
        sc.total_carpetas_incluidas,
        sc.total_delitos_incluidos,
        sc.total_victimas_incluidas,
        CASE
            WHEN sc.tipo_carga = N'ACTUALIZACION' THEN 1
            ELSE 0
        END,
        sc.estado,
        sc.fecha_validacion,
        sc.activo
    FROM dbo.semanal_carga sc
    WHERE sc.id_entidad_federativa IS NOT NULL
      AND sc.tipo_carga IN (N'CARGA_INICIAL', N'ACTUALIZACION')
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.semanal_carga_bloque bloque
          WHERE bloque.id_semanal_carga = sc.id_semanal_carga
            AND bloque.anio_semana = sc.anio_semana
            AND bloque.numero_semana = sc.numero_semana
            AND bloque.anio_corte = sc.anio_corte
            AND bloque.mes_corte = sc.mes_corte
      );

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'IX_semanal_carga_bloque_entidad_periodo'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_semanal_carga_bloque_entidad_periodo
        ON dbo.semanal_carga_bloque
        (
            id_entidad_federativa,
            anio_corte,
            mes_corte,
            fecha_inicio_tramo,
            fecha_fin_tramo
        )
        INCLUDE
        (
            id_semanal_carga,
            anio_semana,
            numero_semana,
            reemplaza_informacion,
            estado
        )
        WHERE activo = 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'UX_semanal_carga_bloque_pendiente'
    )
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_bloque_pendiente
        ON dbo.semanal_carga_bloque
        (
            id_entidad_federativa,
            anio_semana,
            numero_semana,
            anio_corte,
            mes_corte
        )
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          );
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;

SELECT
    OBJECT_SCHEMA_NAME(object_id) AS esquema,
    name AS tabla,
    create_date AS fecha_creacion
FROM sys.tables
WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque');

SELECT
    COUNT_BIG(DISTINCT sc.id_semanal_carga) AS cargas_semanales,
    COUNT_BIG(bloque.id_semanal_carga_bloque) AS bloques_registrados,
    COUNT_BIG
    (
        DISTINCT CASE
            WHEN bloque.id_semanal_carga_bloque IS NULL
                THEN sc.id_semanal_carga
        END
    ) AS cargas_sin_bloque
FROM dbo.semanal_carga sc
LEFT JOIN dbo.semanal_carga_bloque bloque
    ON bloque.id_semanal_carga = sc.id_semanal_carga
WHERE sc.tipo_carga IN (N'CARGA_INICIAL', N'ACTUALIZACION');

SELECT
    name AS indice,
    is_unique,
    has_filter,
    filter_definition
FROM sys.indexes
WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
ORDER BY index_id;

GO

-- Fuente: semanal/ajustePropiedadEntidadDelito.sql
USE siiid2;
GO

SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
    THROW 53400, 'No existe dbo.semanal_carga_bloque.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1
    )
    BEGIN
        SELECT
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte,
            COUNT(*) AS bloques_pendientes,
            COUNT(DISTINCT id_usuario_carga) AS usuarios_distintos
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1;

        THROW 53401, 'Existen bloques pendientes duplicados para la misma entidad, delito y periodo.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'UX_semanal_carga_bloque_pendiente'
    )
    BEGIN
        DROP INDEX UX_semanal_carga_bloque_pendiente
        ON dbo.semanal_carga_bloque;
    END;

    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_bloque_pendiente
    ON dbo.semanal_carga_bloque
    (
        id_entidad_federativa,
        id_delito,
        fecha_inicio_semana,
        anio_corte,
        mes_corte
    )
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      );

    COMMIT TRANSACTION;

    PRINT N'Propiedad semanal corregida: entidad + delito + periodo, independientemente del usuario.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    indice.name,
    indice.is_unique,
    indice.filter_definition,
    STRING_AGG(columna.name, N', ') WITHIN GROUP (ORDER BY indice_columna.key_ordinal) AS columnas
FROM sys.indexes indice
INNER JOIN sys.index_columns indice_columna
    ON indice_columna.object_id = indice.object_id
   AND indice_columna.index_id = indice.index_id
   AND indice_columna.key_ordinal > 0
INNER JOIN sys.columns columna
    ON columna.object_id = indice_columna.object_id
   AND columna.column_id = indice_columna.column_id
WHERE indice.object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
  AND indice.name = N'UX_semanal_carga_bloque_pendiente'
GROUP BY
    indice.name,
    indice.is_unique,
    indice.filter_definition;
GO

GO

-- Fuente: semanal/ajusteOperacionPendientePorUsuario.sql
USE siiid2;
GO

SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
BEGIN
    THROW 53200, 'No existe dbo.semanal_carga.', 1;
END;
GO

IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
BEGIN
    THROW 53201, 'No existe dbo.semanal_carga_bloque.', 1;
END;
GO

/*
    Este ALTER debe ir en un lote independiente.
    Por eso hay un GO inmediatamente después.
*/
IF COL_LENGTH(N'dbo.semanal_carga_bloque', N'id_usuario_carga') IS NULL
BEGIN
    ALTER TABLE dbo.semanal_carga_bloque
    ADD id_usuario_carga INT NULL;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE bloque
    SET bloque.id_usuario_carga = carga.id_usuario_carga
    FROM dbo.semanal_carga_bloque bloque
    INNER JOIN dbo.semanal_carga carga
        ON carga.id_semanal_carga = bloque.id_semanal_carga
    WHERE bloque.id_usuario_carga IS NULL
       OR bloque.id_usuario_carga <> carga.id_usuario_carga;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga_bloque
        WHERE id_usuario_carga IS NULL
    )
    BEGIN
        THROW 53202, 'Existen bloques sin usuario propietario.', 1;
    END;

    ALTER TABLE dbo.semanal_carga_bloque
    ALTER COLUMN id_usuario_carga INT NOT NULL;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'FK_semanal_carga_bloque_usuario'
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga_bloque WITH CHECK
        ADD CONSTRAINT FK_semanal_carga_bloque_usuario
            FOREIGN KEY (id_usuario_carga)
            REFERENCES dbo.usuario(id_usuario);

        ALTER TABLE dbo.semanal_carga_bloque
        CHECK CONSTRAINT FK_semanal_carga_bloque_usuario;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana
        HAVING COUNT(*) > 1
    )
    BEGIN
        SELECT
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana,
            COUNT(*) AS operaciones_pendientes
        FROM dbo.semanal_carga
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana
        HAVING COUNT(*) > 1;

        THROW 53203, 'Existen operaciones pendientes duplicadas para el mismo usuario.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1
    )
    BEGIN
        SELECT
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana,
            anio_corte,
            mes_corte,
            COUNT(*) AS bloques_pendientes
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_entidad_federativa,
            id_usuario_carga,
            anio_semana,
            numero_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1;

        THROW 53204, 'Existen bloques pendientes duplicados para el mismo usuario.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
          AND name = N'UX_semanal_carga_operacion_pendiente'
    )
    BEGIN
        DROP INDEX UX_semanal_carga_operacion_pendiente
        ON dbo.semanal_carga;
    END;

    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_operacion_pendiente
    ON dbo.semanal_carga
    (
        id_entidad_federativa,
        id_usuario_carga,
        anio_semana,
        numero_semana
    )
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      );

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'UX_semanal_carga_bloque_pendiente'
    )
    BEGIN
        DROP INDEX UX_semanal_carga_bloque_pendiente
        ON dbo.semanal_carga_bloque;
    END;

    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_bloque_pendiente
    ON dbo.semanal_carga_bloque
    (
        id_entidad_federativa,
        id_usuario_carga,
        anio_semana,
        numero_semana,
        anio_corte,
        mes_corte
    )
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      );

    COMMIT TRANSACTION;

    PRINT N'Protección de operaciones preliminares separada correctamente por usuario.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

SELECT
    tabla.name AS tabla,
    indice.name AS indice,
    indice.is_unique,
    indice.has_filter,
    indice.filter_definition
FROM sys.indexes indice
INNER JOIN sys.tables tabla
    ON tabla.object_id = indice.object_id
WHERE indice.name IN
(
    N'UX_semanal_carga_operacion_pendiente',
    N'UX_semanal_carga_bloque_pendiente'
)
ORDER BY tabla.name, indice.name;
GO

SELECT
    columna.name,
    tipo.name AS tipo,
    columna.max_length,
    columna.is_nullable
FROM sys.columns columna
INNER JOIN sys.types tipo
    ON tipo.user_type_id = columna.user_type_id
WHERE columna.object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
  AND columna.name = N'id_usuario_carga';
GO

GO

-- Fuente: semanal/ajusteOperacionPendientePorDelito.sql
USE siiid2;
GO

SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    THROW 53300, 'No existe dbo.semanal_carga.', 1;
GO

IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
    THROW 53301, 'No existe dbo.semanal_carga_bloque.', 1;
GO

IF COL_LENGTH(N'dbo.semanal_carga', N'id_delito') IS NULL
    THROW 53302, 'No existe semanal_carga.id_delito.', 1;
GO

IF COL_LENGTH(N'dbo.semanal_carga_bloque', N'id_delito') IS NULL
BEGIN
    ALTER TABLE dbo.semanal_carga_bloque
    ADD id_delito INT NULL;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE bloque
    SET bloque.id_delito = carga.id_delito
    FROM dbo.semanal_carga_bloque bloque
    INNER JOIN dbo.semanal_carga carga
        ON carga.id_semanal_carga = bloque.id_semanal_carga
    WHERE carga.id_delito IS NOT NULL
      AND
      (
          bloque.id_delito IS NULL
          OR bloque.id_delito <> carga.id_delito
      );

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND id_delito IS NULL
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
    )
    BEGIN
        THROW 53303, 'Existen bloques pendientes sin delito asociado.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'FK_semanal_carga_bloque_delito'
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga_bloque WITH CHECK
        ADD CONSTRAINT FK_semanal_carga_bloque_delito
            FOREIGN KEY (id_delito)
            REFERENCES dbo.catalogo_delito(id_delito);

        ALTER TABLE dbo.semanal_carga_bloque
        CHECK CONSTRAINT FK_semanal_carga_bloque_delito;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'CK_semanal_carga_bloque_delito_pendiente'
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga_bloque WITH CHECK
        ADD CONSTRAINT CK_semanal_carga_bloque_delito_pendiente
        CHECK
        (
            activo = 0
            OR estado NOT IN
            (
                N'VALIDADO_PENDIENTE',
                N'VALIDADO_PENDIENTE_ACTUALIZACION',
                N'PENDIENTE_APROBACION'
            )
            OR id_delito IS NOT NULL
        );
    END;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_usuario_carga,
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1
    )
    BEGIN
        SELECT
            id_usuario_carga,
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte,
            COUNT(*) AS bloques_pendientes
        FROM dbo.semanal_carga_bloque
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          )
        GROUP BY
            id_usuario_carga,
            id_entidad_federativa,
            id_delito,
            fecha_inicio_semana,
            anio_corte,
            mes_corte
        HAVING COUNT(*) > 1;

        THROW 53304, 'Existen bloques pendientes duplicados.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
          AND name = N'UX_semanal_carga_operacion_pendiente'
    )
    BEGIN
        DROP INDEX UX_semanal_carga_operacion_pendiente
        ON dbo.semanal_carga;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'UX_semanal_carga_bloque_pendiente'
    )
    BEGIN
        DROP INDEX UX_semanal_carga_bloque_pendiente
        ON dbo.semanal_carga_bloque;
    END;

    CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_bloque_pendiente
    ON dbo.semanal_carga_bloque
    (
        id_usuario_carga,
        id_entidad_federativa,
        id_delito,
        fecha_inicio_semana,
        anio_corte,
        mes_corte
    )
    WHERE activo = 1
      AND estado IN
      (
          N'VALIDADO_PENDIENTE',
          N'VALIDADO_PENDIENTE_ACTUALIZACION',
          N'PENDIENTE_APROBACION'
      );

    COMMIT TRANSACTION;

    PRINT N'Protección pendiente corregida por bloque lunes-domingo y delito.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

GO

-- Fuente: semanal/migrarConfiguracionDelitosAModalidades.sql
USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_configuracion_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga_delito_configurado', N'U') IS NULL
    BEGIN
        THROW 52100, 'No existen las tablas de configuración semanal que deben migrarse.', 1;
    END;

    DECLARE @ConfiguracionPorDelito BIT = CASE WHEN COL_LENGTH(N'dbo.semanal_configuracion_delito', N'id_delito') IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @ConfiguracionPorModalidad BIT = CASE WHEN COL_LENGTH(N'dbo.semanal_configuracion_delito', N'id_modalidad_delito') IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @CargaPorDelito BIT = CASE WHEN COL_LENGTH(N'dbo.semanal_carga_delito_configurado', N'id_delito') IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @CargaPorModalidad BIT = CASE WHEN COL_LENGTH(N'dbo.semanal_carga_delito_configurado', N'id_modalidad_delito') IS NOT NULL THEN 1 ELSE 0 END;

    IF @ConfiguracionPorModalidad = 1 AND @CargaPorModalidad = 1 AND @ConfiguracionPorDelito = 0 AND @CargaPorDelito = 0
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'La configuración semanal ya trabaja por modalidad. No se realizaron cambios.';
        RETURN;
    END;

    IF @ConfiguracionPorDelito = 0 OR @CargaPorDelito = 0 OR @ConfiguracionPorModalidad = 1 OR @CargaPorModalidad = 1
    BEGIN
        THROW 52101, 'La estructura semanal está en un estado mixto y no es seguro migrarla automáticamente.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_configuracion_delito_modalidad_nueva', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo.semanal_carga_delito_configurado_modalidad_nueva', N'U') IS NOT NULL
    BEGIN
        THROW 52102, 'Existen tablas temporales de una migración anterior. Revise su estado antes de continuar.', 1;
    END;

    CREATE TABLE dbo.semanal_configuracion_delito_modalidad_nueva
    (
        id_semanal_configuracion_delito INT IDENTITY(1,1) NOT NULL,
        id_modalidad_delito INT NOT NULL,
        es_obligatorio BIT NOT NULL CONSTRAINT DF_scd_modalidad_nueva_obligatorio DEFAULT (0),
        conservar_entre_periodos BIT NOT NULL CONSTRAINT DF_scd_modalidad_nueva_conservar DEFAULT (0),
        orden SMALLINT NOT NULL CONSTRAINT DF_scd_modalidad_nueva_orden DEFAULT (0),
        fecha_alta DATETIME2(0) NOT NULL CONSTRAINT DF_scd_modalidad_nueva_fecha_alta DEFAULT (SYSDATETIME()),
        fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_scd_modalidad_nueva_fecha_modificacion DEFAULT (SYSDATETIME()),
        id_usuario_modificacion INT NULL,
        activo BIT NOT NULL CONSTRAINT DF_scd_modalidad_nueva_activo DEFAULT (1),
        CONSTRAINT PK_scd_modalidad_nueva PRIMARY KEY (id_semanal_configuracion_delito),
        CONSTRAINT UQ_scd_modalidad_nueva UNIQUE (id_modalidad_delito),
        CONSTRAINT FK_scd_modalidad_nueva_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.catalogo_modalidad_delito(id_modalidad_delito),
        CONSTRAINT FK_scd_modalidad_nueva_usuario FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT CK_scd_modalidad_nueva_obligatorio CHECK (es_obligatorio = 0 OR activo = 1)
    );

    INSERT INTO dbo.semanal_configuracion_delito_modalidad_nueva
    (
        id_modalidad_delito,
        es_obligatorio,
        conservar_entre_periodos,
        orden,
        fecha_alta,
        fecha_modificacion,
        id_usuario_modificacion,
        activo
    )
    SELECT
        md.id_modalidad_delito,
        configuracion.es_obligatorio,
        configuracion.conservar_entre_periodos,
        CONVERT(SMALLINT, ROW_NUMBER() OVER (ORDER BY CASE WHEN configuracion.activo = 1 THEN 0 ELSE 1 END, configuracion.orden, md.clave4)),
        configuracion.fecha_alta,
        configuracion.fecha_modificacion,
        configuracion.id_usuario_modificacion,
        configuracion.activo
    FROM dbo.semanal_configuracion_delito configuracion
    INNER JOIN dbo.catalogo_subtipo_delito sd ON sd.id_delito = configuracion.id_delito
    INNER JOIN dbo.catalogo_modalidad_delito md ON md.id_subtipo_delito = sd.id_subtipo_delito;

    DECLARE @ModalidadesExtorsion TABLE (id_modalidad_delito INT NOT NULL PRIMARY KEY, orden SMALLINT NOT NULL);

    INSERT INTO @ModalidadesExtorsion (id_modalidad_delito, orden)
    SELECT md.id_modalidad_delito, CONVERT(SMALLINT, ROW_NUMBER() OVER (ORDER BY md.clave4))
    FROM dbo.catalogo_modalidad_delito md
    INNER JOIN dbo.catalogo_subtipo_delito sd ON sd.id_subtipo_delito = md.id_subtipo_delito AND sd.activo = 1
    INNER JOIN dbo.catalogo_delito cd ON cd.id_delito = sd.id_delito AND cd.activo = 1
    WHERE cd.clave2 = N'4.04'
      AND md.activo = 1;

    IF NOT EXISTS (SELECT 1 FROM @ModalidadesExtorsion)
    BEGIN
        THROW 52103, 'No se encontraron modalidades activas de Extorsión para la clave 4.04.', 1;
    END;

    UPDATE configuracion
    SET configuracion.es_obligatorio = 1,
        configuracion.conservar_entre_periodos = 1,
        configuracion.orden = extorsion.orden,
        configuracion.fecha_modificacion = SYSDATETIME(),
        configuracion.activo = 1
    FROM dbo.semanal_configuracion_delito_modalidad_nueva configuracion
    INNER JOIN @ModalidadesExtorsion extorsion ON extorsion.id_modalidad_delito = configuracion.id_modalidad_delito;

    INSERT INTO dbo.semanal_configuracion_delito_modalidad_nueva (id_modalidad_delito, es_obligatorio, conservar_entre_periodos, orden, activo)
    SELECT extorsion.id_modalidad_delito, 1, 1, extorsion.orden, 1
    FROM @ModalidadesExtorsion extorsion
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.semanal_configuracion_delito_modalidad_nueva configuracion
        WHERE configuracion.id_modalidad_delito = extorsion.id_modalidad_delito
    );

    CREATE TABLE dbo.semanal_carga_delito_configurado_modalidad_nueva
    (
        id_semanal_carga_delito_configurado BIGINT IDENTITY(1,1) NOT NULL,
        id_semanal_carga BIGINT NOT NULL,
        id_modalidad_delito INT NOT NULL,
        es_obligatorio BIT NOT NULL,
        conservar_entre_periodos BIT NOT NULL,
        orden SMALLINT NOT NULL,
        fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_sccdm_nueva_fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_sccdm_nueva PRIMARY KEY (id_semanal_carga_delito_configurado),
        CONSTRAINT UQ_sccdm_nueva UNIQUE (id_semanal_carga, id_modalidad_delito),
        CONSTRAINT FK_sccdm_nueva_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
        CONSTRAINT FK_sccdm_nueva_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.catalogo_modalidad_delito(id_modalidad_delito)
    );

    INSERT INTO dbo.semanal_carga_delito_configurado_modalidad_nueva
    (
        id_semanal_carga,
        id_modalidad_delito,
        es_obligatorio,
        conservar_entre_periodos,
        orden,
        fecha_registro
    )
    SELECT
         configuracion.id_semanal_carga,
        md.id_modalidad_delito,
        configuracion.es_obligatorio,
        configuracion.conservar_entre_periodos,
        CONVERT(SMALLINT, ROW_NUMBER() OVER (PARTITION BY configuracion.id_semanal_carga ORDER BY configuracion.orden, md.clave4)),
        configuracion.fecha_registro
    FROM dbo.semanal_carga_delito_configurado configuracion
    INNER JOIN dbo.catalogo_subtipo_delito sd ON sd.id_delito = configuracion.id_delito
    INNER JOIN dbo.catalogo_modalidad_delito md ON md.id_subtipo_delito = sd.id_subtipo_delito;

    IF OBJECT_ID(N'dbo.semanal_delito', N'U') IS NOT NULL
       AND EXISTS
       (
           SELECT 1
           FROM dbo.semanal_delito delito
           LEFT JOIN dbo.semanal_carga_delito_configurado_modalidad_nueva configuracion
             ON configuracion.id_semanal_carga = delito.id_semanal_carga
            AND configuracion.id_modalidad_delito = delito.id_modalidad_delito
           WHERE configuracion.id_semanal_carga IS NULL
       )
    BEGIN
        THROW 52104, 'Existen delitos semanales cuya modalidad no estaba incluida en la configuración de su carga.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_delito_historico', N'U') IS NOT NULL
       AND EXISTS
       (
           SELECT 1
           FROM dbo.semanal_delito_historico delito
           LEFT JOIN dbo.semanal_carga_delito_configurado_modalidad_nueva configuracion
             ON configuracion.id_semanal_carga = delito.id_semanal_carga
            AND configuracion.id_modalidad_delito = delito.id_modalidad_delito
           WHERE configuracion.id_semanal_carga IS NULL
       )
    BEGIN
        THROW 52105, 'Existen delitos históricos semanales cuya modalidad no estaba incluida en la configuración de su carga.', 1;
    END;

    IF OBJECT_ID(N'dbo.FK_semanal_delito_configurado', N'F') IS NOT NULL ALTER TABLE dbo.semanal_delito DROP CONSTRAINT FK_semanal_delito_configurado;
    IF OBJECT_ID(N'dbo.FK_semanal_delito_historico_configurado', N'F') IS NOT NULL ALTER TABLE dbo.semanal_delito_historico DROP CONSTRAINT FK_semanal_delito_historico_configurado;

    DROP TABLE dbo.semanal_carga_delito_configurado;
    DROP TABLE dbo.semanal_configuracion_delito;

    EXEC sys.sp_rename N'dbo.semanal_configuracion_delito_modalidad_nueva', N'semanal_configuracion_delito';
    EXEC sys.sp_rename N'dbo.semanal_carga_delito_configurado_modalidad_nueva', N'semanal_carga_delito_configurado';

    IF OBJECT_ID(N'dbo.semanal_delito', N'U') IS NOT NULL
    BEGIN
        ALTER TABLE dbo.semanal_delito WITH CHECK ADD CONSTRAINT FK_semanal_delito_configurado FOREIGN KEY (id_semanal_carga, id_modalidad_delito) REFERENCES dbo.semanal_carga_delito_configurado(id_semanal_carga, id_modalidad_delito);
    END;

    IF OBJECT_ID(N'dbo.semanal_delito_historico', N'U') IS NOT NULL
    BEGIN
        ALTER TABLE dbo.semanal_delito_historico WITH CHECK ADD CONSTRAINT FK_semanal_delito_historico_configurado FOREIGN KEY (id_semanal_carga, id_modalidad_delito) REFERENCES dbo.semanal_carga_delito_configurado(id_semanal_carga, id_modalidad_delito);
    END;

    COMMIT TRANSACTION;

    SELECT
        COL_LENGTH(N'dbo.semanal_configuracion_delito', N'id_modalidad_delito') AS configuracion_por_modalidad,
        COL_LENGTH(N'dbo.semanal_carga_delito_configurado', N'id_modalidad_delito') AS carga_por_modalidad,
        (SELECT COUNT(*) FROM dbo.semanal_configuracion_delito WHERE activo = 1) AS modalidades_seleccionadas,
        (SELECT COUNT(*) FROM dbo.semanal_configuracion_delito WHERE activo = 1 AND es_obligatorio = 1) AS modalidades_obligatorias;

    PRINT 'Configuración semanal migrada correctamente al nivel de modalidad.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO