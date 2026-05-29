DROP TEMPORARY TABLE IF EXISTS tmp_ent_del_sabana;
CREATE TEMPORARY TABLE tmp_ent_del_sabana AS
SELECT
  2026 as anio_corte,
  e.cve_ent,
  e.nom_ent,
  s.id_del,
  s.bien_juridico,
  s.delito_sabana,
  s.subtipo_delito_sabana,
  s.modalidad_delito_sabana
FROM cat_entidades e
CROSS JOIN cat_delitos_sabana s
WHERE cve_ent<>33
GROUP BY e.cve_ent, e.nom_ent, s.id_del, s.bien_juridico, s.delito_sabana, s.subtipo_delito_sabana, s.modalidad_delito_sabana;

ALTER TABLE tmp_ent_del_sabana
  ADD INDEX idx_eds (cve_ent, id_del);
 
DROP TEMPORARY TABLE IF EXISTS tmp_conteos;
CREATE TEMPORARY TABLE tmp_conteos AS
SELECT
  a.anio_corte,
  a.mes_corte,
  a.id_ent_hchos AS cve_ent,
  d.id_del,
  a.grdo_cons    AS id_grdo_cons,
  a.emto_com_dto AS id_emto_com_dto,
  a.forma_acc    AS id_forma_acc,
  COUNT(*)       AS cantidad_delitos
FROM tbl_delitos a
JOIN cat_delitos d ON d.clave4  = a.clasf_de_dto
WHERE #a.mes_corte >= 7 AND
usuario_reg<>'FGRX26011400'
GROUP BY
  a.anio_corte, a.mes_corte, a.id_ent_hchos,
  d.id_del, a.grdo_cons, a.emto_com_dto, a.forma_acc;
 
DROP TEMPORARY TABLE IF EXISTS tmp_conteos_sabana;
CREATE TEMPORARY TABLE tmp_conteos_sabana AS
SELECT
  a.anio_corte,
  a.mes_corte,
  a.cve_ent,
  d.id_del,
  d.delito_sabana,
  d.subtipo_delito_sabana,
  d.modalidad_delito_sabana,
  SUM(cantidad_delitos) AS cantidad_delitos
FROM tmp_conteos a
JOIN cat_delitos_sabana d
  ON d.id_del = a.id_del AND a.id_grdo_cons=d.id_grdo_cons
  AND a.id_emto_com_dto=d.id_emto_com_dto
  AND a.id_forma_acc=d.id_forma_acc
GROUP BY
  a.anio_corte, a.mes_corte, a.cve_ent, d.id_del, d.delito_sabana, d.subtipo_delito_sabana, d.modalidad_delito_sabana;

ALTER TABLE tmp_conteos_sabana
  ADD INDEX idx_eds (cve_ent, id_del);

SELECT
  c.anio_corte AS `Año`,
  c.cve_ent    AS `Clave_Ent`,
  nom_ent    AS `Entidad`,
  bien_juridico AS `Bien jurídico afectado`,
  c.delito_sabana AS `Tipo de delito`,
  c.subtipo_delito_sabana AS `Subtipo de delito`,
  c.modalidad_delito_sabana AS `Modalidad`,
SUM(CASE WHEN s.mes_corte = 1 THEN s.cantidad_delitos ELSE 0 END) AS Enero,
SUM(CASE WHEN s.mes_corte = 2 THEN s.cantidad_delitos ELSE 0 END) AS Febrero,
SUM(CASE WHEN s.mes_corte = 3 THEN s.cantidad_delitos ELSE 0 END) AS Marzo,
SUM(CASE WHEN s.mes_corte = 4 THEN s.cantidad_delitos ELSE 0 END) AS Abril,
SUM(CASE WHEN s.mes_corte = 5 THEN s.cantidad_delitos ELSE 0 END) AS Mayo,
SUM(CASE WHEN s.mes_corte = 6 THEN s.cantidad_delitos ELSE 0 END) AS Junio,
SUM(CASE WHEN s.mes_corte = 7 THEN s.cantidad_delitos ELSE 0 END) AS Julio,
SUM(CASE WHEN s.mes_corte = 8 THEN s.cantidad_delitos ELSE 0 END) AS Agosto,
SUM(CASE WHEN s.mes_corte = 9 THEN s.cantidad_delitos ELSE 0 END) AS Septiembre,
SUM(CASE WHEN s.mes_corte = 10 THEN s.cantidad_delitos ELSE 0 END) AS Octubre,
SUM(CASE WHEN s.mes_corte = 11 THEN s.cantidad_delitos ELSE 0 END) AS Noviembre,
SUM(CASE WHEN s.mes_corte = 12 THEN s.cantidad_delitos ELSE 0 END) AS Diciembre
FROM tmp_ent_del_sabana c
LEFT JOIN tmp_conteos_sabana s
ON c.anio_corte=s.anio_corte AND c.cve_ent=s.cve_ent AND c.id_del=s.id_del AND c.modalidad_delito_sabana=s.modalidad_delito_sabana
GROUP BY c.anio_corte, c.cve_ent, nom_ent, bien_juridico, c.delito_sabana, c.subtipo_delito_sabana,
c.modalidad_delito_sabana
ORDER BY c.cve_ent, c.id_del, c.subtipo_delito_sabana, c.modalidad_delito_sabana;
