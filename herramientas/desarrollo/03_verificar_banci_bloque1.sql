-- SOLO LECTURA: comprobar bloque 1 después de publicar los paquetes coordinados.
SET NOCOUNT ON;
DECLARE @Errores TABLE(mensaje NVARCHAR(2000));
INSERT @Errores SELECT N'Falta tabla: '+nombre FROM(VALUES (N'banci_carga'),(N'banci_carga_archivo'),(N'banci_carga_bitacora_estado'),(N'banci_carga_observacion'),(N'banci_carga_tmp_carpeta'),(N'banci_carga_tmp_delito'),(N'banci_carga_tmp_victima'),(N'banci_consecutivo_carpeta'),(N'banci_carpeta_investigacion'),(N'banci_delito'),(N'banci_victima'),(N'banci_historial_cambio'),(N'banci_reclasificado'),(N'banci_operacion_vinculada'))v(nombre)
WHERE OBJECT_ID(N'dbo.'+v.nombre,N'U') IS NULL;
INSERT @Errores SELECT N'Sigue presente objeto retirado: '+nombre FROM(VALUES (N'sp_banci_confirmar_carga_v2'),(N'sp_banci_procesar_carga'),(N'sp_banci_vista_previa_v2'),(N'sp_banci_vista_previa'),(N'banci_vw_victimas_v2'),(N'sp_banci_confirmar_carga'),(N'sp_banci_confirmar_actualizacion_v2'),(N'sp_banci_calcular_actualizacion_v2'),(N'sp_banci_vista_previa_actualizacion_v2'),(N'sp_banci_asignar_folios_v2'),(N'sp_banci_procesar_carga_v2'),(N'sp_banci_buscar_victimas_v2'),(N'sp_banci_preparar_actualizacion_v2'),(N'fn_banci_es_usuario_federal'),(N'fn_banci_puede_actualizar_victima'),(N'banci_cruce_federal'),(N'banci_cruce_mensual'),(N'banci_actualizacion_v2'),(N'banci_catalogo_voluntaria'),(N'banci_catalogo_fue_delito'),(N'banci_catalogo_motivo_localizacion'))v(nombre)
WHERE OBJECT_ID(N'dbo.'+v.nombre) IS NOT NULL;
INSERT @Errores SELECT N'Sigue presente opción vieja de cruce.' WHERE EXISTS(SELECT 1 FROM dbo.sistema_configuracion WHERE clave=N'CRUCE_BANCI');
INSERT @Errores SELECT N'Falta configuración BANCI: '+v.clave FROM(VALUES(N'PERMITIR_CORTES_ANTERIORES'),(N'VALIDACIONES_CAMPOS'),(N'CRUCE_ACTUALIZACION_CONSOLIDADO'))v(clave)
WHERE NOT EXISTS(SELECT 1 FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo WHERE m.clave=N'BANCI' AND c.clave=v.clave);
INSERT @Errores SELECT N'FK deshabilitada/no confiable: '+f.name FROM sys.foreign_keys f
WHERE OBJECT_NAME(f.parent_object_id) LIKE N'banci[_]%' AND(f.is_disabled=1 OR f.is_not_trusted=1);
INSERT @Errores SELECT N'Falta corte en carga BANCI.' WHERE COL_LENGTH(N'dbo.banci_carga',N'mes_corte') IS NULL;
INSERT @Errores SELECT N'Falta mantenimiento BANCI.' WHERE OBJECT_ID(N'dbo.usp_mantenimiento_banci',N'P') IS NULL;
INSERT @Errores SELECT DISTINCT N'Dependencia pendiente: '+OBJECT_SCHEMA_NAME(m.object_id)+N'.'+OBJECT_NAME(m.object_id)
FROM sys.sql_modules m CROSS JOIN(VALUES (N'sp_banci_confirmar_carga_v2'),(N'sp_banci_procesar_carga'),(N'sp_banci_vista_previa_v2'),(N'sp_banci_vista_previa'),(N'banci_vw_victimas_v2'),(N'sp_banci_confirmar_carga'),(N'sp_banci_confirmar_actualizacion_v2'),(N'sp_banci_calcular_actualizacion_v2'),(N'sp_banci_vista_previa_actualizacion_v2'),(N'sp_banci_asignar_folios_v2'),(N'sp_banci_procesar_carga_v2'),(N'sp_banci_buscar_victimas_v2'),(N'sp_banci_preparar_actualizacion_v2'),(N'fn_banci_es_usuario_federal'),(N'fn_banci_puede_actualizar_victima'),(N'banci_cruce_federal'),(N'banci_cruce_mensual'),(N'banci_actualizacion_v2'),(N'banci_catalogo_voluntaria'),(N'banci_catalogo_fue_delito'),(N'banci_catalogo_motivo_localizacion'))v(nombre)
WHERE CHARINDEX(v.nombre,m.definition COLLATE Latin1_General_100_CI_AS)>0;
IF EXISTS(SELECT 1 FROM @Errores)
BEGIN
 SELECT * FROM @Errores;
 THROW 52920,'El bloque 1 no pasó las comprobaciones. Revisar resultados.',1;
END;
SELECT @@SERVERNAME AS servidor,DB_NAME() AS base_actual,N'Bloque 1: objetos y dependencias verificados.' AS resultado;
SELECT m.clave AS modulo,c.clave,c.habilitado,c.disponible FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo WHERE m.clave=N'BANCI' ORDER BY c.clave;
