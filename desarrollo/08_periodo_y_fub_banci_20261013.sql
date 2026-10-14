-- BANCI 08: fechas desde 2024-10-01 y FUB opcional.
-- Seleccionar expresamente la base en SSMS. Requiere respaldo, script 07
-- y una ventana sin cargas/actualizaciones BANCI en ejecución.
-- No ejecutar 06 completo. Sin USE, sin switch aplicar/no aplicar.
-- El 08 conserva los procedimientos instalados y sólo cambia reglas conocidas.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

IF @@TRANCOUNT <> 0
    THROW 52800, 'Ejecute 08 sin transacciones abiertas.', 1;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 52801, 'Seleccione la base SIIID2 correspondiente.', 1;
IF OBJECT_ID(N'dbo.banci_victima', N'U') IS NULL
    THROW 52802, 'BANCI no está instalado.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.banci_victima') AND name = N'FK_banci_victima_pob_catalogo')
    OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.banci_victima') AND name = N'FK_banci_victima_disc_catalogo')
    THROW 52803, 'Aplique antes el script 07 de POB/DISC.', 1;
IF EXISTS (SELECT 1 FROM dbo.banci_carga WHERE activo = 1
    AND estado IN (N'RECIBIDO', N'VALIDANDO', N'VALIDADO', N'VALIDADO_PENDIENTE', N'PROCESANDO'))
    THROW 52804, 'Hay cargas BANCI pendientes; finalícelas o rechácelas primero.', 1;

DECLARE @Nombres TABLE(nombre SYSNAME PRIMARY KEY);
INSERT INTO @Nombres VALUES (N'sp_banci_procesar_carga_v2'),
    (N'sp_banci_vista_previa_v2'), (N'sp_banci_calcular_actualizacion_v2');
DECLARE @Cambios TABLE(nombre SYSNAME PRIMARY KEY, definicion NVARCHAR(MAX), cambiar BIT);
DECLARE @Nombre SYSNAME, @Original NVARCHAR(MAX), @Nueva NVARCHAR(MAX),
    @Old NVARCHAR(60) = N'DATEADD(MONTH,-1,@MesBanci)',
    @New NVARCHAR(60) = N'CONVERT(DATE,N''20241001'',112)',
    @Codigo NVARCHAR(30), @P INT, @Q INT, @R INT, @Inicio INT, @Fin INT,
    @Bloque NVARCHAR(MAX), @Condicion NVARCHAR(MAX), @Esperada NVARCHAR(MAX),
    @Cabecera INT, @Cambiar BIT, @PosNombre INT, @RevCreate INT, @RevAlter INT,
    @Palabra NVARCHAR(6), @Firma NVARCHAR(MAX), @FirmaNormalizada NVARCHAR(MAX);

