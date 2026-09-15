USE [siiid2];
GO
SET NOCOUNT ON;
-- Para las pruebas posteriores de API/Front. No modifica tablas persistentes.
-- Misma ventana SSMS: 1 antes de una acción; 0 después para comparar.
DECLARE @CapturarBase BIT = 1;
DECLARE @IdEntidad TINYINT = 14;
DECLARE @Json NVARCHAR(MAX);
DECLARE @Actual TABLE (tabla SYSNAME PRIMARY KEY, registros BIGINT, huella VARBINARY(32));

SELECT @Json = (SELECT c.* FROM dbo.banci_carpeta_investigacion c WHERE c.id_entidad_federativa = @IdEntidad ORDER BY c.id_banci_carpeta_investigacion FOR JSON PATH, INCLUDE_NULL_VALUES);
INSERT INTO @Actual SELECT N'carpetas', COUNT_BIG(*), HASHBYTES('SHA2_256', @Json) FROM dbo.banci_carpeta_investigacion WHERE id_entidad_federativa = @IdEntidad;

SELECT @Json = (SELECT d.* FROM dbo.banci_delito d JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion WHERE c.id_entidad_federativa = @IdEntidad ORDER BY d.id_banci_delito FOR JSON PATH, INCLUDE_NULL_VALUES);
INSERT INTO @Actual SELECT N'delitos', COUNT_BIG(*), HASHBYTES('SHA2_256', @Json) FROM dbo.banci_delito d JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion WHERE c.id_entidad_federativa = @IdEntidad;

SELECT @Json = (SELECT v.* FROM dbo.banci_victima v JOIN dbo.banci_delito d ON d.id_banci_delito = v.id_banci_delito JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion WHERE c.id_entidad_federativa = @IdEntidad ORDER BY v.id_banci_victima FOR JSON PATH, INCLUDE_NULL_VALUES);
INSERT INTO @Actual SELECT N'victimas', COUNT_BIG(*), HASHBYTES('SHA2_256', @Json) FROM dbo.banci_victima v JOIN dbo.banci_delito d ON d.id_banci_delito = v.id_banci_delito JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion WHERE c.id_entidad_federativa = @IdEntidad;

SELECT @Json = (SELECT h.* FROM dbo.banci_historial_cambio h WHERE h.id_entidad_federativa = @IdEntidad ORDER BY h.id_banci_historial_cambio FOR JSON PATH, INCLUDE_NULL_VALUES);
INSERT INTO @Actual SELECT N'historial_datos', COUNT_BIG(*), HASHBYTES('SHA2_256', @Json) FROM dbo.banci_historial_cambio WHERE id_entidad_federativa = @IdEntidad;

IF @CapturarBase = 1
BEGIN
    IF OBJECT_ID(N'tempdb..#BasePruebaBanciDecision', N'U') IS NOT NULL DROP TABLE #BasePruebaBanciDecision;
    CREATE TABLE #BasePruebaBanciDecision (entidad TINYINT, tabla SYSNAME PRIMARY KEY, registros BIGINT, huella VARBINARY(32));
    INSERT INTO #BasePruebaBanciDecision SELECT @IdEntidad, tabla, registros, huella FROM @Actual;
    SELECT N'BASE CAPTURADA. Mantenga esta ventana abierta.' AS resultado, * FROM #BasePruebaBanciDecision;
END
ELSE
BEGIN
    IF OBJECT_ID(N'tempdb..#BasePruebaBanciDecision', N'U') IS NULL
        THROW 52440, 'Primero capture la base en esta misma ventana SSMS.', 1;
    IF EXISTS (SELECT 1 FROM #BasePruebaBanciDecision WHERE entidad <> @IdEntidad)
        THROW 52441, 'La entidad no corresponde con la base capturada.', 1;
    SELECT a.tabla, b.registros AS registros_antes, a.registros AS registros_despues,
           CASE WHEN a.registros = b.registros AND a.huella = b.huella THEN N'SIN CAMBIOS' ELSE N'CAMBIÓ' END AS resultado
    FROM @Actual a JOIN #BasePruebaBanciDecision b ON b.tabla = a.tabla ORDER BY a.tabla;
END;
