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