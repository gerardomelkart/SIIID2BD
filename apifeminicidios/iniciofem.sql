USE [SIIID2];
GO

SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.api_feminicidios_usuario', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.api_feminicidios_usuario
    (
        id_usuario INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_api_feminicidios_usuario PRIMARY KEY,

        usuario NVARCHAR(100) NOT NULL,
        nombre NVARCHAR(200) NOT NULL,
        institucion NVARCHAR(200) NOT NULL,

        password_hash VARCHAR(60)
            COLLATE Latin1_General_100_BIN2 NOT NULL,

        habilitado BIT NOT NULL
            CONSTRAINT DF_api_feminicidios_usuario_habilitado
            DEFAULT (1),

        fecha_creacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_api_feminicidios_usuario_creacion
            DEFAULT (SYSUTCDATETIME()),

        fecha_modificacion DATETIME2(0) NULL,
        id_usuario_creacion INT NOT NULL,
        version ROWVERSION NOT NULL,

        CONSTRAINT UQ_api_feminicidios_usuario
            UNIQUE (usuario),

        CONSTRAINT CK_api_feminicidios_usuario_hash
            CHECK (
                DATALENGTH(password_hash) = 60
                AND LEFT(password_hash, 4) = '$2a$'
            ),

        CONSTRAINT FK_api_feminicidios_usuario_creador
            FOREIGN KEY (id_usuario_creacion)
            REFERENCES dbo.usuario(id_usuario)
    );
END;
GO