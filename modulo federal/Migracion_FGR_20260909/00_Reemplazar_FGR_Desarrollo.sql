/*
    SIIID2 - Desarrollo
    Reemplaza el usuario Federal de pruebas por el usuario FGR de producción.

    Usuario que se elimina: fgr / ID 1060
    Usuario que se crea: FGRX26011400

    EJECUTAR SOLO EN DESARROLLO, conectado a siiid2.
*/
USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @UsuarioAnterior INT = 1060;
DECLARE @NombreUsuarioAnterior NVARCHAR(50) = N'fgr';
DECLARE @NombreUsuarioNuevo NVARCHAR(50) = N'FGRX26011400';
DECLARE @ResultadoLock INT;

IF DB_NAME() <> N'siiid2'
    THROW 51000, 'Esta limpieza solo puede ejecutarse en la base siiid2.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.usuario
    WHERE id_usuario = @UsuarioAnterior
      AND usuario = @NombreUsuarioAnterior
)
    THROW 51000, 'No se encontro el usuario de pruebas fgr con ID 1060. No se borro nada.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.usuario u
    INNER JOIN dbo.roles r ON r.id_rol = u.id_rol
    WHERE u.id_usuario = @UsuarioAnterior
      AND r.rol = N'SUPER_USUARIO'
)
    THROW 51000, 'El usuario indicado es SUPER_USUARIO. Se cancela por seguridad.', 1;

CREATE TABLE #Cargas
(
    id_federal_carga BIGINT NOT NULL PRIMARY KEY,
    codigo_referencia NVARCHAR(50) NOT NULL
);

INSERT INTO #Cargas (id_federal_carga, codigo_referencia)
SELECT id_federal_carga, codigo_referencia
FROM dbo.federal_carga
WHERE id_usuario_carga = @UsuarioAnterior;

SELECT
    N'Usuario a eliminar' AS concepto,
    @UsuarioAnterior AS id_usuario,
    @NombreUsuarioAnterior AS usuario
UNION ALL
SELECT
    N'Cargas federales',
    COUNT_BIG(*),
    NULL
FROM #Cargas;

SELECT
    c.id_federal_carga,
    c.codigo_referencia,
    c.anio_corte,
    c.mes_corte,
    c.estado,
    c.total_carpetas_investigacion,
    c.total_delitos,
    c.total_victimas
FROM dbo.federal_carga c
INNER JOIN #Cargas x
    ON x.id_federal_carga = c.id_federal_carga
