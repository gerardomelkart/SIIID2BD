-- BANCI V2: fechas de localización. Ejecutar después de los scripts 16, 17 y 18, primero en desarrollo.
-- No borra registros ni crea tablas. Los procedimientos de preparación/confirmación conservan sus permisos y bloqueos.
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 52536, 'Ejecute este script sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sp_banci_calcular_actualizacion_v2', N'P') IS NULL OR OBJECT_ID(N'dbo.banci_vw_victimas_v2', N'V') IS NULL THROW 52536, 'Falta instalar BANCI V2 (scripts 16 a 18).', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_victimas_v2 AS
SELECT c.id_entidad_federativa, c.no_banci, c.id_ci, c.ntra_ci, c.fha_de_ini,
    c.id_banci_carpeta_investigacion, d.id_banci_delito, d.id_delito, v.id_banci_victima, v.id_vicf,
    v.id_tv, v.id_tpm, v.sexo, v.genero, v.pob, v.disc, v.fha_nac, v.edad, v.nacional,
    v.folio_rnpdno, v.pro_apellido, v.sdo_apellido, v.nomb, v.entidad_nacimiento, v.estado_migratorio, v.curp, v.rfc,
    v.localizado_o_no_localizado, v.con_o_sin_vida, v.fecha_localizacion, v.voluntaria_o_fue_delito, v.delito, v.acciones_busqueda, v.obs,
    v.version_banci, v.fecha_modificacion, d.fha_de_hchos
