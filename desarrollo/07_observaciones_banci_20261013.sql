-- BANCI: observaciones octubre 2026. Incremental sobre desarrollo/06_cruce_previo_federal_banci.sql.
-- Ejecutar SOLO después de comprobar en QA el esquema real instalado; no usar sobre una instalación v2 incompleta.
-- Seleccione SIIID2_QA o siiid2 explícitamente desde SSMS. No hay USE ni eliminación de información.
-- Detener/evitar cargas y confirmaciones BANCI durante la ejecución.
-- Requiere catálogos compartidos activos con claves 1=Sí, 2=No, 3=No identificado y 4=No aplica.
-- Los históricos de staging y auditoría NO se sobrescriben; reflejan los valores originales de su recepción.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET IMPLICIT_TRANSACTIONS OFF;

IF OBJECT_ID(N'dbo.banci_victima', N'U') IS NULL
    THROW 52710, 'Falta dbo.banci_victima; no ejecute este ajuste sin BANCI instalado.', 1;
IF OBJECT_ID(N'dbo.banci_carga', N'U') IS NULL
    THROW 52711, 'Falta dbo.banci_carga.', 1;
IF OBJECT_ID(N'dbo.catalogo_pertenece_poblacion_indigena', N'U') IS NULL
    THROW 52712, 'Falta el catálogo institucional de población indígena.', 1;
IF OBJECT_ID(N'dbo.catalogo_presenta_discapacidad', N'U') IS NULL
    THROW 52713, 'Falta el catálogo institucional de discapacidad.', 1;

-- Nunca alterar el significado de registros con una carga aún pendiente de revisión/confirmación.
IF EXISTS
(
    SELECT 1 FROM dbo.banci_carga
    WHERE activo = 1
      AND estado IN (N'RECIBIDO', N'VALIDANDO', N'VALIDADO', N'VALIDADO_PENDIENTE', N'PROCESANDO')
)
    THROW 52714, 'Existen cargas BANCI abiertas. Confírmelas o rechácelas antes de este ajuste.', 1;

-- No se crean catálogos ni se insertan códigos nuevos: las claves ya deben existir y estar activas.
IF EXISTS
(
    SELECT 1 FROM (VALUES (1),(2),(3),(4)) k(clave)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.catalogo_pertenece_poblacion_indigena c WHERE c.clave=k.clave AND c.activo=1)
       OR NOT EXISTS (SELECT 1 FROM dbo.catalogo_presenta_discapacidad c WHERE c.clave=k.clave AND c.activo=1)
)
    THROW 52715, 'Faltan claves activas 1-4 en los catálogos institucionales POB/DISC.', 1;

IF EXISTS (SELECT 1 FROM dbo.banci_victima WHERE pob NOT IN (0,1,2,3,4) OR disc NOT IN (0,1,2,3,4))
    THROW 52716, 'BANCI contiene valores POB/DISC fuera del dominio conocido. Revise antes de migrar.', 1;

DECLARE @BloqueFub NVARCHAR(MAX) = N'    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(fub)), N'''') IS NULL)
        THROW 52512, ''FUB es obligatorio para cada víctima.'', 1;
';
DECLARE @BloqueFubActualizacion NVARCHAR(MAX) = N'    IF EXISTS (SELECT 1 FROM #Propuesto WHERE NULLIF(LTRIM(RTRIM(fub)), N'''') IS NULL) THROW 52531, ''FUB es obligatorio; informe el folio faltante antes de actualizar.'', 1;';
DECLARE @Nombre SYSNAME, @Definicion NVARCHAR(MAX), @Nueva NVARCHAR(MAX), @Cambiados INT = 0;
DECLARE @Objetos TABLE (nombre SYSNAME PRIMARY KEY, tipo NVARCHAR(25));
INSERT INTO @Objetos (nombre, tipo) VALUES
(N'sp_banci_procesar_carga_v2', N'CARGA'),
(N'sp_banci_vista_previa_v2', N'CARGA'),
(N'sp_banci_calcular_actualizacion_v2', N'ACTUALIZACION');