DECLARE preparar CURSOR LOCAL FAST_FORWARD FOR SELECT nombre FROM @Nombres ORDER BY nombre;
OPEN preparar;
FETCH NEXT FROM preparar INTO @Nombre;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Original = OBJECT_DEFINITION(OBJECT_ID(N'dbo.'+@Nombre, N'P'));
    IF @Original IS NULL
        THROW 52805, 'Falta un procedimiento BANCI o no puede leer su definición.', 1;
    IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.'+@Nombre)
        AND (uses_ansi_nulls = 0 OR uses_quoted_identifier = 0))
        THROW 52806, 'Procedimiento con configuración ANSI/QUOTED_IDENTIFIER diferente.', 1;
    SET @Nueva = REPLACE(@Original, NCHAR(13), N'');

    IF @Nombre <> N'sp_banci_calcular_actualizacion_v2'
    BEGIN
        IF CHARINDEX(N'DATEADD(MONTH,1,@MesBanci)', @Nueva COLLATE Latin1_General_100_CI_AS) = 0
            OR CHARINDEX(N'THROW 52610', @Nueva COLLATE Latin1_General_100_CI_AS) = 0
            THROW 52807, 'Condición de fecha del procedimiento diferente de la reconocida.', 1;
        SET @P = CHARINDEX(@Old, @Nueva COLLATE Latin1_General_100_CI_AS);
        IF @P>0
        BEGIN
            IF CHARINDEX(@Old, @Nueva COLLATE Latin1_General_100_CI_AS, @P+1)>0
                THROW 52808, 'Se encontró más de un límite inferior de fecha.', 1;
            SET @Nueva = STUFF(@Nueva, @P, LEN(@Old), @New);
            SET @Nueva = REPLACE(@Nueva,
                N'La fecha de inicio debe pertenecer al mes en curso o al anterior. Vuelva a validar si cambió el periodo.',
                N'La fecha de inicio debe estar entre octubre de 2024 y el mes actual. Vuelva a validar si cambió el periodo.');
        END
        ELSE IF CHARINDEX(N'20241001', @Nueva) = 0
            THROW 52809, 'Límite inferior de fecha desconocido.', 1;
    END;

    SET @Codigo = CASE WHEN @Nombre = N'sp_banci_calcular_actualizacion_v2'
        THEN N'THROW 52531' ELSE N'THROW 52512' END;
    SET @P = CHARINDEX(@Codigo, @Nueva COLLATE Latin1_General_100_CI_AS);
    IF @P>0
    BEGIN
        IF CHARINDEX(@Codigo, @Nueva COLLATE Latin1_General_100_CI_AS, @P+LEN(@Codigo))>0
            THROW 52810, 'Hay varias validaciones FUB con el mismo código.', 1;
        SET @R = CHARINDEX(REVERSE(N'IF EXISTS'), REVERSE(LEFT(@Nueva, @P-1)) COLLATE Latin1_General_100_CI_AS);
        IF @R = 0
            THROW 52811, 'No se encontró el IF EXISTS anterior al THROW FUB.', 1;
        SET @Inicio = @P-@R-LEN(N'IF EXISTS')+1;
        SET @Q = CHARINDEX(N', 1;', @Nueva, @P);
        IF @Inicio<1 OR @Q = 0 OR @P-@Inicio>750 OR @Q-@P>260
            THROW 52812, 'Bloque de FUB desconocido. Se conservó el procedimiento.', 1;
        SET @Fin = @Q+LEN(N', 1;')-1;
        SET @Bloque = SUBSTRING(@Nueva, @Inicio, @Fin-@Inicio+1);
        SET @Condicion = LEFT(@Bloque, CHARINDEX(@Codigo, @Bloque COLLATE Latin1_General_100_CI_AS)-1);
        SET @Condicion = UPPER(REPLACE(REPLACE(REPLACE(@Condicion, N' ', N''), NCHAR(9), N''), NCHAR(10), N''));
        SET @Esperada = CASE WHEN @Nombre = N'sp_banci_calcular_actualizacion_v2'
            THEN N'IFEXISTS(SELECT1FROM#PROPUESTOWHERENULLIF(LTRIM(RTRIM(FUB)),N'''')ISNULL)'
            ELSE N'IFEXISTS(SELECT1FROMDBO.BANCI_CARGA_TMP_VICTIMAWHEREID_BANCI_CARGA=@IDBANCICARGAANDACTIVO=1ANDNULLIF(LTRIM(RTRIM(FUB)),N'''')ISNULL)' END;
        IF @Condicion COLLATE Latin1_General_100_BIN2 <> @Esperada COLLATE Latin1_General_100_BIN2
            OR CHARINDEX(N'FUB es obligatorio', @Bloque COLLATE Latin1_General_100_CI_AS) = 0
            THROW 52813, 'FUB utiliza otra regla y no se modificará.', 1;
        SET @Nueva = STUFF(@Nueva, @Inicio, @Fin-@Inicio+1, N'-- FUB opcional (BANCI 08).');
    END
    ELSE IF CHARINDEX(N'FUB es obligatorio', @Nueva COLLATE Latin1_General_100_CI_AS)>0
        THROW 52814, 'Existe una validación FUB adicional no reconocida.', 1;

    SET @Cambiar = CASE WHEN @Nueva <> REPLACE(@Original, NCHAR(13), N'') THEN 1 ELSE 0 END;
    IF @Cambiar = 1
    BEGIN
        -- OBJECT_DEFINITION puede empezar con comentarios o espacios.
        -- Buscar la palabra de declaración INMEDIATAMENTE anterior al
        -- nombre del procedimiento, sin modificar comentarios ni su cuerpo.
        SET @PosNombre = CHARINDEX(@Nombre, @Nueva COLLATE Latin1_General_100_CI_AS);
        IF @PosNombre = 0
            THROW 52815, 'La definición no contiene el nombre del procedimiento.', 1;

        SET @Firma = REVERSE(LEFT(@Nueva, @PosNombre-1));
        SET @RevCreate = CHARINDEX(N'ETAERC', @Firma COLLATE Latin1_General_100_CI_AS);
        SET @RevAlter = CHARINDEX(N'RETLA', @Firma COLLATE Latin1_General_100_CI_AS);
        IF @RevCreate = 0 AND @RevAlter = 0
            THROW 52815, 'No se identificó CREATE ni ALTER en la declaración.', 1;

        IF @RevAlter>0 AND (@RevCreate = 0 OR @RevAlter<@RevCreate)
        BEGIN
            SET @Cabecera = LEN(@Firma)-@RevAlter-LEN(N'ALTER')+2;
            SET @Palabra = N'ALTER';
        END
        ELSE
        BEGIN
            SET @Cabecera = LEN(@Firma)-@RevCreate-LEN(N'CREATE')+2;
            SET @Palabra = N'CREATE';
        END;

        SET @Firma = SUBSTRING(@Nueva, @Cabecera, @PosNombre-@Cabecera);
        SET @FirmaNormalizada = UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            @Firma, N' ', N''), NCHAR(9), N''), NCHAR(10), N''), N'[', N''), N']', N''));

        IF @FirmaNormalizada COLLATE Latin1_General_100_BIN2 NOT IN
        (
            N'CREATEPROCEDUREDBO.', N'CREATEPROCDBO.',
            N'ALTERPROCEDUREDBO.', N'ALTERPROCDBO.',
            N'CREATEPROCEDURE', N'CREATEPROC',
            N'ALTERPROCEDURE', N'ALTERPROC'
        )
            THROW 52815, 'Declaración de procedimiento no reconocida; no se modificó.', 1;

        IF @Palabra = N'CREATE'
            SET @Nueva = STUFF(@Nueva, @Cabecera, LEN(N'CREATE'), N'ALTER');
    END;
    INSERT INTO @Cambios VALUES(@Nombre, @Nueva, @Cambiar);
    SET @Original = NULL;
    FETCH NEXT FROM preparar INTO @Nombre;
END;
CLOSE preparar;
DEALLOCATE preparar;

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Sql NVARCHAR(MAX);
    DECLARE instalar CURSOR LOCAL FAST_FORWARD FOR
        SELECT definicion FROM @Cambios WHERE cambiar = 1 ORDER BY nombre;
    OPEN instalar;
    FETCH NEXT FROM instalar INTO @Sql;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sys.sp_executesql @Sql;
        FETCH NEXT FROM instalar INTO @Sql;
    END;
    CLOSE instalar;
    DEALLOCATE instalar;
    COMMIT TRANSACTION;
    SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_actual, nombre AS procedimiento,
        CASE WHEN cambiar = 1 THEN N'ACTUALIZADO' ELSE N'YA ESTABA ACTUALIZADO' END AS resultado
    FROM @Cambios ORDER BY nombre;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
