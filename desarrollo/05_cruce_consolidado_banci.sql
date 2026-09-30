-- Incremental sobre desarrollo/04_motivo_desaparicion_banci.sql.
-- Instalar con API y FrontEnd de esta entrega. No borra registros BANCI.
USE [siiid2];
GO
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_configuracion',N'U') IS NULL THROW 52600, 'Falta configuración del sistema.', 1;
IF OBJECT_ID(N'dbo.banci_cruce_mensual',N'U') IS NULL
CREATE TABLE dbo.banci_cruce_mensual (
    id_carga BIGINT NOT NULL CONSTRAINT PK_banci_cruce_mensual PRIMARY KEY,
    archivos_json NVARCHAR(MAX) NOT NULL,
    victimas_json NVARCHAR(MAX) NULL,
    fecha_cruce_utc DATETIME2(0) NULL,
    CONSTRAINT FK_banci_cruce_carga FOREIGN KEY (id_carga) REFERENCES dbo.carga(id_carga) ON DELETE CASCADE,
    CONSTRAINT CK_banci_cruce_archivos CHECK (ISJSON(archivos_json)=1),
    CONSTRAINT CK_banci_cruce_victimas CHECK (victimas_json IS NULL OR ISJSON(victimas_json)=1)
);
GO
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
        IF @Habilitado = 1 AND @Clave = N''CRUCE_BANCI'' AND NOT EXISTS (SELECT 1 FROM dbo.catalogo_modulo WHERE clave=N''BANCI'' AND activo=1)
            THROW 52606, ''Active BANCI antes de habilitar el cruce.'', 1;
        IF @Habilitado = 1 AND @Clave = N''RENAPO'' AND @Modulo IN (N''MENSUAL'', N''FEDERAL'') AND NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion WHERE id_modulo=@IdModulo AND clave=N''FEMINICIDIO_DATOS_ADICIONALES'' AND habilitado=1 AND disponible=1)
            THROW 52606, ''Active las reglas de feminicidio antes de habilitar RENAPO.'', 1;

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
        IF @Habilitado=0
        BEGIN
            UPDATE c SET habilitado=0
            OUTPUT m.clave, inserted.clave, deleted.habilitado INTO @Dependientes
            FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo
            WHERE c.habilitado=1 AND (
                (@Modulo=N''BANCI'' AND @Clave=N''MODULO_ACTIVO'' AND c.clave=N''CRUCE_BANCI'') OR
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
END;
';
GO
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @lock INT;
    EXEC @lock=sys.sp_getapplock @Resource=N'SIIID2:CONFIGURACION', @LockMode=N'Exclusive', @LockOwner=N'Transaction', @LockTimeout=10000;
    IF @lock<0 THROW 52601, 'Configuración ocupada. Reintente.', 1;
    UPDATE c SET disponible=1, descripcion=N'Cruce de carpetas, delitos de desaparición y víctimas con BANCI por entidad y periodo'
    FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo WHERE m.clave=N'MENSUAL' AND c.clave=N'CRUCE_BANCI';
    UPDATE c SET habilitado=0 FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo
    WHERE (c.clave=N'CRUCE_BANCI' AND NOT EXISTS (SELECT 1 FROM dbo.catalogo_modulo WHERE clave=N'BANCI' AND activo=1))
       OR (m.clave IN (N'MENSUAL',N'FEDERAL') AND c.clave=N'RENAPO' AND NOT EXISTS (SELECT 1 FROM dbo.sistema_configuracion p WHERE p.id_modulo=c.id_modulo AND p.clave=N'FEMINICIDIO_DATOS_ADICIONALES' AND p.habilitado=1 AND p.disponible=1));
    UPDATE dbo.sistema_configuracion_version SET version=version+1, fecha_modificacion=SYSUTCDATETIME() WHERE id=1;
    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
GO
