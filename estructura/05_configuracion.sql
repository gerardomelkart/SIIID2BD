-- REFERENCIA TECNICA: base y ajustes en secuencia; no ejecutar sobre una BD publicada.
-- No sustituye una exportación del esquema real. Revisar dependencias indicadas en README.

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/12_01_estructura.sql
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
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/13_02_procedimientos.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'siiid2' THROW 52600, 'Base incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_configuracion', N'U') IS NULL OR OBJECT_ID(N'dbo.sistema_administrador', N'U') IS NULL OR OBJECT_ID(N'dbo.sistema_configuracion_version', N'U') IS NULL OR OBJECT_ID(N'dbo.sistema_configuracion_bitacora', N'U') IS NULL THROW 52600, 'Ejecute primero 01_estructura.sql.', 1;
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

        IF @Clave = N''MODULO_ACTIVO''
        BEGIN
            SELECT @Anterior = activo FROM dbo.catalogo_modulo WHERE id_modulo = @IdModulo;
            IF @Modulo = N''BANCI'' AND @Habilitado = 1 AND (
                OBJECT_ID(N''dbo.sp_banci_procesar_carga_v2'', N''P'') IS NULL OR
                OBJECT_ID(N''dbo.sp_banci_confirmar_carga_v2'', N''P'') IS NULL OR
                OBJECT_ID(N''dbo.sp_banci_calcular_actualizacion_v2'', N''P'') IS NULL
            ) THROW 52606, ''Complete la instalación BANCI V2 antes de activarlo.'', 1;
            IF @Anterior <> @Habilitado UPDATE dbo.catalogo_modulo SET activo = @Habilitado WHERE id_modulo = @IdModulo;
        END
        ELSE
        BEGIN
            SELECT @Anterior = habilitado, @Disponible = disponible FROM dbo.sistema_configuracion WITH (UPDLOCK, HOLDLOCK) WHERE id_modulo = @IdModulo AND clave = @Clave;
            IF @Anterior IS NULL THROW 52605, ''Opción de configuración inexistente.'', 1;
            IF @Disponible = 0 THROW 52606, ''Esta funcionalidad todavía no está implementada.'', 1;
            IF @Anterior <> @Habilitado UPDATE dbo.sistema_configuracion SET habilitado = @Habilitado WHERE id_modulo = @IdModulo AND clave = @Clave;
        END;
        IF @Anterior <> @Habilitado
        BEGIN
            UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
            SELECT @Version = version FROM dbo.sistema_configuracion_version WHERE id = 1;
            INSERT dbo.sistema_configuracion_bitacora (id_usuario, modulo, clave, valor_anterior, valor_nuevo, motivo, version)
            VALUES (@IdUsuario, @Modulo, @Clave, @Anterior, @Habilitado, LTRIM(RTRIM(@Motivo)), @Version);
        END;
        COMMIT;
        SELECT @Version AS version, CAST(CASE WHEN @Anterior <> @Habilitado THEN 1 ELSE 0 END AS BIT) AS modificado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH;
