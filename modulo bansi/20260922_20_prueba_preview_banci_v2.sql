USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- PRUEBA OPCIONAL EN DESARROLLO. No confirma ninguna actualización. Todo termina en ROLLBACK.
-- Requiere un superusuario activo, BANCI activo y al menos una víctima activa existente.
IF @@TRANCOUNT <> 0 THROW 52590, 'Use una ventana sin transacciones abiertas.', 1;
DECLARE @Usuario INT = (SELECT MIN(u.id_usuario) FROM dbo.usuario u JOIN dbo.roles r ON r.id_rol = u.id_rol WHERE u.activo = 1 AND r.activo = 1 AND r.rol = N'SUPER_USUARIO');
DECLARE @Victima BIGINT = (SELECT MIN(id_banci_victima) FROM dbo.banci_vw_victimas_v2);
IF @Usuario IS NULL OR @Victima IS NULL THROW 52590, 'Faltan los datos mínimos de desarrollo para esta prueba.', 1;
DECLARE @Entidad TINYINT, @Codigo UNIQUEIDENTIFIER = NEWID(), @Datos NVARCHAR(MAX), @Huella1 VARCHAR(64), @Huella2 VARCHAR(64), @Aplicar NVARCHAR(MAX), @Cambios NVARCHAR(MAX), @Lock INT;
DECLARE @Observacion NVARCHAR(100) = CONCAT(N'PRUEBA TEMPORAL ', NEWID());
SELECT @Entidad = id_entidad_federativa FROM dbo.banci_vw_victimas_v2 WHERE id_banci_victima = @Victima;
SET @Datos = (SELECT no_banci, id_delito, id_vicf, COALESCE(NULLIF(LTRIM(RTRIM(folio_rnpdno)), N''), N'PRUEBA-TEMPORAL-RNPDNO') AS folio_rnpdno,
    N'' AS pro_apellido, @Observacion AS obs FROM dbo.banci_vw_victimas_v2 WHERE id_banci_victima = @Victima FOR JSON PATH);
DECLARE @Recurso NVARCHAR(255) = CONCAT(N'BANCI:ENTIDAD:', @Entidad);
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @Lock = sys.sp_getapplock @Resource = @Recurso, @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @Lock < 0 THROW 52590, 'No se obtuvo bloqueo de prueba.', 1;
    INSERT INTO dbo.banci_actualizacion_v2(codigo_referencia,id_entidad_federativa,id_usuario,origen,datos_json,advertencias_json)
    VALUES (@Codigo,@Entidad,@Usuario,N'FORMULARIO',@Datos,N'[]');
    EXEC dbo.sp_banci_calcular_actualizacion_v2 @Codigo,@Usuario,@Huella1 OUTPUT,@Aplicar OUTPUT,@Cambios OUTPUT;
    IF NOT EXISTS (SELECT 1 FROM OPENJSON(@Cambios) WITH (campo NVARCHAR(150), nuevo NVARCHAR(MAX)) WHERE campo = N'obs' AND nuevo = @Observacion)
        THROW 52590, 'La vista previa no detectó el cambio esperado.', 1;
    IF EXISTS (SELECT 1 FROM OPENJSON(@Cambios) WITH (campo NVARCHAR(150)) WHERE campo = N'pro_apellido')
        THROW 52590, 'Un campo vacío intentó borrar el apellido existente.', 1;
    EXEC dbo.sp_banci_calcular_actualizacion_v2 @Codigo,@Usuario,@Huella2 OUTPUT,@Aplicar OUTPUT,@Cambios OUTPUT;
    IF @Huella1 <> @Huella2 THROW 52590, 'La huella no es estable sin cambios.', 1;
    -- Cambiar las advertencias debe invalidar la huella anterior.
    UPDATE dbo.banci_actualizacion_v2 SET advertencias_json = N'[{"codigo":"PRUEBA"}]' WHERE codigo_referencia = @Codigo;
    EXEC dbo.sp_banci_calcular_actualizacion_v2 @Codigo,@Usuario,@Huella2 OUTPUT,@Aplicar OUTPUT,@Cambios OUTPUT;
    IF @Huella1 = @Huella2 THROW 52590, 'La huella no detectó el cambio de advertencias.', 1;
    ROLLBACK TRANSACTION;
    SELECT N'Correcto: preview, vacíos, huella estable y cambio de advertencias. Prueba revertida; no se actualizaron víctimas.' AS resultado;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
