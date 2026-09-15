USE [siiid2];
GO
SET NOCOUNT ON;

-- Sólo consultas. Las cargas 5/6 no se cambian ni se vuelven a procesar.
SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos, SERVERPROPERTY('Edition') AS edicion;

SELECT c.name AS columna, TYPE_NAME(c.user_type_id) AS tipo, c.max_length, c.scale, c.is_nullable
FROM sys.columns c
WHERE c.object_id = OBJECT_ID(N'dbo.banci_carga')
  AND c.name IN (N'estado', N'aceptada_usuario', N'id_usuario_confirmacion', N'fecha_confirmacion')
ORDER BY c.column_id;

SELECT name, definition, is_disabled, is_not_trusted
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID(N'dbo.banci_carga')
  AND name IN (N'CK_banci_carga_estado', N'CK_banci_carga_decision');

SELECT name, is_disabled, is_not_trusted
FROM sys.foreign_keys
WHERE name IN (N'FK_banci_carga_confirmacion_usuario', N'FK_banci_bitacora_carga', N'FK_banci_bitacora_usuario');

SELECT o.name, o.type_desc, o.modify_date
FROM sys.objects o
WHERE o.object_id IN
(
    OBJECT_ID(N'dbo.sp_banci_procesar_carga'),
    OBJECT_ID(N'dbo.sp_banci_confirmar_carga'),
    OBJECT_ID(N'dbo.banci_carga_bitacora_estado')
);

SELECT name AS parametro, TYPE_NAME(user_type_id) AS tipo, max_length
FROM sys.parameters WHERE object_id = OBJECT_ID(N'dbo.sp_banci_confirmar_carga') ORDER BY parameter_id;

SELECT estado, COUNT_BIG(*) AS operaciones,
       SUM(CASE WHEN aceptada_usuario IS NULL THEN CONVERT(BIGINT, 1) ELSE 0 END) AS sin_decision_registrada
FROM dbo.banci_carga GROUP BY estado ORDER BY estado;

DECLARE @IdEntidad TINYINT = 14; -- Jalisco; cambiar sólo si se prueba otra entidad.

SELECT id_banci_carga, codigo_referencia, id_usuario_carga, estado,
       aceptada_usuario, id_usuario_confirmacion, fecha_confirmacion,
       total_carpetas, total_delitos, total_victimas,
       total_altas, total_actualizaciones, total_sin_cambio, total_advertencias,
       fecha_carga, fecha_inicio_procesamiento, fecha_fin_procesamiento
FROM dbo.banci_carga WHERE id_entidad_federativa = @IdEntidad ORDER BY id_banci_carga;

SELECT N'carpetas_vivas' AS tabla, COUNT_BIG(*) AS registros
FROM dbo.banci_carpeta_investigacion WHERE id_entidad_federativa = @IdEntidad
UNION ALL
SELECT N'delitos_vivos', COUNT_BIG(*) FROM dbo.banci_delito d
JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion WHERE c.id_entidad_federativa = @IdEntidad
UNION ALL
SELECT N'victimas_vivas', COUNT_BIG(*) FROM dbo.banci_victima v
JOIN dbo.banci_delito d ON d.id_banci_delito = v.id_banci_delito
JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion WHERE c.id_entidad_federativa = @IdEntidad
UNION ALL
SELECT N'historial_datos', COUNT_BIG(*) FROM dbo.banci_historial_cambio WHERE id_entidad_federativa = @IdEntidad;

SELECT b.* FROM dbo.banci_carga_bitacora_estado b
JOIN dbo.banci_carga c ON c.id_banci_carga = b.id_banci_carga
WHERE c.id_entidad_federativa = @IdEntidad ORDER BY b.id_banci_carga_bitacora_estado;