END;
';
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/14_05_vincular_validaciones.sql
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


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/15_06_federal_feminicidio.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'siiid2' THROW 52600, 'Base incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_validacion_configuracion', N'U') IS NULL THROW 52600, 'Requiere configuración 01 a 05.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT;
    EXEC @Lock = sys.sp_getapplock @Resource=N'SIIID2:CONFIGURACION', @LockMode=N'Exclusive', @LockOwner=N'Transaction', @LockTimeout=10000;
    IF @Lock < 0 THROW 52601, 'Configuración ocupada. Reintente.', 1;
    DECLARE @IdModulo TINYINT = (SELECT id_modulo FROM dbo.catalogo_modulo WHERE clave = N'FEDERAL');
    IF @IdModulo IS NULL THROW 52605, 'Falta el módulo Federal.', 1;
    IF OBJECT_ID(N'dbo.federal_carga_tmp_victima', N'U') IS NULL THROW 52600, 'Falta federal_carga_tmp_victima.', 1;
    IF COL_LENGTH(N'dbo.federal_carga_tmp_victima', N'nombre_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_carga_tmp_victima ADD nombre_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_carga_tmp_victima', N'primer_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_carga_tmp_victima ADD primer_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_carga_tmp_victima', N'segundo_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_carga_tmp_victima ADD segundo_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_carga_tmp_victima', N'curp_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_carga_tmp_victima ADD curp_vicfem NVARCHAR(250) NULL;');
    IF OBJECT_ID(N'dbo.federal_victima', N'U') IS NULL THROW 52600, 'Falta federal_victima.', 1;
    IF COL_LENGTH(N'dbo.federal_victima', N'nombre_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima ADD nombre_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima', N'primer_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima ADD primer_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima', N'segundo_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima ADD segundo_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima', N'curp_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima ADD curp_vicfem NVARCHAR(250) NULL;');
    IF OBJECT_ID(N'dbo.federal_victima_historico', N'U') IS NULL THROW 52600, 'Falta federal_victima_historico.', 1;
    IF COL_LENGTH(N'dbo.federal_victima_historico', N'nombre_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima_historico ADD nombre_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima_historico', N'primer_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima_historico ADD primer_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima_historico', N'segundo_apellido_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima_historico ADD segundo_apellido_vicfem NVARCHAR(250) NULL;');
    IF COL_LENGTH(N'dbo.federal_victima_historico', N'curp_vicfem') IS NULL EXEC(N'ALTER TABLE dbo.federal_victima_historico ADD curp_vicfem NVARCHAR(250) NULL;');
    INSERT dbo.sistema_configuracion (id_modulo, clave, descripcion, habilitado, disponible)
    SELECT @IdModulo, v.clave, v.descripcion, 0, 1 FROM (VALUES
        (N'FEMINICIDIO_DATOS_ADICIONALES', N'Campos y reglas adicionales de víctimas de feminicidio'),
        (N'RENAPO', N'Consulta externa de CURP de víctimas de feminicidio en RENAPO')
    ) v(clave, descripcion)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion c WHERE c.id_modulo = @IdModulo AND c.clave = v.clave);
    IF @@ROWCOUNT > 0 UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/16_07_administradores.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() <> N'siiid2' THROW 52600, 'Base incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_validacion_configuracion', N'U') IS NULL THROW 52600, 'Requiere configuración 01 a 05.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT;
    EXEC @Lock = sys.sp_getapplock @Resource=N'SIIID2:CONFIGURACION', @LockMode=N'Exclusive', @LockOwner=N'Transaction', @LockTimeout=10000;
    IF @Lock < 0 THROW 52601, 'Configuración ocupada. Reintente.', 1;
    IF COL_LENGTH(N'dbo.sistema_configuracion_bitacora', N'id_usuario_objetivo') IS NULL EXEC(N'ALTER TABLE dbo.sistema_configuracion_bitacora ADD id_usuario_objetivo INT NULL CONSTRAINT FK_sistema_bitacora_objetivo REFERENCES dbo.usuario(id_usuario);');
    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_sistema_administrador_cambiar
    @IdUsuario INT, @IdUsuarioObjetivo INT, @Habilitado BIT, @VersionEsperada BIGINT, @Motivo NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 52600, ''Ejecute sin transacciones abiertas.'', 1;
    IF @IdUsuarioObjetivo IS NULL OR @Habilitado IS NULL OR @VersionEsperada IS NULL THROW 52602, ''Faltan usuario, estado o versión.'', 1;
    SET @Motivo = COALESCE(NULLIF(LTRIM(RTRIM(@Motivo)), N''''), N''Sin motivo reportado'');
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Lock INT, @Version BIGINT, @Anterior BIT;
        EXEC @Lock = sys.sp_getapplock @Resource=N''SIIID2:CONFIGURACION'', @LockMode=N''Exclusive'', @LockOwner=N''Transaction'', @LockTimeout=10000;
        IF @Lock < 0 THROW 52601, ''Configuración ocupada. Reintente.'', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.sistema_administrador a WITH (HOLDLOCK) JOIN dbo.usuario u WITH (HOLDLOCK) ON u.id_usuario = a.id_usuario JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol WHERE a.id_usuario = @IdUsuario AND a.activo = 1 AND u.activo = 1 AND r.activo = 1 AND r.rol = N''SUPER_USUARIO'')
            THROW 52603, ''No tiene permiso de administración del sistema.'', 1;
        SELECT @Version = version FROM dbo.sistema_configuracion_version WITH (UPDLOCK, HOLDLOCK) WHERE id = 1;
        IF @Version IS NULL OR @Version <> @VersionEsperada THROW 52604, ''La configuración cambió. Actualice antes de guardar.'', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.usuario u WITH (HOLDLOCK) JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol WHERE u.id_usuario = @IdUsuarioObjetivo AND u.activo = 1 AND r.activo = 1 AND r.rol = N''SUPER_USUARIO'')
            THROW 52605, ''El destino debe ser un superusuario activo.'', 1;
        IF @IdUsuario = @IdUsuarioObjetivo AND @Habilitado = 0 THROW 52606, ''No puede retirar su propio acceso desde esta pantalla.'', 1;
        SELECT @Anterior = activo FROM dbo.sistema_administrador WITH (UPDLOCK, HOLDLOCK) WHERE id_usuario = @IdUsuarioObjetivo;
        SET @Anterior = ISNULL(@Anterior, 0);
        IF @Anterior <> @Habilitado
        BEGIN
            IF @Habilitado = 0 AND NOT EXISTS (SELECT 1 FROM dbo.sistema_administrador a WITH (HOLDLOCK) JOIN dbo.usuario u WITH (HOLDLOCK) ON u.id_usuario = a.id_usuario JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol WHERE a.id_usuario <> @IdUsuarioObjetivo AND a.activo = 1 AND u.activo = 1 AND r.activo = 1 AND r.rol = N''SUPER_USUARIO'')
                THROW 52606, ''Debe conservar al menos un administrador activo.'', 1;
            IF EXISTS (SELECT 1 FROM dbo.sistema_administrador WHERE id_usuario = @IdUsuarioObjetivo) UPDATE dbo.sistema_administrador SET activo = @Habilitado WHERE id_usuario = @IdUsuarioObjetivo;
            ELSE INSERT dbo.sistema_administrador (id_usuario, activo) VALUES (@IdUsuarioObjetivo, @Habilitado);
            UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
            SELECT @Version = version FROM dbo.sistema_configuracion_version WHERE id = 1;
            INSERT dbo.sistema_configuracion_bitacora (id_usuario, id_usuario_objetivo, modulo, clave, valor_anterior, valor_nuevo, motivo, version)
            VALUES (@IdUsuario, @IdUsuarioObjetivo, N''SISTEMA'', N''ADMINISTRADOR_ACCESO'', @Anterior, @Habilitado, @Motivo, @Version);
        END;
        COMMIT;
        SELECT @Version AS version, CAST(CASE WHEN @Anterior <> @Habilitado THEN 1 ELSE 0 END AS BIT) AS modificado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        THROW;
    END CATCH;
END;
';
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/17_09_federal_cruce_banci_pendiente.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_configuracion', N'U') IS NULL THROW 52600, 'Falta la configuración del sistema.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT, @IdModulo TINYINT;
    EXEC @Lock = sys.sp_getapplock @Resource = N'SIIID2:CONFIGURACION', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @Lock < 0 THROW 52601, 'Configuración ocupada. Reintente.', 1;
    SELECT @IdModulo = id_modulo FROM dbo.catalogo_modulo WHERE clave = N'FEDERAL';
    IF @IdModulo IS NULL THROW 52600, 'Falta el módulo Federal.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion WHERE id_modulo = @IdModulo AND clave = N'CRUCE_BANCI')
    BEGIN
        INSERT dbo.sistema_configuracion (id_modulo, clave, descripcion, habilitado, disponible) VALUES (@IdModulo, N'CRUCE_BANCI', N'Cruce con BANCI: pendiente de implementación', 0, 0);
        UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
        IF @@ROWCOUNT <> 1 THROW 52600, 'Falta la versión de configuración.', 1;
    END;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
SELECT m.clave AS modulo, c.clave, c.habilitado, c.disponible FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo = c.id_modulo WHERE m.clave IN (N'MENSUAL', N'FEDERAL') AND c.clave = N'CRUCE_BANCI';
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/18_10_coordenadas_municipio.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_configuracion', N'U') IS NULL THROW 52600, 'Instale primero la configuración del sistema.', 1;
IF (SELECT COUNT(*) FROM dbo.catalogo_modulo WHERE clave IN (N'MENSUAL', N'SEMANAL', N'FEDERAL', N'BANCI')) <> 4 THROW 52600, 'Faltan módulos en el catálogo; instale BANCI antes.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT, @Nuevas INT;
    EXEC @Lock = sys.sp_getapplock @Resource = N'SIIID2:CONFIGURACION', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @Lock < 0 THROW 52601, 'Configuración ocupada. Reintente.', 1;
    INSERT dbo.sistema_configuracion (id_modulo, clave, descripcion, habilitado, disponible)
    SELECT m.id_modulo, N'COORDENADAS_MUNICIPIO', N'Coordenadas dentro del municipio: todos los delitos', 0, 1
    FROM dbo.catalogo_modulo m WHERE m.clave IN (N'MENSUAL', N'SEMANAL', N'FEDERAL', N'BANCI')
      AND NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion c WHERE c.id_modulo = m.id_modulo AND c.clave = N'COORDENADAS_MUNICIPIO');
    SET @Nuevas = @@ROWCOUNT;
    INSERT dbo.sistema_configuracion (id_modulo, clave, descripcion, habilitado, disponible)
    SELECT m.id_modulo, N'COORDENADAS_MUNICIPIO_HOMICIDIO_DOLOSO', N'Coordenadas dentro del municipio: solo homicidio doloso', 1, 1
    FROM dbo.catalogo_modulo m WHERE m.clave = N'SEMANAL'
      AND NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion c WHERE c.id_modulo = m.id_modulo AND c.clave = N'COORDENADAS_MUNICIPIO_HOMICIDIO_DOLOSO');
    SET @Nuevas += @@ROWCOUNT;
    IF @Nuevas > 0
    BEGIN
        UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
        IF @@ROWCOUNT <> 1 THROW 52600, 'Falta la versión de configuración.', 1;
    END;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
SELECT m.clave AS modulo, c.clave, c.habilitado, c.disponible FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo = c.id_modulo WHERE c.clave LIKE N'COORDENADAS_MUNICIPIO%';
GO
