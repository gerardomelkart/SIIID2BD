-- Después del 13. Publicar API y Front coordinados. No elimina datos ni cambia identificadores.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.banci_operacion_vinculada',N'U') IS NULL
    THROW 51000, 'Falta instalar el modelo mensual BANCI (scripts 11 a 13).', 1;
IF COL_LENGTH('dbo.banci_victima','reclasificada') IS NULL
    ALTER TABLE dbo.banci_victima ADD reclasificada BIT NOT NULL CONSTRAINT DF_banci_victima_reclasificada DEFAULT(0);
IF COL_LENGTH('dbo.banci_reclasificado','id_banci_victima') IS NULL
BEGIN
    ALTER TABLE dbo.banci_reclasificado ADD id_banci_victima BIGINT NULL REFERENCES dbo.banci_victima(id_banci_victima),
        es_reclasificacion BIT NOT NULL CONSTRAINT DF_banci_reclasificado_movimiento DEFAULT(1);
    EXEC(N'CREATE INDEX IX_banci_reclasificado_victima ON dbo.banci_reclasificado(id_banci_victima,fecha_utc);');
END;
-- Se actualiza por víctima sin cambiar el delito compartido con otras víctimas.
EXEC(N'UPDATE v SET reclasificada=CASE WHEN c.codigo_regla=N''NO_DELITO'' THEN 1
 WHEN c.codigo_regla=N''DELITO'' AND v.motivo_desaparicion IS NOT NULL AND NOT EXISTS(
 SELECT 1 FROM dbo.banci_catalogo_clasificacion_delito bc
 JOIN dbo.catalogo_modalidad_delito md ON md.clave4=bc.clave
 JOIN dbo.catalogo_subtipo_delito sd ON sd.id_subtipo_delito=md.id_subtipo_delito
 JOIN dbo.catalogo_delito cd ON cd.id_delito=sd.id_delito
 WHERE bc.activo=1 AND (v.motivo_desaparicion=md.clave4 OR v.motivo_desaparicion=cd.clave2)) THEN 1 ELSE 0 END
 FROM dbo.banci_victima v LEFT JOIN dbo.banci_catalogo_constitutiva_delito c ON c.clave=v.constitutiva_delito;');
-- La migración conserva como eventos las reclasificaciones que ya estaban aprobadas.
EXEC(N'IF EXISTS(SELECT 1 FROM dbo.banci_victima WHERE reclasificada=1 AND NULLIF(LTRIM(RTRIM(motivo_desaparicion)),N'''') IS NULL)
 THROW 51002, ''Hay reclasificaciones previas sin motivo. Complete sus datos en BANCI antes de habilitar el cruce.'', 1;
INSERT dbo.banci_reclasificado(id_banci_delito,id_banci_victima,id_banci_carga,constitutiva_delito,motivo,snapshot_previo,id_usuario,es_reclasificacion)
SELECT v.id_banci_delito,v.id_banci_victima,v.id_banci_carga,v.constitutiva_delito,v.motivo_desaparicion,
 (SELECT N''Migración de reclasificación previamente aprobada'' AS origen,v.id_vicf,v.constitutiva_delito,v.motivo_desaparicion FOR JSON PATH,WITHOUT_ARRAY_WRAPPER),
 COALESCE(c.id_usuario_aprobacion,c.id_usuario_carga),1
FROM dbo.banci_victima v JOIN dbo.banci_carga c ON c.id_banci_carga=v.id_banci_carga
WHERE v.reclasificada=1 AND NOT EXISTS(SELECT 1 FROM dbo.banci_reclasificado r WHERE r.id_banci_victima=v.id_banci_victima);');
EXEC(N'CREATE OR ALTER VIEW dbo.vw_banci_desaparicion_vigente AS
 SELECT v.* FROM dbo.banci_victima v JOIN dbo.banci_delito d ON d.id_banci_delito=v.id_banci_delito
 JOIN dbo.banci_carpeta_investigacion ci ON ci.id_banci_carpeta_investigacion=d.id_banci_carpeta_investigacion
 WHERE v.activo=1 AND v.reclasificada=0 AND d.activo=1 AND ci.activo=1;');
UPDATE c SET descripcion=N'Cruzar actualizaciones del Consolidado con BANCI: reclasificaciones aprobadas y complementos de nuevas desapariciones',habilitado=CASE WHEN disponible=0 THEN 1 ELSE habilitado END,disponible=1
FROM dbo.sistema_configuracion c JOIN dbo.catalogo_modulo m ON m.id_modulo=c.id_modulo
WHERE m.clave=N'MENSUAL' AND c.clave=N'CRUCE_ACTUALIZACION_CONSOLIDADO';
IF @@ROWCOUNT<>1 THROW 51001, 'Falta la opción mensual de cruce. Ejecute primero el script 13.', 1;
UPDATE dbo.sistema_configuracion_version SET version=version+1 WHERE id=1;
COMMIT;
