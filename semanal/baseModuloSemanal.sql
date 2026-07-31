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