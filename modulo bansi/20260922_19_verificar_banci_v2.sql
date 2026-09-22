USE [siiid2];
GO
SET NOCOUNT ON;
-- Sólo lectura. Ejecutar después de 16, 17 y 18 en desarrollo.
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos;

SELECT v.nombre, CASE WHEN OBJECT_ID(N'dbo.' + v.nombre, v.tipo) IS NOT NULL THEN N'EXISTE' ELSE N'FALTA' END AS resultado
FROM (VALUES
    (N'banci_consecutivo_carpeta', N'U'), (N'banci_catalogo_motivo_localizacion', N'U'), (N'banci_actualizacion_v2', N'U'),
    (N'banci_vw_victimas_v2', N'V'), (N'banci_vw_delito_localizacion_catalogo', N'V'),
    (N'sp_banci_asignar_folios_v2', N'P'), (N'sp_banci_procesar_carga_v2', N'P'), (N'sp_banci_vista_previa_v2', N'P'),
    (N'sp_banci_confirmar_carga_v2', N'P'), (N'sp_banci_calcular_actualizacion_v2', N'P'), (N'sp_banci_preparar_actualizacion_v2', N'P'),
    (N'sp_banci_vista_previa_actualizacion_v2', N'P'), (N'sp_banci_confirmar_actualizacion_v2', N'P'), (N'sp_banci_buscar_victimas_v2', N'P')
) v(nombre, tipo);
GO
IF OBJECT_ID(N'dbo.banci_vw_victimas_v2', N'V') IS NULL OR COL_LENGTH(N'dbo.banci_carpeta_investigacion', N'no_banci') IS NULL
    THROW 52590, 'Faltan objetos de la entrega. Revise la ejecución de 16 a 18.', 1;
GO
SELECT COUNT_BIG(*) AS carpetas, SUM(CONVERT(BIGINT, CASE WHEN no_banci IS NULL THEN 1 ELSE 0 END)) AS sin_folio
FROM dbo.banci_carpeta_investigacion;

-- Ambos conjuntos deben estar vacíos al terminar la migración.
SELECT no_banci, COUNT_BIG(*) AS repeticiones FROM dbo.banci_carpeta_investigacion WHERE no_banci IS NOT NULL GROUP BY no_banci HAVING COUNT_BIG(*) > 1;
SELECT id_banci_carpeta_investigacion, no_banci FROM dbo.banci_carpeta_investigacion
WHERE no_banci IS NOT NULL AND (LEN(no_banci) <> 20 OR LEFT(no_banci, 9) <> CONCAT(N'BANCI/', RIGHT(N'00' + CONVERT(NVARCHAR(2), id_entidad_federativa), 2), N'/')
    OR TRY_CONVERT(INT, SUBSTRING(no_banci, 10, 4)) IS NULL OR SUBSTRING(no_banci, 14, 1) <> N'/' OR TRY_CONVERT(INT, RIGHT(no_banci, 6)) NOT BETWEEN 1 AND 999999);

SELECT * FROM dbo.banci_catalogo_motivo_localizacion ORDER BY clave;
SELECT id_entidad_federativa, anio, ultimo FROM dbo.banci_consecutivo_carpeta ORDER BY id_entidad_federativa, anio;

-- No se fuerza la equivalencia de los catálogos viejos: evita inventar datos históricos.
SELECT COUNT_BIG(*) AS victimas_con_motivo_legacy_sin_clasificar_v2 FROM dbo.banci_victima
WHERE voluntaria_o_fue_delito IS NULL AND (voluntaria IS NOT NULL OR fue_delito IS NOT NULL);
SELECT COUNT_BIG(*) AS victimas_historicas_sin_folio_rnpdno FROM dbo.banci_victima WHERE NULLIF(LTRIM(RTRIM(folio_rnpdno)), N'') IS NULL;
SELECT COUNT_BIG(*) AS cargas_v1_pendientes FROM dbo.banci_carga WHERE version_formato = 1 AND estado = N'VALIDADO_PENDIENTE';

-- Las vistas compilan y conservan disponibles las columnas del contrato sin mostrar datos personales.
SELECT TOP (0) * FROM dbo.banci_vw_victimas_v2;
SELECT TOP (0) * FROM dbo.banci_vw_delito_localizacion_catalogo;

SELECT OBJECT_NAME(parent_object_id) AS tabla, name, is_disabled, is_not_trusted FROM sys.foreign_keys
WHERE name IN (N'FK_banci_victima_motivo_localizacion', N'FK_banci_historial_actualizacion_v2');
