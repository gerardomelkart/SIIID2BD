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
