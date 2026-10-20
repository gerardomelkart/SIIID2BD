-- Solo lectura. Ejecutar después de instalar el script 14 y completar las pruebas de QA.
SET NOCOUNT ON;
SELECT ci.id_entidad_federativa,ci.anio_corte,ci.mes_corte,
       COUNT(*) AS victimas_conservadas,SUM(CASE WHEN v.reclasificada=0 THEN 1 ELSE 0 END) AS desapariciones_vigentes,
       SUM(CASE WHEN v.reclasificada=1 THEN 1 ELSE 0 END) AS reclasificadas
FROM dbo.banci_victima v JOIN dbo.banci_delito d ON d.id_banci_delito=v.id_banci_delito
JOIN dbo.banci_carpeta_investigacion ci ON ci.id_banci_carpeta_investigacion=d.id_banci_carpeta_investigacion
WHERE ci.activo=1 AND d.activo=1 AND v.activo=1
GROUP BY ci.id_entidad_federativa,ci.anio_corte,ci.mes_corte;

-- Debe devolver cero filas después de resolver operaciones: no puede haber integración parcial.
SELECT ov.id_carga_consolidado,ov.id_banci_carga,c.estado AS estado_consolidado,b.estado AS estado_banci
FROM dbo.banci_operacion_vinculada ov JOIN dbo.carga c ON c.id_carga=ov.id_carga_consolidado
JOIN dbo.banci_carga b ON b.id_banci_carga=ov.id_banci_carga
WHERE (c.estado='CONFIRMADO_ACTUALIZACION' AND b.estado<>'CONFIRMADO_ACTUALIZACION')
   OR (b.estado='CONFIRMADO_ACTUALIZACION' AND c.estado<>'CONFIRMADO_ACTUALIZACION')
   OR (c.estado='RECHAZADO_ADMIN' AND b.estado<>'RECHAZADO_ADMIN');

-- Histórico por víctima: incluye reversos, sin mostrar nombres ni datos personales.
SELECT id_banci_reclasificado,id_banci_victima,id_banci_delito,id_banci_carga,es_reclasificacion,constitutiva_delito,motivo,fecha_utc
FROM dbo.banci_reclasificado ORDER BY fecha_utc DESC;
SELECT m.clave AS modulo,c.clave,c.habilitado,c.disponible FROM dbo.sistema_configuracion c
JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo WHERE c.clave='CRUCE_ACTUALIZACION_CONSOLIDADO';
