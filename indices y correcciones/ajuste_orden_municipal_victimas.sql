USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @EjecutarAjuste BIT = 0; -- 0 = prueba con ROLLBACK, 1 = aplica con COMMIT

BEGIN TRY
    BEGIN TRANSACTION;

    ;WITH orden AS (
        SELECT N'El patrimonio' AS bien_juridico, N'Abuso de confianza' AS delito_sabana, N'Abuso de confianza' AS subtipo_delito_sabana, N'Abuso de confianza' AS modalidad_delito_sabana, 1 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Daño a la propiedad' AS delito_sabana, N'Daño a la propiedad' AS subtipo_delito_sabana, N'Daño a la propiedad' AS modalidad_delito_sabana, 2 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Despojo' AS delito_sabana, N'Despojo' AS subtipo_delito_sabana, N'Despojo' AS modalidad_delito_sabana, 3 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Extorsión por otros medios' AS subtipo_delito_sabana, N'Extorsión por otros medios' AS modalidad_delito_sabana, 4 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Extorsión presencial' AS subtipo_delito_sabana, N'Extorsión presencial' AS modalidad_delito_sabana, 5 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Tentativa de extorsión por otros medios' AS subtipo_delito_sabana, N'Tentativa de extorsión por otros medios' AS modalidad_delito_sabana, 6 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Extorsión' AS delito_sabana, N'Tentativa de extorsión presencial' AS subtipo_delito_sabana, N'Tentativa de extorsión presencial' AS modalidad_delito_sabana, 7 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Fraude' AS delito_sabana, N'Fraude' AS subtipo_delito_sabana, N'Fraude' AS modalidad_delito_sabana, 8 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Otros delitos contra el patrimonio' AS delito_sabana, N'Otros delitos contra el patrimonio' AS subtipo_delito_sabana, N'Otros delitos contra el patrimonio' AS modalidad_delito_sabana, 9 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Otros robos' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 10 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Otros robos' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 11 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a casa habitación' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 12 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a casa habitación' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 13 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a institución bancaria' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 14 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a institución bancaria' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 15 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a negocio' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 16 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a negocio' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 17 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en espacio abierto al público' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 18 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en espacio abierto al público' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 19 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en vía pública' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 20 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transeúnte en vía pública' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 21 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transportista' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 22 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo a transportista' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 23 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de autopartes' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 24 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de autopartes' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 25 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de ganado' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 26 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de ganado' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 27 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Cables, tubos y otros objetos destinados a servicios públicos' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 28 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Cables, tubos y otros objetos destinados a servicios públicos' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 29 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Herramienta industrial o agrícola' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 30 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Herramienta industrial o agrícola' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 31 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Tractores y/o montacargas' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 32 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de maquinaria - Tractores y/o montacargas' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 33 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Coche de 4 ruedas' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 34 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Coche de 4 ruedas' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 35 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Embarcaciones' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 36 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Embarcaciones' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 37 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Motocicleta' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 38 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo de vehículo automotor - Motocicleta' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 39 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte individual' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 40 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte individual' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 41 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público colectivo' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 42 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público colectivo' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 43 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público individual' AS subtipo_delito_sabana, N'Con violencia' AS modalidad_delito_sabana, 44 AS orden_municipal_victimas
        UNION ALL
        SELECT N'El patrimonio' AS bien_juridico, N'Robo' AS delito_sabana, N'Robo en transporte público individual' AS subtipo_delito_sabana, N'Sin violencia' AS modalidad_delito_sabana, 45 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La familia' AS bien_juridico, N'Incumplimiento de obligaciones de asistencia familiar' AS delito_sabana, N'Incumplimiento de obligaciones de asistencia familiar' AS subtipo_delito_sabana, N'Incumplimiento de obligaciones de asistencia familiar' AS modalidad_delito_sabana, 46 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La familia' AS bien_juridico, N'Otros delitos contra la familia' AS delito_sabana, N'Otros delitos contra la familia' AS subtipo_delito_sabana, N'Otros delitos contra la familia' AS modalidad_delito_sabana, 47 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La familia' AS bien_juridico, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS delito_sabana, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS subtipo_delito_sabana, N'Violencia de género en todas sus modalidades distinta a la violencia familiar' AS modalidad_delito_sabana, 48 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La familia' AS bien_juridico, N'Violencia familiar' AS delito_sabana, N'Violencia familiar' AS subtipo_delito_sabana, N'Violencia familiar' AS modalidad_delito_sabana, 49 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Abuso sexual' AS delito_sabana, N'Abuso sexual' AS subtipo_delito_sabana, N'Abuso sexual' AS modalidad_delito_sabana, 50 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Acoso sexual' AS delito_sabana, N'Acoso sexual' AS subtipo_delito_sabana, N'Acoso sexual' AS modalidad_delito_sabana, 51 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Hostigamiento sexual' AS delito_sabana, N'Hostigamiento sexual' AS subtipo_delito_sabana, N'Hostigamiento sexual' AS modalidad_delito_sabana, 52 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Incesto' AS delito_sabana, N'Incesto' AS subtipo_delito_sabana, N'Incesto' AS modalidad_delito_sabana, 53 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS delito_sabana, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la libertad y la seguridad sexual' AS modalidad_delito_sabana, 54 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación' AS delito_sabana, N'Violación equiparada' AS subtipo_delito_sabana, N'Violación equiparada' AS modalidad_delito_sabana, 55 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación' AS delito_sabana, N'Violación simple' AS subtipo_delito_sabana, N'Violación simple' AS modalidad_delito_sabana, 56 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La libertad y la seguridad sexual' AS bien_juridico, N'Violación a la intimidad sexual' AS delito_sabana, N'Violación a la intimidad sexual' AS subtipo_delito_sabana, N'Violación a la intimidad sexual' AS modalidad_delito_sabana, 57 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Corrupción de menores' AS delito_sabana, N'Corrupción de menores' AS subtipo_delito_sabana, N'Corrupción de menores' AS modalidad_delito_sabana, 58 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Discriminación' AS delito_sabana, N'Discriminación' AS subtipo_delito_sabana, N'Discriminación' AS modalidad_delito_sabana, 59 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Otros delitos contra la sociedad' AS delito_sabana, N'Otros delitos contra la sociedad' AS subtipo_delito_sabana, N'Otros delitos contra la sociedad' AS modalidad_delito_sabana, 60 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Pornografía infantil' AS delito_sabana, N'Pornografía infantil' AS subtipo_delito_sabana, N'Pornografía infantil' AS modalidad_delito_sabana, 61 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de explotación sexual' AS subtipo_delito_sabana, N'Trata de personas con fines de explotación sexual' AS modalidad_delito_sabana, 62 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de trabajo o servicios forzados' AS subtipo_delito_sabana, N'Trata de personas con fines de trabajo o servicios forzados' AS modalidad_delito_sabana, 63 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con fines de tráfico de órganos' AS subtipo_delito_sabana, N'Trata de personas con fines de tráfico de órganos' AS modalidad_delito_sabana, 64 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La sociedad' AS bien_juridico, N'Trata de personas' AS delito_sabana, N'Trata de personas con otros fines' AS subtipo_delito_sabana, N'Trata de personas con otros fines' AS modalidad_delito_sabana, 65 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Aborto' AS delito_sabana, N'Aborto' AS subtipo_delito_sabana, N'Aborto' AS modalidad_delito_sabana, 66 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 67 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 68 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 69 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Feminicidio' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 70 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Feminicidio' AS delito_sabana, N'Tentativa de feminicidio' AS subtipo_delito_sabana, N'Tentativa de feminicidio' AS modalidad_delito_sabana, 71 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 72 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 73 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 74 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'En accidente de tránsito' AS modalidad_delito_sabana, 75 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio culposo' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 76 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 77 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 78 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 79 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Homicidio doloso' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 80 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Homicidio' AS delito_sabana, N'Tentativa de homicidio doloso' AS subtipo_delito_sabana, N'Tentativa de homicidio doloso' AS modalidad_delito_sabana, 81 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 82 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 83 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 84 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'En accidente de tránsito' AS modalidad_delito_sabana, 85 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones culposas' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 86 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con arma blanca' AS modalidad_delito_sabana, 87 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con arma de fuego' AS modalidad_delito_sabana, 88 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'Con otro elemento' AS modalidad_delito_sabana, 89 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Lesiones' AS delito_sabana, N'Lesiones dolosas' AS subtipo_delito_sabana, N'No especificado' AS modalidad_delito_sabana, 90 AS orden_municipal_victimas
        UNION ALL
        SELECT N'La vida y la Integridad corporal' AS bien_juridico, N'Otros delitos que atentan contra la vida y la integridad corporal' AS delito_sabana, N'Otros delitos que atentan contra la vida y la integridad corporal' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la vida y la integridad corporal' AS modalidad_delito_sabana, 91 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Otros delitos que atentan contra la libertad personal' AS delito_sabana, N'Otros delitos que atentan contra la libertad personal' AS subtipo_delito_sabana, N'Otros delitos que atentan contra la libertad personal' AS modalidad_delito_sabana, 92 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Privación ilegal de la libertad' AS delito_sabana, N'Privación ilegal de la libertad' AS subtipo_delito_sabana, N'Privación ilegal de la libertad' AS modalidad_delito_sabana, 93 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Rapto' AS delito_sabana, N'Rapto' AS subtipo_delito_sabana, N'Rapto' AS modalidad_delito_sabana, 94 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Retención o sustracción de menores e incapaces' AS delito_sabana, N'Retención o sustracción de menores e incapaces' AS subtipo_delito_sabana, N'Retención o sustracción de menores e incapaces' AS modalidad_delito_sabana, 95 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro con calidad de rehén' AS subtipo_delito_sabana, N'Secuestro con calidad de rehén' AS modalidad_delito_sabana, 96 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro exprés' AS subtipo_delito_sabana, N'Secuestro exprés' AS modalidad_delito_sabana, 97 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro extorsivo' AS subtipo_delito_sabana, N'Secuestro extorsivo' AS modalidad_delito_sabana, 98 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Secuestro' AS delito_sabana, N'Secuestro para causar daño' AS subtipo_delito_sabana, N'Secuestro para causar daño' AS modalidad_delito_sabana, 99 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Libertad personal' AS bien_juridico, N'Tráfico de menores' AS delito_sabana, N'Tráfico de menores' AS subtipo_delito_sabana, N'Tráfico de menores' AS modalidad_delito_sabana, 100 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Allanamiento de morada' AS delito_sabana, N'Allanamiento de morada' AS subtipo_delito_sabana, N'Allanamiento de morada' AS modalidad_delito_sabana, 101 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Amenazas' AS delito_sabana, N'Amenazas' AS subtipo_delito_sabana, N'Amenazas' AS modalidad_delito_sabana, 102 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Contra el medio ambiente' AS delito_sabana, N'Contra el medio ambiente' AS subtipo_delito_sabana, N'Contra el medio ambiente' AS modalidad_delito_sabana, 103 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Delitos cometidos por servidores públicos' AS delito_sabana, N'Delitos cometidos por servidores públicos' AS subtipo_delito_sabana, N'Delitos cometidos por servidores públicos' AS modalidad_delito_sabana, 104 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Delitos contra la administración de justicia' AS delito_sabana, N'Delitos contra la administración de justicia' AS subtipo_delito_sabana, N'Delitos contra la administración de justicia' AS modalidad_delito_sabana, 105 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Electorales' AS delito_sabana, N'Electorales' AS subtipo_delito_sabana, N'Electorales' AS modalidad_delito_sabana, 106 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Evasión de presos' AS delito_sabana, N'Evasión de presos' AS subtipo_delito_sabana, N'Evasión de presos' AS modalidad_delito_sabana, 107 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Falsedad' AS delito_sabana, N'Falsedad' AS subtipo_delito_sabana, N'Falsedad' AS modalidad_delito_sabana, 108 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Falsificación' AS delito_sabana, N'Falsificación' AS subtipo_delito_sabana, N'Falsificación' AS modalidad_delito_sabana, 109 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Narcomenudeo' AS delito_sabana, N'Narcomenudeo con fines de venta' AS subtipo_delito_sabana, N'Narcomenudeo con fines de venta' AS modalidad_delito_sabana, 110 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Narcomenudeo' AS delito_sabana, N'Narcomenudeo posesión simple' AS subtipo_delito_sabana, N'Narcomenudeo posesión simple' AS modalidad_delito_sabana, 111 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Otros delitos del Fuero Común' AS delito_sabana, N'Otros delitos del Fuero Común' AS subtipo_delito_sabana, N'Otros delitos del Fuero Común' AS modalidad_delito_sabana, 112 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Suplantación y usurpación de identidad' AS delito_sabana, N'Suplantación y usurpación de identidad' AS subtipo_delito_sabana, N'Suplantación y usurpación de identidad' AS modalidad_delito_sabana, 113 AS orden_municipal_victimas
        UNION ALL
        SELECT N'Otros bienes jurídicos afectados (del fuero común)' AS bien_juridico, N'Tortura' AS delito_sabana, N'Tortura' AS subtipo_delito_sabana, N'Tortura' AS modalidad_delito_sabana, 114 AS orden_municipal_victimas
    )
    UPDATE ol
    SET orden_municipal_victimas = o.orden_municipal_victimas
    FROM dbo.catalogo_sabana_orden_legacy ol
    INNER JOIN orden o
        ON o.bien_juridico = ol.bien_juridico
       AND o.delito_sabana = ol.delito_sabana
       AND o.subtipo_delito_sabana = ol.subtipo_delito_sabana
       AND o.modalidad_delito_sabana = ol.modalidad_delito_sabana
    WHERE ol.activo = 1
      AND ISNULL(ol.orden_municipal_victimas, -1) <> o.orden_municipal_victimas;

    PRINT CONCAT('Renglones actualizados: ', @@ROWCOUNT);

    IF @EjecutarAjuste = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Ajuste aplicado con COMMIT.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Prueba terminada con ROLLBACK. Cambia @EjecutarAjuste = 1 para aplicar.';
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@MensajeError, 16, 1);
END CATCH;
GO