-- Prevalidación de TODAS las definiciones antes de actualizar cualquier objeto.
DECLARE @Definiciones TABLE (nombre SYSNAME PRIMARY KEY, nueva NVARCHAR(MAX));
DECLARE objetos CURSOR LOCAL FAST_FORWARD FOR SELECT nombre FROM @Objetos ORDER BY nombre;
OPEN objetos;
FETCH NEXT FROM objetos INTO @Nombre;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @Definicion = OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + @Nombre, N'P'));
    IF @Definicion IS NULL
        THROW 52717, 'Falta un procedimiento BANCI v2 o no hay permisos para leer su definición.', 1;
    SET @Definicion = REPLACE(@Definicion, NCHAR(13), N'');
    SET @Nueva = @Definicion;

    IF @Nombre IN (N'sp_banci_procesar_carga_v2', N'sp_banci_vista_previa_v2')
    BEGIN
        IF CHARINDEX(N'DATEADD(MONTH,-1,@MesBanci)', @Nueva) = 0 OR CHARINDEX(@BloqueFub, @Nueva) = 0
            THROW 52718, 'La definición de procesamiento/vista previa BANCI es diferente del script 06; revise antes de instalar.', 1;
        SET @Nueva = REPLACE(@Nueva, N'DATEADD(MONTH,-1,@MesBanci)', N'CONVERT(DATE,N''20241001'',112)');
        SET @Nueva = REPLACE(@Nueva, N'La fecha de inicio debe pertenecer al mes en curso o al anterior. Vuelva a validar si cambió el periodo.', N'La fecha de inicio debe estar entre octubre de 2024 y el mes actual. Vuelva a validar si cambió el periodo.');
        SET @Nueva = REPLACE(@Nueva, @BloqueFub, N'');
    END
    ELSE
    BEGIN
        IF CHARINDEX(@BloqueFubActualizacion, @Nueva) = 0
            THROW 52719, 'La definición de actualización BANCI es diferente del script 06; revise antes de instalar.', 1;
        SET @Nueva = REPLACE(@Nueva, @BloqueFubActualizacion, N'');
    END;

    INSERT INTO @Definiciones (nombre,nueva) VALUES (@Nombre,@Nueva);
    SET @Definicion = NULL;
    FETCH NEXT FROM objetos INTO @Nombre;
END;
CLOSE objetos;
DEALLOCATE objetos;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Los antiguos valores 0=No y 1=Sí se convierten en 2=No y 1=Sí.
    -- No se actualizan los staging ni los históricos porque son evidencia de los valores originales.
    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.banci_victima') AND name=N'CK_banci_victima_pob')
        ALTER TABLE dbo.banci_victima DROP CONSTRAINT CK_banci_victima_pob;
    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.banci_victima') AND name=N'CK_banci_victima_disc')
        ALTER TABLE dbo.banci_victima DROP CONSTRAINT CK_banci_victima_disc;

    UPDATE dbo.banci_victima SET pob = 2 WHERE pob = 0;
    UPDATE dbo.banci_victima SET disc = 2 WHERE disc = 0;

    ALTER TABLE dbo.banci_victima WITH CHECK ADD CONSTRAINT CK_banci_victima_pob
        CHECK (pob IS NULL OR pob IN (1,2,3,4));
    ALTER TABLE dbo.banci_victima WITH CHECK ADD CONSTRAINT CK_banci_victima_disc
        CHECK (disc IS NULL OR disc IN (1,2,3,4));

    DECLARE @DefinicionEjecutable NVARCHAR(MAX);
    DECLARE instalar CURSOR LOCAL FAST_FORWARD FOR SELECT nombre,nueva FROM @Definiciones ORDER BY nombre;
    OPEN instalar;
    FETCH NEXT FROM instalar INTO @Nombre,@DefinicionEjecutable;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Cada definición es un lote CREATE OR ALTER PROCEDURE vigente, sin SQL reescrito fuera de BANCI.
        EXEC sys.sp_executesql @DefinicionEjecutable;
        SET @Cambiados += 1;
        FETCH NEXT FROM instalar INTO @Nombre,@DefinicionEjecutable;
    END;
    CLOSE instalar;
    DEALLOCATE instalar;

    COMMIT TRANSACTION;
    SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_actual, @Cambiados AS procedimientos_ajustados,
           (SELECT COUNT_BIG(*) FROM dbo.banci_victima WHERE pob=0 OR disc=0) AS valores_antiguos_restantes;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
