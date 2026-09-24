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
