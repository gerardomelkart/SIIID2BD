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
