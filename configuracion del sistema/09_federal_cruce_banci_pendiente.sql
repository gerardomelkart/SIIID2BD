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
