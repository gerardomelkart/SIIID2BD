USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'siiid2' THROW 52600, 'Base incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.usuario', N'U') IS NULL OR OBJECT_ID(N'dbo.roles', N'U') IS NULL OR OBJECT_ID(N'dbo.catalogo_modulo', N'U') IS NULL THROW 52600, 'Falta la estructura base del sistema.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT;
    EXEC @Lock = sys.sp_getapplock @Resource = N'SIIID2:CONFIGURACION', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @Lock < 0 THROW 52601, 'No se pudo bloquear la configuración.', 1;

    IF OBJECT_ID(N'dbo.sistema_administrador', N'U') IS NULL
    CREATE TABLE dbo.sistema_administrador (
        id_usuario INT NOT NULL CONSTRAINT PK_sistema_administrador PRIMARY KEY,
        activo BIT NOT NULL CONSTRAINT DF_sistema_administrador_activo DEFAULT (1),
        fecha_alta DATETIME2(0) NOT NULL CONSTRAINT DF_sistema_administrador_fecha DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_sistema_administrador_usuario FOREIGN KEY (id_usuario) REFERENCES dbo.usuario(id_usuario)
    );

    IF OBJECT_ID(N'dbo.sistema_configuracion_version', N'U') IS NULL
    CREATE TABLE dbo.sistema_configuracion_version (
        id TINYINT NOT NULL CONSTRAINT PK_sistema_configuracion_version PRIMARY KEY,
        version BIGINT NOT NULL,
        fecha_modificacion DATETIME2(0) NOT NULL,
        CONSTRAINT CK_sistema_configuracion_version_id CHECK (id = 1),
        CONSTRAINT CK_sistema_configuracion_version_valor CHECK (version > 0)
    );

    IF OBJECT_ID(N'dbo.sistema_configuracion', N'U') IS NULL
    CREATE TABLE dbo.sistema_configuracion (
        id_modulo TINYINT NOT NULL,
        clave NVARCHAR(60) NOT NULL,
        descripcion NVARCHAR(250) NOT NULL,
        habilitado BIT NOT NULL,
        disponible BIT NOT NULL,
        CONSTRAINT PK_sistema_configuracion PRIMARY KEY (id_modulo, clave),
        CONSTRAINT FK_sistema_configuracion_modulo FOREIGN KEY (id_modulo) REFERENCES dbo.catalogo_modulo(id_modulo),
        CONSTRAINT CK_sistema_configuracion_disponible CHECK (disponible = 1 OR habilitado = 0)
    );

    IF OBJECT_ID(N'dbo.sistema_configuracion_bitacora', N'U') IS NULL
    CREATE TABLE dbo.sistema_configuracion_bitacora (
        id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_sistema_configuracion_bitacora PRIMARY KEY,
        fecha_utc DATETIME2(0) NOT NULL CONSTRAINT DF_sistema_configuracion_bitacora_fecha DEFAULT (SYSUTCDATETIME()),
        id_usuario INT NULL,
        ejecutor_sql NVARCHAR(128) NOT NULL CONSTRAINT DF_sistema_configuracion_bitacora_login DEFAULT (ORIGINAL_LOGIN()),
        modulo NVARCHAR(20) NOT NULL,
        clave NVARCHAR(60) NOT NULL,
        valor_anterior BIT NULL,
        valor_nuevo BIT NOT NULL,
        motivo NVARCHAR(500) NOT NULL,
        version BIGINT NOT NULL,
        CONSTRAINT FK_sistema_configuracion_bitacora_usuario FOREIGN KEY (id_usuario) REFERENCES dbo.usuario(id_usuario)
    );

    IF NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion_version WHERE id = 1)
        INSERT dbo.sistema_configuracion_version (id, version, fecha_modificacion) VALUES (1, 1, SYSUTCDATETIME());

    -- Sólo se añaden opciones faltantes. Nunca se sobrescriben decisiones existentes.
    -- Tampoco se crean módulos ni se cambia catalogo_modulo.activo.
    DECLARE @Opciones TABLE (modulo NVARCHAR(20), clave NVARCHAR(60), descripcion NVARCHAR(250), habilitado BIT, disponible BIT);
    INSERT @Opciones
    SELECT m.clave, o.clave, o.descripcion, 0, 1
    FROM dbo.catalogo_modulo m
    CROSS JOIN (VALUES
        (N'COORDENADAS_FORMATO_RANGO', N'Advertir formato y rango de coordenadas'),
        (N'COORDENADAS_SIN_INFORMACION', N'Advertir coordenadas sin información'),
        (N'COORDENADAS_CONCENTRACION', N'Advertir más de cinco delitos en el mismo punto')
    ) o(clave, descripcion)
    WHERE m.clave IN (N'MENSUAL', N'SEMANAL', N'FEDERAL', N'BANCI');
    INSERT @Opciones VALUES
        (N'MENSUAL', N'FEMINICIDIO_DATOS_ADICIONALES', N'Campos y reglas adicionales de víctimas de feminicidio', 1, 1),
        (N'MENSUAL', N'RENAPO', N'Consulta externa de CURP de víctimas de feminicidio en RENAPO', 1, 1),
        (N'BANCI', N'RENAPO', N'Consulta externa de CURP en RENAPO', 1, 1),
        (N'MENSUAL', N'CRUCE_BANCI', N'Cruce con BANCI: pendiente de implementación', 0, 0);

    INSERT dbo.sistema_configuracion (id_modulo, clave, descripcion, habilitado, disponible)
    SELECT m.id_modulo, o.clave, o.descripcion, o.habilitado, o.disponible
    FROM @Opciones o JOIN dbo.catalogo_modulo m ON m.clave = o.modulo
    WHERE NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion c WHERE c.id_modulo = m.id_modulo AND c.clave = o.clave);
    DECLARE @Nuevas INT = @@ROWCOUNT;
    IF @Nuevas > 0
    BEGIN
        UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
        INSERT dbo.sistema_configuracion_bitacora (modulo, clave, valor_nuevo, motivo, version)
        SELECT N'SISTEMA', N'INSTALACION', 1, CONCAT(N'Se añadieron ', @Nuevas, N' opciones sin modificar las existentes.'), version FROM dbo.sistema_configuracion_version WHERE id = 1;
    END;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
-- La comprobación municipio/coordenadas del Semanal permanece fuera de esta configuración.