FROM dbo.banci_carpeta_investigacion c JOIN dbo.banci_delito d ON d.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion
JOIN dbo.banci_victima v ON v.id_banci_delito = d.id_banci_delito WHERE c.activo = 1 AND d.activo = 1 AND v.activo = 1;';

    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_calcular_actualizacion_v2
    @CodigoReferencia UNIQUEIDENTIFIER, @IdUsuario INT,
    @Huella VARCHAR(64) OUTPUT, @DatosAplicar NVARCHAR(MAX) OUTPUT, @Cambios NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 OR XACT_STATE() <> 1 THROW 52520, ''La vista previa requiere una transacción activa.'', 1;
    DECLARE @IdEntidad TINYINT, @Datos NVARCHAR(MAX), @Advertencias NVARCHAR(MAX), @Estado NVARCHAR(20);
    SELECT @IdEntidad = id_entidad_federativa, @Datos = datos_json, @Advertencias = advertencias_json, @Estado = estado
    FROM dbo.banci_actualizacion_v2 WITH (HOLDLOCK) WHERE codigo_referencia = @CodigoReferencia AND id_usuario = @IdUsuario;
    IF @IdEntidad IS NULL OR @Estado <> N''PENDIENTE'' THROW 52521, ''La actualización no está pendiente o no pertenece al usuario.'', 1;
    DECLARE @Recurso NVARCHAR(255) = CONCAT(N''BANCI:ENTIDAD:'', @IdEntidad);
    IF ISNULL(APPLOCK_MODE(N''public'', @Recurso, N''Transaction''), N''NoLock'') NOT IN (N''Shared'', N''Exclusive'') THROW 52522, ''Falta el bloqueo de la entidad.'', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.usuario u WITH (HOLDLOCK)
    JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
    JOIN dbo.catalogo_modulo m WITH (HOLDLOCK) ON m.clave = N''BANCI'' AND m.activo = 1
    LEFT JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = m.id_modulo AND um.activo = 1 AND um.habilitado = 1
    WHERE u.id_usuario = @IdUsuario AND u.activo = 1
      AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad AND um.id_usuario IS NOT NULL AND um.habilita_modificacion = 1))) THROW 52523, ''No tiene permiso de modificación BANCI para esta entidad.'', 1;
    IF ISJSON(@Datos) <> 1 OR LEFT(LTRIM(@Datos), 1) <> N''['' THROW 52524, ''Los datos deben ser un arreglo JSON.'', 1;
    IF EXISTS (SELECT 1 FROM OPENJSON(@Datos) WHERE type <> 5) THROW 52524, ''Cada fila debe ser un objeto JSON.'', 1;
    SELECT CONVERT(INT, [key]) AS indice, value AS datos INTO #Filas FROM OPENJSON(@Datos);
    IF (SELECT COUNT(*) FROM #Filas) NOT BETWEEN 1 AND 20000 THROW 52524, ''Se permiten de 1 a 20000 víctimas por actualización.'', 1;
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j GROUP BY f.indice, j.[key] COLLATE Latin1_General_100_BIN2 HAVING COUNT(*) > 1)
        THROW 52524, ''Hay propiedades JSON repetidas en una fila.'', 1;
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j WHERE j.[key] COLLATE Latin1_General_100_BIN2 NOT IN (N''fila'',N''no_banci'',N''id_delito'',N''id_vicf'',N''folio_rnpdno'',N''pro_apellido'',N''sdo_apellido'',N''nomb'',N''entidad_nacimiento'',N''estado_migratorio'',N''curp'',N''rfc'',N''localizado_o_no_localizado'',N''con_o_sin_vida'',N''fecha_localizacion'',N''voluntaria_o_fue_delito'',N''delito'',N''acciones_busqueda'',N''obs''))
        THROW 52524, ''La actualización contiene columnas no permitidas.'', 1;
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j WHERE j.type NOT IN (0,1,2)) THROW 52524, ''Los campos deben ser texto, número o null.'', 1;
    SELECT f.indice, j.[key] COLLATE DATABASE_DEFAULT AS campo, NULLIF(LTRIM(RTRIM(j.value)), N'''') AS valor INTO #Valores FROM #Filas f CROSS APPLY OPENJSON(f.datos) j;
    IF EXISTS (SELECT 1 FROM #Valores WHERE (campo = N''no_banci'' AND DATALENGTH(valor) > 80) OR (campo = N''id_delito'' AND DATALENGTH(valor) > 500) OR (campo = N''id_vicf'' AND DATALENGTH(valor) > 500) OR (campo = N''folio_rnpdno'' AND DATALENGTH(valor) > 500) OR (campo = N''pro_apellido'' AND DATALENGTH(valor) > 500) OR (campo = N''sdo_apellido'' AND DATALENGTH(valor) > 500) OR (campo = N''nomb'' AND DATALENGTH(valor) > 1000) OR (campo = N''entidad_nacimiento'' AND DATALENGTH(valor) > 500) OR (campo = N''estado_migratorio'' AND DATALENGTH(valor) > 1000) OR (campo = N''curp'' AND DATALENGTH(valor) > 100) OR (campo = N''rfc'' AND DATALENGTH(valor) > 26) OR (campo = N''localizado_o_no_localizado'' AND DATALENGTH(valor) > 6) OR (campo = N''con_o_sin_vida'' AND DATALENGTH(valor) > 6) OR (campo = N''fecha_localizacion'' AND DATALENGTH(valor) > 20) OR (campo = N''voluntaria_o_fue_delito'' AND DATALENGTH(valor) > 6) OR (campo = N''delito'' AND DATALENGTH(valor) > 2000)) THROW 52525, ''Un campo supera su longitud permitida.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE campo = N''fila'' AND valor IS NOT NULL AND (TRY_CONVERT(INT, valor) IS NULL OR TRY_CONVERT(INT, valor) < 1)) THROW 52525, ''Número de fila inválido.'', 1;
    SELECT f.indice, COALESCE(TRY_CONVERT(INT, JSON_VALUE(f.datos, ''$.fila'')), f.indice + 1) AS fila,
        NULLIF(LTRIM(RTRIM(JSON_VALUE(f.datos, ''$.no_banci''))), N'''') AS no_banci,
        NULLIF(LTRIM(RTRIM(JSON_VALUE(f.datos, ''$.id_delito''))), N'''') AS id_delito,
        NULLIF(LTRIM(RTRIM(JSON_VALUE(f.datos, ''$.id_vicf''))), N'''') AS id_vicf
    INTO #Llaves FROM #Filas f;
    IF EXISTS (SELECT 1 FROM #Llaves WHERE no_banci IS NULL OR id_delito IS NULL OR id_vicf IS NULL) THROW 52526, ''Cada víctima requiere NO_BANCI, ID_DELITO e ID_VICF.'', 1;
    SELECT k.indice, k.fila, v.* INTO #Actual FROM #Llaves k JOIN dbo.banci_vw_victimas_v2 v WITH (HOLDLOCK)
        ON v.no_banci = k.no_banci AND v.id_delito = k.id_delito AND v.id_vicf = k.id_vicf AND v.id_entidad_federativa = @IdEntidad;
    IF (SELECT COUNT(*) FROM #Actual) <> (SELECT COUNT(*) FROM #Llaves) THROW 52527, ''Alguna víctima no existe, está inactiva o pertenece a otra entidad.'', 1;
    IF EXISTS (SELECT 1 FROM #Actual GROUP BY id_banci_victima HAVING COUNT(*) > 1) THROW 52528, ''Una víctima aparece varias veces en el archivo.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE valor IS NOT NULL AND campo IN (N''localizado_o_no_localizado'',N''con_o_sin_vida'') AND (TRY_CONVERT(TINYINT,valor) IS NULL OR TRY_CONVERT(TINYINT,valor) NOT IN (1,2))) THROW 52529, ''Localización o condición de vida fuera del catálogo.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE valor IS NOT NULL AND campo = N''voluntaria_o_fue_delito'' AND (TRY_CONVERT(TINYINT,valor) IS NULL OR TRY_CONVERT(TINYINT,valor) NOT IN (1,2,3))) THROW 52529, ''Motivo de localización fuera del catálogo 1/2/3.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE valor IS NOT NULL AND campo = N''fecha_localizacion'' AND (TRY_CONVERT(DATE,valor,23) IS NULL OR CONVERT(NVARCHAR(10),TRY_CONVERT(DATE,valor,23),23) <> valor)) THROW 52529, ''La fecha de localización debe ser válida y estar en formato yyyy-MM-dd.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE valor IS NOT NULL AND campo = N''curp'' AND (LEN(valor) <> 18 OR valor COLLATE Latin1_General_100_BIN2 LIKE N''%[^A-Z0-9]%'')) THROW 52529, ''La CURP debe tener 18 caracteres alfanuméricos en mayúsculas.'', 1;
    -- La API valida el formato completo y consulta RENAPO antes de guardar la operación.
    -- Delito de localización: opcional e independiente; se acepta clave2 o descripción del catálogo mensual.
    IF EXISTS (SELECT 1 FROM #Valores x WHERE x.campo = N''delito'' AND x.valor IS NOT NULL AND
        (SELECT COUNT(*) FROM dbo.banci_vw_delito_localizacion_catalogo d WHERE d.clave = x.valor OR d.descripcion = x.valor) <> 1)
        THROW 52530, ''El delito de localización no corresponde unívocamente a un delito activo del catálogo Consolidado.'', 1;
    UPDATE x SET valor = d.descripcion FROM #Valores x JOIN dbo.banci_vw_delito_localizacion_catalogo d ON d.clave = x.valor OR d.descripcion = x.valor WHERE x.campo = N''delito'';
    SELECT a.indice, a.fila, a.id_banci_victima, a.no_banci, a.id_ci, a.id_delito, a.id_vicf,
        folio_rnpdno = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''folio_rnpdno'')),a.folio_rnpdno),
        pro_apellido = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''pro_apellido'')),a.pro_apellido),
        sdo_apellido = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''sdo_apellido'')),a.sdo_apellido),
        nomb = COALESCE(TRY_CONVERT(NVARCHAR(500),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''nomb'')),a.nomb),
        entidad_nacimiento = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''entidad_nacimiento'')),a.entidad_nacimiento),
        estado_migratorio = COALESCE(TRY_CONVERT(NVARCHAR(500),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''estado_migratorio'')),a.estado_migratorio),
        curp = COALESCE(TRY_CONVERT(NVARCHAR(50),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''curp'')),a.curp),
        rfc = COALESCE(TRY_CONVERT(NVARCHAR(13),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''rfc'')),a.rfc),
        localizado_o_no_localizado = COALESCE(TRY_CONVERT(TINYINT,(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''localizado_o_no_localizado'')),a.localizado_o_no_localizado),
        con_o_sin_vida = COALESCE(TRY_CONVERT(TINYINT,(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''con_o_sin_vida'')),a.con_o_sin_vida),
        fecha_localizacion = COALESCE(TRY_CONVERT(DATE,(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''fecha_localizacion''),23),a.fecha_localizacion),
        voluntaria_o_fue_delito = COALESCE(TRY_CONVERT(TINYINT,(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''voluntaria_o_fue_delito'')),a.voluntaria_o_fue_delito),
        delito = COALESCE(TRY_CONVERT(NVARCHAR(1000),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''delito'')),a.delito),
        acciones_busqueda = COALESCE(TRY_CONVERT(NVARCHAR(MAX),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''acciones_busqueda'')),a.acciones_busqueda),
        obs = COALESCE(TRY_CONVERT(NVARCHAR(MAX),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''obs'')),a.obs)
    INTO #Propuesto FROM #Actual a;
    IF EXISTS (SELECT 1 FROM #Propuesto WHERE NULLIF(LTRIM(RTRIM(folio_rnpdno)), N'''') IS NULL) THROW 52531, ''Folio RNPDNO es obligatorio; informe el folio faltante antes de actualizar.'', 1;
    -- Revalidar la fecha final al preparar, recuperar y confirmar; los vacíos conservan el valor registrado.
    DECLARE @HoyLocal DATE = CONVERT(DATE, SWITCHOFFSET(SYSDATETIMEOFFSET(), ''-06:00''));
    IF EXISTS (SELECT 1 FROM #Propuesto p JOIN #Actual a ON a.id_banci_victima = p.id_banci_victima
        WHERE EXISTS (SELECT 1 FROM #Valores x WHERE x.indice = a.indice AND x.valor IS NOT NULL
            AND x.campo IN (N''fecha_localizacion'', N''localizado_o_no_localizado'', N''con_o_sin_vida'', N''voluntaria_o_fue_delito''))
          AND (p.fecha_localizacion > @HoyLocal OR p.fecha_localizacion < CONVERT(DATE, a.fha_de_ini) OR p.fecha_localizacion < CONVERT(DATE, a.fha_de_hchos)))
        THROW 52536, ''La fecha de localización debe estar entre el inicio de la carpeta/los hechos y hoy. Rechace esta revisión y corrija la fecha.'', 1;
    SELECT a.id_banci_victima, a.fila, a.no_banci, a.id_ci, a.id_delito, a.id_vicf, x.campo, x.anterior, x.nuevo INTO #Cambios
    FROM #Actual a JOIN #Propuesto p ON p.id_banci_victima = a.id_banci_victima
    CROSS APPLY (VALUES (N''folio_rnpdno'',CONVERT(NVARCHAR(MAX),a.folio_rnpdno),CONVERT(NVARCHAR(MAX),p.folio_rnpdno)),
        (N''pro_apellido'',CONVERT(NVARCHAR(MAX),a.pro_apellido),CONVERT(NVARCHAR(MAX),p.pro_apellido)),
        (N''sdo_apellido'',CONVERT(NVARCHAR(MAX),a.sdo_apellido),CONVERT(NVARCHAR(MAX),p.sdo_apellido)),
        (N''nomb'',CONVERT(NVARCHAR(MAX),a.nomb),CONVERT(NVARCHAR(MAX),p.nomb)),
        (N''entidad_nacimiento'',CONVERT(NVARCHAR(MAX),a.entidad_nacimiento),CONVERT(NVARCHAR(MAX),p.entidad_nacimiento)),
        (N''estado_migratorio'',CONVERT(NVARCHAR(MAX),a.estado_migratorio),CONVERT(NVARCHAR(MAX),p.estado_migratorio)),
        (N''curp'',CONVERT(NVARCHAR(MAX),a.curp),CONVERT(NVARCHAR(MAX),p.curp)),
        (N''rfc'',CONVERT(NVARCHAR(MAX),a.rfc),CONVERT(NVARCHAR(MAX),p.rfc)),
        (N''localizado_o_no_localizado'',CONVERT(NVARCHAR(MAX),a.localizado_o_no_localizado),CONVERT(NVARCHAR(MAX),p.localizado_o_no_localizado)),
        (N''con_o_sin_vida'',CONVERT(NVARCHAR(MAX),a.con_o_sin_vida),CONVERT(NVARCHAR(MAX),p.con_o_sin_vida)),
        (N''fecha_localizacion'',CONVERT(NVARCHAR(MAX),a.fecha_localizacion,23),CONVERT(NVARCHAR(MAX),p.fecha_localizacion,23)),
        (N''voluntaria_o_fue_delito'',CONVERT(NVARCHAR(MAX),a.voluntaria_o_fue_delito),CONVERT(NVARCHAR(MAX),p.voluntaria_o_fue_delito)),
        (N''delito'',CONVERT(NVARCHAR(MAX),a.delito),CONVERT(NVARCHAR(MAX),p.delito)),
        (N''acciones_busqueda'',CONVERT(NVARCHAR(MAX),a.acciones_busqueda),CONVERT(NVARCHAR(MAX),p.acciones_busqueda)),
        (N''obs'',CONVERT(NVARCHAR(MAX),a.obs),CONVERT(NVARCHAR(MAX),p.obs))) x(campo, anterior, nuevo)
    WHERE (x.anterior IS NULL AND x.nuevo IS NOT NULL) OR (x.anterior IS NOT NULL AND x.nuevo IS NULL) OR x.anterior COLLATE Latin1_General_100_BIN2 <> x.nuevo COLLATE Latin1_General_100_BIN2;
    SET @DatosAplicar = (SELECT * FROM #Propuesto ORDER BY id_banci_victima FOR JSON PATH, INCLUDE_NULL_VALUES);
    SET @Cambios = (SELECT * FROM #Cambios ORDER BY id_banci_victima, campo FOR JSON PATH, INCLUDE_NULL_VALUES);
    DECLARE @Snapshot NVARCHAR(MAX) = (SELECT id_banci_victima, CONVERT(VARCHAR(18), version_banci, 1) AS version_banci FROM #Actual ORDER BY id_banci_victima FOR JSON PATH);
    SET @Huella = CONVERT(VARCHAR(64), HASHBYTES(''SHA2_256'', CONCAT(CONVERT(NVARCHAR(MAX),@CodigoReferencia),N''|'',@IdUsuario,N''|'',@Datos,N''|'',@Advertencias,N''|'',@Snapshot,N''|'',@DatosAplicar,N''|'',@Cambios)),2);
END;';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
