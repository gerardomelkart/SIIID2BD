USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @EjecutarBorrado BIT = 1;

/* ============================================================
   LIMPIEZA TOTAL DEL MÓDULO PRELIMINAR / SEMANAL
   NO TOCA TABLAS DEL MÓDULO MENSUAL
   ============================================================ */

DECLARE @Tablas TABLE
(
    orden INT NOT NULL,
    tabla SYSNAME NOT NULL
);

INSERT INTO @Tablas(orden, tabla)
VALUES
    (10, N'semanal_victima_historico'),
    (20, N'semanal_delito_historico'),
    (30, N'semanal_carpeta_investigacion_historico'),
    (40, N'semanal_victima'),
    (50, N'semanal_delito'),
    (60, N'semanal_carpeta_investigacion'),
    (70, N'semanal_carga_advertencia'),
    (80, N'semanal_carga_tmp_victima'),
    (90, N'semanal_carga_tmp_delito'),
    (100, N'semanal_carga_tmp_carpeta'),
    (110, N'semanal_carga_delito_configurado'),
    (120, N'semanal_carga_bloque'),
    (130, N'semanal_carga');

/* ============================================================
   1. MOSTRAR LAS TABLAS SEMANALES EXISTENTES EN LA BD
   ============================================================ */

SELECT
    t.name AS tabla_semanal_existente
FROM sys.tables t
WHERE t.schema_id = SCHEMA_ID(N'dbo')
  AND t.name LIKE N'semanal[_]%'
ORDER BY t.name;

/* ============================================================
   2. MOSTRAR SI EXISTE ALGUNA TABLA SEMANAL NO CONTEMPLADA
   ============================================================ */

SELECT
    t.name AS tabla_semanal_no_contemplada
FROM sys.tables t
WHERE t.schema_id = SCHEMA_ID(N'dbo')
  AND t.name LIKE N'semanal[_]%'
  AND NOT EXISTS
  (
      SELECT 1
      FROM @Tablas x
      WHERE x.tabla = t.name
  )
ORDER BY t.name;

/* ============================================================
   3. CONTEO PREVIO
   ============================================================ */

DECLARE @SqlConteo NVARCHAR(MAX) = N'';

SELECT @SqlConteo = @SqlConteo +
    N'SELECT N''' + REPLACE(tabla, '''', '''''') + N''' AS tabla, COUNT_BIG(1) AS registros FROM dbo.'
    + QUOTENAME(tabla) + N';' + CHAR(13) + CHAR(10)
FROM @Tablas
WHERE OBJECT_ID(N'dbo.' + tabla, N'U') IS NOT NULL
ORDER BY orden;

EXEC sys.sp_executesql @SqlConteo;

/* ============================================================
   4. PROTECCIÓN
   ============================================================ */

IF @EjecutarBorrado = 0
BEGIN
    PRINT N'============================================================';
    PRINT N'MODO CONSULTA: NO SE BORRÓ NADA.';
    PRINT N'Revisa las tablas y conteos anteriores.';
    PRINT N'Para ejecutar el borrado cambia @EjecutarBorrado a 1.';
    PRINT N'============================================================';
    RETURN;
END;

/* ============================================================
   5. BORRADO TOTAL
   ============================================================ */

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM dbo.semanal_victima_historico;
    DELETE FROM dbo.semanal_delito_historico;
    DELETE FROM dbo.semanal_carpeta_investigacion_historico;

    DELETE FROM dbo.semanal_victima;
    DELETE FROM dbo.semanal_delito;
    DELETE FROM dbo.semanal_carpeta_investigacion;

    DELETE FROM dbo.semanal_carga_advertencia;

    DELETE FROM dbo.semanal_carga_tmp_victima;
    DELETE FROM dbo.semanal_carga_tmp_delito;
    DELETE FROM dbo.semanal_carga_tmp_carpeta;

    DELETE FROM dbo.semanal_carga_delito_configurado;
    DELETE FROM dbo.semanal_carga_bloque;

    DELETE FROM dbo.semanal_carga;

    /* Reiniciar identidades únicamente de estas tablas */
    DECLARE @Tabla SYSNAME;
    DECLARE @SqlReseed NVARCHAR(MAX);

    DECLARE cursor_reseed CURSOR LOCAL FAST_FORWARD FOR
        SELECT x.tabla
        FROM @Tablas x
        WHERE OBJECT_ID(N'dbo.' + x.tabla, N'U') IS NOT NULL
          AND EXISTS
          (
              SELECT 1
              FROM sys.identity_columns ic
              WHERE ic.object_id = OBJECT_ID(N'dbo.' + x.tabla)
          )
        ORDER BY x.orden;

    OPEN cursor_reseed;

    FETCH NEXT FROM cursor_reseed INTO @Tabla;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SqlReseed =
            N'DBCC CHECKIDENT (''dbo.' +
            REPLACE(@Tabla, '''', '''''') +
            N''', RESEED, 0) WITH NO_INFOMSGS;';

        EXEC sys.sp_executesql @SqlReseed;

        FETCH NEXT FROM cursor_reseed INTO @Tabla;
    END;

    CLOSE cursor_reseed;
    DEALLOCATE cursor_reseed;

    COMMIT TRANSACTION;

    PRINT N'============================================================';
    PRINT N'LIMPIEZA DEL MÓDULO PRELIMINAR COMPLETADA.';
    PRINT N'============================================================';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

    IF CURSOR_STATUS('local', 'cursor_reseed') >= -1
    BEGIN
        CLOSE cursor_reseed;
        DEALLOCATE cursor_reseed;
    END;

    THROW;
END CATCH;

/* ============================================================
   6. VALIDACIÓN FINAL
   ============================================================ */

DECLARE @SqlValidacion NVARCHAR(MAX) = N'';

SELECT @SqlValidacion = @SqlValidacion +
    N'SELECT N''' + REPLACE(tabla, '''', '''''') + N''' AS tabla, COUNT_BIG(1) AS registros FROM dbo.'
    + QUOTENAME(tabla) + N';' + CHAR(13) + CHAR(10)
FROM @Tablas
WHERE OBJECT_ID(N'dbo.' + tabla, N'U') IS NOT NULL
ORDER BY orden;

EXEC sys.sp_executesql @SqlValidacion;
GO