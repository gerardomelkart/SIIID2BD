USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Sustituir ambos valores por los de SU cuenta en este ambiente. No reutilizar un ID de desarrollo en producción.
DECLARE @IdUsuario INT = NULL;
DECLARE @Usuario NVARCHAR(50) = NULL;
DECLARE @Motivo NVARCHAR(500) = N'Asignación inicial de administrador del sistema por el responsable de la BD';
IF DB_NAME() <> N'siiid2' THROW 52600, 'Base incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sistema_administrador', N'U') IS NULL THROW 52600, 'Ejecute primero 01_estructura.sql.', 1;
IF @IdUsuario IS NULL OR NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
BEGIN
    SELECT u.id_usuario, u.usuario, u.nombre, u.primer_apellido, r.rol
    FROM dbo.usuario u JOIN dbo.roles r ON r.id_rol = u.id_rol
    WHERE u.activo = 1 AND r.activo = 1 AND r.rol = N'SUPER_USUARIO';
    THROW 52602, 'Complete IdUsuario y Usuario con la cuenta que administrará el sistema. No se asignó ningún permiso.', 1;
END;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Lock INT;
    EXEC @Lock = sys.sp_getapplock @Resource = N'SIIID2:CONFIGURACION', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @Lock < 0 THROW 52601, 'No se pudo bloquear la configuración.', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.usuario u WITH (HOLDLOCK) JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol
        WHERE u.id_usuario = @IdUsuario AND u.usuario = @Usuario AND u.activo = 1 AND r.activo = 1 AND r.rol = N'SUPER_USUARIO'
    ) THROW 52603, 'El ID y usuario no corresponden a un superusuario activo.', 1;
    DECLARE @Anterior BIT = (SELECT activo FROM dbo.sistema_administrador WITH (UPDLOCK, HOLDLOCK) WHERE id_usuario = @IdUsuario);
    IF @Anterior IS NULL INSERT dbo.sistema_administrador (id_usuario) VALUES (@IdUsuario);
    ELSE IF @Anterior = 0 UPDATE dbo.sistema_administrador SET activo = 1 WHERE id_usuario = @IdUsuario;
    IF ISNULL(@Anterior, 0) = 0
    BEGIN
        UPDATE dbo.sistema_configuracion_version SET version = version + 1, fecha_modificacion = SYSUTCDATETIME() WHERE id = 1;
        INSERT dbo.sistema_configuracion_bitacora (id_usuario, modulo, clave, valor_anterior, valor_nuevo, motivo, version)
        SELECT @IdUsuario, N'SISTEMA', N'ADMINISTRADOR_ASIGNADO', @Anterior, 1, @Motivo, version FROM dbo.sistema_configuracion_version WHERE id = 1;
    END;
    COMMIT;
    SELECT @IdUsuario AS id_usuario, @Usuario AS usuario, CAST(1 AS BIT) AS administra_sistema;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;
