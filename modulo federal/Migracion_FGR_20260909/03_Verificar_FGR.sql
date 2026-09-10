-- SSMS, base siiid2. Ejecutar inmediatamente despues de la migracion.
-- Solo lectura; no requiere Modo SQLCMD.
USE [siiid2];
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.federal_migracion_fgr_20260909_mapa', N'U') IS NULL
    THROW 51000, 'No existe el mapa de la migracion. Revise el resultado de 01_Migrar_FGR.sql.', 1;

SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_datos;
SELECT tipo, COUNT_BIG(*) AS registros_mapeados
FROM dbo.federal_migracion_fgr_20260909_mapa
GROUP BY tipo ORDER BY tipo;

SELECT c.id_federal_carga, c.codigo_referencia, c.anio_corte, c.mes_corte,
       c.id_usuario_carga, u.usuario, c.estado, c.activo,
       c.total_carpetas_investigacion AS carpetas_declaradas,
       (SELECT COUNT_BIG(*) FROM dbo.federal_carpeta_investigacion x WHERE x.id_federal_carga = c.id_federal_carga) AS carpetas_insertadas,
       c.total_delitos AS delitos_declarados,
       (SELECT COUNT_BIG(*) FROM dbo.federal_delito x WHERE x.id_federal_carga = c.id_federal_carga) AS delitos_insertados,
       c.total_victimas AS victimas_declaradas,
       (SELECT COUNT_BIG(*) FROM dbo.federal_victima x WHERE x.id_federal_carga = c.id_federal_carga) AS victimas_insertadas
FROM dbo.federal_migracion_fgr_20260909_mapa m
JOIN dbo.federal_carga c ON c.id_federal_carga = m.id_destino
JOIN dbo.usuario u ON u.id_usuario = c.id_usuario_carga
WHERE m.tipo = N'CARGA'
ORDER BY c.anio_corte, c.mes_corte;

SELECT N'Pares de delitos preservados (esperado 115)' AS comprobacion, COUNT_BIG(*) AS resultado
FROM
(
    SELECT d.id_federal_carpeta_investigacion, d.identificador_delito_fiscalia
    FROM dbo.federal_delito d
    JOIN dbo.federal_migracion_fgr_20260909_mapa m ON m.tipo = N'DELITO' AND m.id_destino = d.id_federal_delito
    GROUP BY d.id_federal_carpeta_investigacion, d.identificador_delito_fiscalia
    HAVING COUNT_BIG(*) = 2
) p;

SELECT N'Victimas sin delito o con otro envio (esperado 0)' AS comprobacion, COUNT_BIG(*) AS resultado
FROM dbo.federal_migracion_fgr_20260909_mapa m
JOIN dbo.federal_victima v ON v.id_federal_victima = m.id_destino
LEFT JOIN dbo.federal_delito d ON d.id_federal_delito = v.id_federal_delito
WHERE m.tipo = N'VICTIMA' AND (d.id_federal_delito IS NULL OR d.id_federal_carga <> v.id_federal_carga);

SELECT N'Autor distinto de FGR 68 (esperado 0)' AS comprobacion, COUNT_BIG(*) AS resultado
FROM
(
    SELECT d.id_usuario_registro FROM dbo.federal_carpeta_investigacion d
    JOIN dbo.federal_migracion_fgr_20260909_mapa m ON m.tipo = N'CARPETA' AND m.id_destino = d.id_federal_carpeta_investigacion
    UNION ALL
    SELECT d.id_usuario_registro FROM dbo.federal_delito d
    JOIN dbo.federal_migracion_fgr_20260909_mapa m ON m.tipo = N'DELITO' AND m.id_destino = d.id_federal_delito
    UNION ALL
    SELECT d.id_usuario_registro FROM dbo.federal_victima d
    JOIN dbo.federal_migracion_fgr_20260909_mapa m ON m.tipo = N'VICTIMA' AND m.id_destino = d.id_federal_victima
) a
WHERE a.id_usuario_registro <> 68;
GO
