USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'siiid2' THROW 52600, 'Base incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_configuracion_version', N'U') IS NULL THROW 52600, 'Ejecute primero la instalación de configuración 01 a 04.', 1;
IF OBJECT_ID(N'dbo.sistema_validacion_configuracion', N'U') IS NULL
CREATE TABLE dbo.sistema_validacion_configuracion (
    modulo NVARCHAR(20) NOT NULL,
    tipo NVARCHAR(20) NOT NULL,
    referencia NVARCHAR(100) NOT NULL,
    id_usuario INT NOT NULL,
    version BIGINT NOT NULL,
    fecha_utc DATETIME2(0) NOT NULL CONSTRAINT DF_sistema_validacion_fecha DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_sistema_validacion_configuracion PRIMARY KEY (modulo, tipo, referencia),
    CONSTRAINT FK_sistema_validacion_usuario FOREIGN KEY (id_usuario) REFERENCES dbo.usuario(id_usuario),
    CONSTRAINT CK_sistema_validacion_version CHECK (version > 0)
);
-- No asignar artificialmente la versión actual a operaciones antiguas. Rechazar y validar de nuevo.
GO