ORDER BY c.anio_corte, c.mes_corte;

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC @ResultadoLock = sys.sp_getapplock
        @Resource = N'FGR_REEMPLAZO_USUARIO_DESARROLLO',
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 0;

    IF @ResultadoLock < 0
        THROW 51000, 'Ya existe otra limpieza Federal en ejecucion.', 1;

    /* Historicos: primero las tablas hijas y despues las tablas principales. */
    DELETE vh
    FROM dbo.federal_victima_historico vh
    WHERE EXISTS
    (
        SELECT 1 FROM #Cargas c
        WHERE c.id_federal_carga = vh.id_federal_carga
           OR c.id_federal_carga = vh.id_federal_carga_nueva
    )
    OR EXISTS
    (
        SELECT 1
        FROM dbo.federal_victima v
        WHERE v.id_federal_victima = vh.id_federal_victima
          AND EXISTS (SELECT 1 FROM #Cargas c WHERE c.id_federal_carga = v.id_federal_carga)
    );

    DELETE dh
    FROM dbo.federal_delito_historico dh
    WHERE EXISTS
    (
        SELECT 1 FROM #Cargas c
        WHERE c.id_federal_carga = dh.id_federal_carga
           OR c.id_federal_carga = dh.id_federal_carga_nueva
    )
    OR EXISTS
    (
        SELECT 1
        FROM dbo.federal_delito d
        WHERE d.id_federal_delito = dh.id_federal_delito
          AND EXISTS (SELECT 1 FROM #Cargas c WHERE c.id_federal_carga = d.id_federal_carga)
    );

    DELETE ch
    FROM dbo.federal_carpeta_investigacion_historico ch
    WHERE EXISTS
    (
        SELECT 1 FROM #Cargas c
        WHERE c.id_federal_carga = ch.id_federal_carga
           OR c.id_federal_carga = ch.id_federal_carga_nueva
    )
    OR EXISTS
    (
        SELECT 1
        FROM dbo.federal_carpeta_investigacion ci
        WHERE ci.id_federal_carpeta_investigacion = ch.id_federal_carpeta_investigacion
          AND EXISTS (SELECT 1 FROM #Cargas c WHERE c.id_federal_carga = ci.id_federal_carga)
    );

    /* Temporales, advertencias y bitacora de las cargas del usuario. */
    DELETE FROM dbo.federal_carga_tmp_victima
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    DELETE FROM dbo.federal_carga_tmp_delito
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    DELETE FROM dbo.federal_carga_tmp_carpeta
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    DELETE FROM dbo.federal_carga_advertencia
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    DELETE FROM dbo.federal_carga_bitacora_estado
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    /* Datos definitivos de Federal. */
    DELETE FROM dbo.federal_victima
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    DELETE FROM dbo.federal_delito
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    DELETE FROM dbo.federal_carpeta_investigacion
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    DELETE FROM dbo.federal_carga
    WHERE id_federal_carga IN (SELECT id_federal_carga FROM #Cargas);

    /* Si existe el mapa generado por una prueba anterior, se limpian sus filas FGR. */
    IF OBJECT_ID(N'dbo.federal_migracion_fgr_20260909_mapa', N'U') IS NOT NULL
    BEGIN
        DELETE FROM dbo.federal_migracion_fgr_20260909_mapa
        WHERE codigo_referencia IN (SELECT codigo_referencia FROM #Cargas);
    END;

    /* Se quitan permisos Federal y permisos operativos del usuario de pruebas. */
    DELETE um
    FROM dbo.usuario_modulo um
    INNER JOIN dbo.catalogo_modulo cm
        ON cm.id_modulo = um.id_modulo
       AND cm.clave = N'FEDERAL'
    WHERE um.id_usuario = @UsuarioAnterior;

    DELETE FROM dbo.habilita_carga_modificacion
    WHERE id_usuario = @UsuarioAnterior;

    /* No se elimina si otra tabla del sistema todavía referencia al usuario. */
    CREATE TABLE #ReferenciasRestantes
    (
        esquema_tabla SYSNAME NOT NULL,
        tabla SYSNAME NOT NULL,
        columna SYSNAME NOT NULL,
        registros BIGINT NOT NULL
    );

    DECLARE @Esquema SYSNAME;
    DECLARE @Tabla SYSNAME;
    DECLARE @Columna SYSNAME;
    DECLARE @Comando NVARCHAR(MAX) = N'';

    DECLARE referencias CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        OBJECT_SCHEMA_NAME(fkc.parent_object_id),
        OBJECT_NAME(fkc.parent_object_id),
        COL_NAME(fkc.parent_object_id, fkc.parent_column_id)
    FROM sys.foreign_key_columns fkc
    WHERE fkc.referenced_object_id = OBJECT_ID(N'dbo.usuario');

    OPEN referencias;
    FETCH NEXT FROM referencias INTO @Esquema, @Tabla, @Columna;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Comando += N'
            INSERT INTO #ReferenciasRestantes (esquema_tabla, tabla, columna, registros)
            SELECT N''' + REPLACE(@Esquema, '''', '''''') + N''',
                   N''' + REPLACE(@Tabla, '''', '''''') + N''',
                   N''' + REPLACE(@Columna, '''', '''''') + N''',
                   COUNT_BIG(*)
            FROM ' + QUOTENAME(@Esquema) + N'.' + QUOTENAME(@Tabla) + N'
            WHERE ' + QUOTENAME(@Columna) + N' = @IdUsuario;
';
        FETCH NEXT FROM referencias INTO @Esquema, @Tabla, @Columna;
    END;

    CLOSE referencias;
    DEALLOCATE referencias;

    EXEC sys.sp_executesql
        @Comando,
        N'@IdUsuario INT',
        @IdUsuario = @UsuarioAnterior;

    DELETE FROM #ReferenciasRestantes
    WHERE registros = 0;

    IF EXISTS (SELECT 1 FROM #ReferenciasRestantes)
    BEGIN
        SELECT * FROM #ReferenciasRestantes ORDER BY esquema_tabla, tabla, columna;
        THROW 51000, 'El usuario aun tiene referencias fuera de Federal. La transaccion se revirtio.', 1;
    END;

    DELETE FROM dbo.usuario
    WHERE id_usuario = @UsuarioAnterior;

    /* Se crea la copia de produccion con el mismo hash de password. */
    IF EXISTS (SELECT 1 FROM dbo.usuario WHERE usuario = @NombreUsuarioNuevo)
        THROW 51000, 'El usuario FGRX26011400 ya existe en desarrollo.', 1;

    IF EXISTS (SELECT 1 FROM dbo.usuario WHERE correo_electronico = N'fgr@gmail.com')
        THROW 51000, 'El correo fgr@gmail.com ya pertenece a otro usuario en desarrollo.', 1;

    DECLARE @RolEnlaceEstatal INT;
    DECLARE @ModuloFederal INT;
    DECLARE @NuevoUsuario INT;

    SELECT @RolEnlaceEstatal = id_rol
    FROM dbo.roles
    WHERE rol = N'ENLACE_ESTATAL'
      AND activo = 1;

    SELECT @ModuloFederal = id_modulo
    FROM dbo.catalogo_modulo
    WHERE clave = N'FEDERAL';

    IF @RolEnlaceEstatal IS NULL
        THROW 51000, 'No existe el rol activo ENLACE_ESTATAL.', 1;

    IF @ModuloFederal IS NULL
        THROW 51000, 'No existe el modulo FEDERAL.', 1;

    INSERT INTO dbo.usuario
    (
        usuario,
        [password],
        nombre,
        primer_apellido,
        segundo_apellido,
        correo_electronico,
        rfc,
        curp,
        telefono_contacto,
        id_entidad_federativa,
        fecha_alta,
        fecha_modificacion,
        id_usuario_alta,
        id_usuario_modificacion,
        id_rol,
        activo,
        requiere_cambio_password
    )
    VALUES
    (
        N'FGRX26011400',
        N'$2a$12$1rAuqAZNBq/CA8aYgHxUquGvKEsBhsKJEGacwcEgn5QIy1EU.841u',
        N'FISCALIA',
        N'GENERAL',
        N'REPUBLICA',
        N'fgr@gmail.com',
        NULL,
        NULL,
        NULL,
        NULL,
        CONVERT(DATETIME2(0), '2026-01-14 10:15:25', 120),
        CONVERT(DATETIME2(0), '2026-09-09 18:12:34', 120),
        NULL,
        NULL,
        @RolEnlaceEstatal,
        1,
        0
    );

    SET @NuevoUsuario = CONVERT(INT, SCOPE_IDENTITY());

    INSERT INTO dbo.usuario_modulo
    (
        id_usuario,
        id_modulo,
        habilitado,
        habilita_carga,
        habilita_modificacion,
        administra_delitos,
        id_usuario_modificacion,
        activo
    )
    VALUES
    (
        @NuevoUsuario,
        @ModuloFederal,
        1,
        1,
        1,
        0,
        @NuevoUsuario,
        1
    );

    COMMIT TRANSACTION;

    SELECT
        @NuevoUsuario AS id_usuario_nuevo,
        N'FGRX26011400' AS usuario,
        N'ENLACE_ESTATAL' AS rol,
        N'FEDERAL' AS modulo,
        N'Usuario de pruebas reemplazado correctamente.' AS resultado;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
