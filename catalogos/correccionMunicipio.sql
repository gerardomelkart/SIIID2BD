SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @Viejo TABLE (
    id_entidad_federativa int NOT NULL,
    clave_municipio int NOT NULL,
    nombre_viejo nvarchar(255) NOT NULL
);

INSERT INTO @Viejo (id_entidad_federativa, clave_municipio, nombre_viejo)
VALUES
    (7, 72, N'Pueblo Nuevo Solistahuacá'),
    (7, 78, N'San Cristóbal de las Casa'),
    (7, 114, N'Benemérito de las América'),
    (8, 8, N'Batopilas de Manuel Gómez'),
    (8, 56, N'Rosario'),
    (11, 14, N'Dolores Hidalgo Cuna de l'),
    (11, 32, N'San José Iturbide'),
    (11, 35, N'Santa Cruz de Juventino R'),
    (12, 6, N'Apaxtla'),
    (12, 16, N'Coahuayutla de José María'),
    (12, 32, N'General Heliodoro Castill'),
    (12, 35, N'Iguala de la Independenci'),
    (12, 65, N'Tlalixtaquilla de Maldona'),
    (12, 68, N'La Unión de Isidoro Monte'),
    (13, 56, N'Santiago Tulantepec de Lu'),
    (14, 26, N'Concepción de Buenos Aire'),
    (14, 27, N'Cuautitlán de García Barr'),
    (14, 44, N'Ixtlahuacán de los Membri'),
    (14, 71, N'San Cristóbal de la Barra'),
    (14, 81, N'Santa María de los Ángele'),
    (14, 118, N'Yahualica de González Gal'),
    (15, 75, N'San Martín de las Pirámid'),
    (15, 122, N'Valle de Chalco Solidarid'),
    (16, 15, N'Coalcomán de Vázquez Pall'),
    (16, 92, N'Tiquicheo de Nicolás Rome'),
    (17, 13, N'Jonacatepec de Leandro Va'),
    (20, 24, N'Cuyamecalco Villa de Zara'),
    (20, 27, N'Chiquihuitlán de Benito J'),
    (20, 28, N'Heroica Ciudad de Ejutla '),
    (20, 29, N'Eloxochitlán de Flores Ma'),
    (20, 31, N'Tamazulápam del Espíritu '),
    (20, 39, N'Heroica Ciudad de Huajuap'),
    (20, 43, N'Heroica Ciudad de Juchitá'),
    (20, 59, N'Miahuatlán de Porfirio Dí'),
    (20, 74, N'Santa Catarina Quioquitan'),
    (20, 103, N'San Antonino Castillo Vel'),
    (20, 114, N'San Baltazar Yatzachi el '),
    (20, 124, N'Heroica Villa de San Blas'),
    (20, 129, N'San Cristóbal Suchixtlahu'),
    (20, 144, N'San Francisco Jaltepetong'),
    (20, 150, N'San Francisco Telixtlahua'),
    (20, 160, N'San Jerónimo Silacayoapil'),
    (20, 175, N'San Juan Bautista Atatlah'),
    (20, 176, N'San Juan Bautista Coixtla'),
    (20, 177, N'San Juan Bautista Cuicatl'),
    (20, 178, N'San Juan Bautista Guelach'),
    (20, 179, N'San Juan Bautista Jayacat'),
    (20, 180, N'San Juan Bautista Lo de S'),
    (20, 181, N'San Juan Bautista Suchite'),
    (20, 182, N'San Juan Bautista Tlacoat'),
    (20, 183, N'San Juan Bautista Tlachic'),
    (20, 184, N'San Juan Bautista Tuxtepe'),
    (20, 196, N'San Juan Evangelista Anal'),
    (20, 228, N'San Lorenzo Cuaunecuiltit'),
    (20, 238, N'Heroico San Martín de los'),
    (20, 304, N'San Pedro Coxcaltepec Cán'),
    (20, 316, N'San Pedro Mártir Quiechap'),
    (20, 337, N'San Pedro y San Pablo Ayu'),
    (20, 339, N'San Pedro y San Pablo Tep'),
    (20, 340, N'San Pedro y San Pablo Teq'),
    (20, 348, N'San Sebastián Tecomaxtlah'),
    (20, 381, N'Santa Cruz Tacache de Min'),
    (20, 397, N'Heroica Ciudad de Tlaxiac'),
    (20, 418, N'Santa María Jalapa del Ma'),
    (20, 437, N'Santa María Tlahuitoltepe'),
    (20, 459, N'Villa de Santiago Chazumb'),
    (20, 482, N'Santiago Pinotepa Naciona'),
    (20, 540, N'Villa de Tamazulápam del '),
    (20, 544, N'Teococuilco de Marcos Pér'),
    (20, 548, N'Tepelmeme Villa de Morelo'),
    (20, 549, N'Heroica Villa Tezoatlán d'),
    (20, 550, N'San Jerónimo Tlacochahuay'),
    (20, 554, N'Totontepec Villa de Morel'),
    (20, 559, N'San Juan Bautista Valle N'),
    (20, 562, N'Magdalena Yodocono de Por'),
    (21, 95, N'La Magdalena Tlatlauquite'),
    (21, 121, N'San Diego la Mesa Tochimi'),
    (21, 138, N'San Nicolás de los Rancho'),
    (21, 171, N'Tepeyahualco de Cuauhtémo'),
    (21, 177, N'Tlacotepec de Benito Juár'),
    (21, 202, N'Xochitlán de Vicente Suár'),
    (23, 8, N'Solidaridad'),
    (24, 35, N'Soledad de Graciano Sánch'),
    (26, 70, N'General Plutarco Elías Ca'),
    (29, 2, N'Apetatitlán de Antonio Ca'),
    (29, 15, N'Ixtacuixtla de Mariano Ma'),
    (29, 17, N'Mazatecochco de José Marí'),
    (29, 20, N'Sanctórum de Lázaro Cárde'),
    (29, 21, N'Nanacamilpa de Mariano Ar'),
    (29, 22, N'Acuamanala de Miguel Hida'),
    (29, 37, N'Ziltlaltépec de Trinidad '),
    (30, 9, N'Alto Lucero de Gutiérrez '),
    (30, 202, N'Zontecomatlán de López y '),
    (30, 206, N'Nanchital de Lázaro Cárde'),
    (32, 6, N'Cañitas de Felipe Pescado'),
    (32, 11, N'Trinidad García de la Cad'),
    (32, 14, N'General Francisco R. Murg'),
    (32, 15, N'El Plateado de Joaquín Am'),
    (32, 48, N'Tlaltenango de Sánchez Ro');

UPDATE m
SET m.nombre = v.nombre_viejo
FROM catalogo_municipio m
INNER JOIN @Viejo v
    ON v.id_entidad_federativa = m.id_entidad_federativa
   AND v.clave_municipio = TRY_CONVERT(int, m.clave)
WHERE ISNULL(m.nombre, N'') <> v.nombre_viejo;

-- Sobran contra el catálogo viejo: se desactivan.
UPDATE catalogo_municipio
SET activo = 0
WHERE id_entidad_federativa = 33
  AND TRY_CONVERT(int, clave) = 999
  AND nombre = N'No especificado';

UPDATE catalogo_municipio
SET activo = 0
WHERE id_entidad_federativa = 23
  AND TRY_CONVERT(int, clave) = 122
  AND nombre = N'Solidaridad';

COMMIT;


SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @MunicipiosExcel TABLE (
    id_entidad_federativa int NOT NULL,
    clave_municipio int NOT NULL,
    nombre_excel nvarchar(255) NOT NULL
);

INSERT INTO @MunicipiosExcel (id_entidad_federativa, clave_municipio, nombre_excel)
VALUES
    (7, 72, N'Pueblo Nuevo Solistahuacán'), -- 7072: Pueblo Nuevo Solistahuacá -> Pueblo Nuevo Solistahuacán
    (7, 78, N'San Cristóbal de las Casas'), -- 7078: San Cristóbal de las Casa -> San Cristóbal de las Casas
    (7, 114, N'Benemérito de las Américas'), -- 7114: Benemérito de las América -> Benemérito de las Américas
    (8, 8, N'Batopilas de Manuel Gómez Morín'), -- 8008: Batopilas de Manuel Gómez -> Batopilas de Manuel Gómez Morín
    (8, 56, N'Valle del Rosario'), -- 8056: Rosario -> Valle del Rosario
    (11, 14, N'Dolores Hidalgo Cuna de la Independencia Nacional'), -- 11014: Dolores Hidalgo Cuna de l -> Dolores Hidalgo Cuna de la Independencia Nacional
    (11, 32, N'San José de Iturbide'), -- 11032: San José Iturbide -> San José de Iturbide
    (11, 35, N'Santa Cruz de Juventino Rosas'), -- 11035: Santa Cruz de Juventino R -> Santa Cruz de Juventino Rosas
    (12, 6, N'Apaxtla de Castrejón'), -- 12006: Apaxtla -> Apaxtla de Castrejón
    (12, 16, N'Coahuayutla de José María Izazaga'), -- 12016: Coahuayutla de José María -> Coahuayutla de José María Izazaga
    (12, 32, N'General Heliodoro Castillo'), -- 12032: General Heliodoro Castill -> General Heliodoro Castillo
    (12, 35, N'Iguala de la Independencia'), -- 12035: Iguala de la Independenci -> Iguala de la Independencia
    (12, 65, N'Tlalixtaquilla de Maldonado'), -- 12065: Tlalixtaquilla de Maldona -> Tlalixtaquilla de Maldonado
    (12, 68, N'La Unión de Isidoro Montes de Oca'), -- 12068: La Unión de Isidoro Monte -> La Unión de Isidoro Montes de Oca
    (13, 56, N'Santiago Tulantepec de Lugo Guerrero'), -- 13056: Santiago Tulantepec de Lu -> Santiago Tulantepec de Lugo Guerrero
    (14, 26, N'Concepción de Buenos Aires'), -- 14026: Concepción de Buenos Aire -> Concepción de Buenos Aires
    (14, 27, N'Cuautitlán de García Barragán'), -- 14027: Cuautitlán de García Barr -> Cuautitlán de García Barragán
    (14, 44, N'Ixtlahuacán de los Membrillos'), -- 14044: Ixtlahuacán de los Membri -> Ixtlahuacán de los Membrillos
    (14, 71, N'San Cristóbal de la Barranca'), -- 14071: San Cristóbal de la Barra -> San Cristóbal de la Barranca
    (14, 81, N'Santa María de los Ángeles'), -- 14081: Santa María de los Ángele -> Santa María de los Ángeles
    (14, 118, N'Yahualica de González Gallo'), -- 14118: Yahualica de González Gal -> Yahualica de González Gallo
    (15, 75, N'San Martín de las Pirámides'), -- 15075: San Martín de las Pirámid -> San Martín de las Pirámides
    (15, 122, N'Valle de Chalco Solidaridad'), -- 15122: Valle de Chalco Solidarid -> Valle de Chalco Solidaridad
    (16, 15, N'Coalcomán de Vázquez Pallares'), -- 16015: Coalcomán de Vázquez Pall -> Coalcomán de Vázquez Pallares
    (16, 92, N'Tiquicheo de Nicolás Romero'), -- 16092: Tiquicheo de Nicolás Rome -> Tiquicheo de Nicolás Romero
    (17, 13, N'Jonacatepec de Leandro Valle'), -- 17013: Jonacatepec de Leandro Va -> Jonacatepec de Leandro Valle
    (20, 24, N'Cuyamecalco Villa de Zaragoza'), -- 20024: Cuyamecalco Villa de Zara -> Cuyamecalco Villa de Zaragoza
    (20, 27, N'Chiquihuitlán de Benito Juárez'), -- 20027: Chiquihuitlán de Benito J -> Chiquihuitlán de Benito Juárez
    (20, 28, N'Heroica Ciudad de Ejutla de Crespo'), -- 20028: Heroica Ciudad de Ejutla  -> Heroica Ciudad de Ejutla de Crespo
    (20, 29, N'Eloxochitlán de Flores Magón'), -- 20029: Eloxochitlán de Flores Ma -> Eloxochitlán de Flores Magón
    (20, 31, N'Tamazulápam del Espíritu Santo'), -- 20031: Tamazulápam del Espíritu  -> Tamazulápam del Espíritu Santo
    (20, 39, N'Heroica Ciudad de Huajuapan de León'), -- 20039: Heroica Ciudad de Huajuap -> Heroica Ciudad de Huajuapan de León
    (20, 43, N'Heroica Ciudad de Juchitán de Zaragoza'), -- 20043: Heroica Ciudad de Juchitá -> Heroica Ciudad de Juchitán de Zaragoza
    (20, 59, N'Heroica Ciudad de Miahuatlán de Porfirio Díaz'), -- 20059: Miahuatlán de Porfirio Dí -> Heroica Ciudad de Miahuatlán de Porfirio Díaz
    (20, 74, N'Santa Catarina Quioquitani'), -- 20074: Santa Catarina Quioquitan -> Santa Catarina Quioquitani
    (20, 103, N'San Antonino Castillo Velasco'), -- 20103: San Antonino Castillo Vel -> San Antonino Castillo Velasco
    (20, 114, N'San Baltazar Yatzachi el Bajo'), -- 20114: San Baltazar Yatzachi el  -> San Baltazar Yatzachi el Bajo
    (20, 124, N'Heroica Villa de San Blas Atempa'), -- 20124: Heroica Villa de San Blas -> Heroica Villa de San Blas Atempa
    (20, 129, N'San Cristóbal Suchixtlahuaca'), -- 20129: San Cristóbal Suchixtlahu -> San Cristóbal Suchixtlahuaca
    (20, 144, N'San Francisco Jaltepetongo'), -- 20144: San Francisco Jaltepetong -> San Francisco Jaltepetongo
    (20, 150, N'San Francisco Telixtlahuaca'), -- 20150: San Francisco Telixtlahua -> San Francisco Telixtlahuaca
    (20, 160, N'San Jerónimo Silacayoapilla'), -- 20160: San Jerónimo Silacayoapil -> San Jerónimo Silacayoapilla
    (20, 175, N'San Juan Bautista Atatlahuca'), -- 20175: San Juan Bautista Atatlah -> San Juan Bautista Atatlahuca
    (20, 176, N'San Juan Bautista Coixtlahuaca'), -- 20176: San Juan Bautista Coixtla -> San Juan Bautista Coixtlahuaca
    (20, 177, N'San Juan Bautista Cuicatlán'), -- 20177: San Juan Bautista Cuicatl -> San Juan Bautista Cuicatlán
    (20, 178, N'San Juan Bautista Guelache'), -- 20178: San Juan Bautista Guelach -> San Juan Bautista Guelache
    (20, 179, N'San Juan Bautista Jayacatlán'), -- 20179: San Juan Bautista Jayacat -> San Juan Bautista Jayacatlán
    (20, 180, N'San Juan Bautista Lo de Soto'), -- 20180: San Juan Bautista Lo de S -> San Juan Bautista Lo de Soto
    (20, 181, N'San Juan Bautista Suchitepec'), -- 20181: San Juan Bautista Suchite -> San Juan Bautista Suchitepec
    (20, 182, N'San Juan Bautista Tlacoatzintepec'), -- 20182: San Juan Bautista Tlacoat -> San Juan Bautista Tlacoatzintepec
    (20, 183, N'San Juan Bautista Tlachichilco'), -- 20183: San Juan Bautista Tlachic -> San Juan Bautista Tlachichilco
    (20, 184, N'San Juan Bautista Tuxtepec'), -- 20184: San Juan Bautista Tuxtepe -> San Juan Bautista Tuxtepec
    (20, 196, N'San Juan Evangelista Analco'), -- 20196: San Juan Evangelista Anal -> San Juan Evangelista Analco
    (20, 228, N'San Lorenzo Cuaunecuiltitla'), -- 20228: San Lorenzo Cuaunecuiltit -> San Lorenzo Cuaunecuiltitla
    (20, 238, N'Heroico San Martín de los Cansecos'), -- 20238: Heroico San Martín de los -> Heroico San Martín de los Cansecos
    (20, 304, N'San Pedro Coxcaltepec Cántaros'), -- 20304: San Pedro Coxcaltepec Cán -> San Pedro Coxcaltepec Cántaros
    (20, 316, N'San Pedro Mártir Quiechapa'), -- 20316: San Pedro Mártir Quiechap -> San Pedro Mártir Quiechapa
    (20, 337, N'San Pedro y San Pablo Ayutla'), -- 20337: San Pedro y San Pablo Ayu -> San Pedro y San Pablo Ayutla
    (20, 339, N'San Pedro y San Pablo Teposcolula'), -- 20339: San Pedro y San Pablo Tep -> San Pedro y San Pablo Teposcolula
    (20, 340, N'San Pedro y San Pablo Tequixtepec'), -- 20340: San Pedro y San Pablo Teq -> San Pedro y San Pablo Tequixtepec
    (20, 348, N'San Sebastián Tecomaxtlahuaca'), -- 20348: San Sebastián Tecomaxtlah -> San Sebastián Tecomaxtlahuaca
    (20, 381, N'Santa Cruz Tacache de Mina'), -- 20381: Santa Cruz Tacache de Min -> Santa Cruz Tacache de Mina
    (20, 397, N'Heroica Ciudad de Tlaxiaco'), -- 20397: Heroica Ciudad de Tlaxiac -> Heroica Ciudad de Tlaxiaco
    (20, 418, N'Santa María Jalapa del Marqués'), -- 20418: Santa María Jalapa del Ma -> Santa María Jalapa del Marqués
    (20, 437, N'Santa María Tlahuitoltepec'), -- 20437: Santa María Tlahuitoltepe -> Santa María Tlahuitoltepec
    (20, 459, N'Villa de Santiago Chazumba'), -- 20459: Villa de Santiago Chazumb -> Villa de Santiago Chazumba
    (20, 482, N'Santiago Pinotepa Nacional'), -- 20482: Santiago Pinotepa Naciona -> Santiago Pinotepa Nacional
    (20, 540, N'Villa de Tamazulápam del Progreso'), -- 20540: Villa de Tamazulápam del  -> Villa de Tamazulápam del Progreso
    (20, 544, N'Teococuilco de Marcos Pérez'), -- 20544: Teococuilco de Marcos Pér -> Teococuilco de Marcos Pérez
    (20, 548, N'Tepelmeme Villa de Morelos'), -- 20548: Tepelmeme Villa de Morelo -> Tepelmeme Villa de Morelos
    (20, 549, N'Heroica Villa Tezoatlán de Segura y Luna, Cuna de la Independencia de Oaxaca'), -- 20549: Heroica Villa Tezoatlán d -> Heroica Villa Tezoatlán de Segura y Luna, Cuna de la Independencia de Oaxaca
    (20, 550, N'San Jerónimo Tlacochahuaya'), -- 20550: San Jerónimo Tlacochahuay -> San Jerónimo Tlacochahuaya
    (20, 554, N'Totontepec Villa de Morelos'), -- 20554: Totontepec Villa de Morel -> Totontepec Villa de Morelos
    (20, 559, N'San Juan Bautista Valle Nacional'), -- 20559: San Juan Bautista Valle N -> San Juan Bautista Valle Nacional
    (20, 562, N'Magdalena Yodocono de Porfirio Díaz'), -- 20562: Magdalena Yodocono de Por -> Magdalena Yodocono de Porfirio Díaz
    (21, 95, N'La Magdalena Tlatlauquitepec'), -- 21095: La Magdalena Tlatlauquite -> La Magdalena Tlatlauquitepec
    (21, 121, N'San Diego la Mesa Tochimiltzingo'), -- 21121: San Diego la Mesa Tochimi -> San Diego la Mesa Tochimiltzingo
    (21, 138, N'San Nicolás de los Ranchos'), -- 21138: San Nicolás de los Rancho -> San Nicolás de los Ranchos
    (21, 171, N'Tepeyahualco de Cuauhtémoc'), -- 21171: Tepeyahualco de Cuauhtémo -> Tepeyahualco de Cuauhtémoc
    (21, 177, N'Tlacotepec de Benito Juárez'), -- 21177: Tlacotepec de Benito Juár -> Tlacotepec de Benito Juárez
    (21, 202, N'Xochitlán de Vicente Suárez'), -- 21202: Xochitlán de Vicente Suár -> Xochitlán de Vicente Suárez
    (23, 8, N'Playa del Carmen'), -- 23008: Solidaridad -> Playa del Carmen
    (24, 35, N'Soledad de Graciano Sánchez'), -- 24035: Soledad de Graciano Sánch -> Soledad de Graciano Sánchez
    (26, 70, N'General Plutarco Elías Calles'), -- 26070: General Plutarco Elías Ca -> General Plutarco Elías Calles
    (29, 2, N'Apetatitlán de Antonio Carvajal'), -- 29002: Apetatitlán de Antonio Ca -> Apetatitlán de Antonio Carvajal
    (29, 15, N'Ixtacuixtla de Mariano Matamoros'), -- 29015: Ixtacuixtla de Mariano Ma -> Ixtacuixtla de Mariano Matamoros
    (29, 17, N'Mazatecochco de José María Morelos'), -- 29017: Mazatecochco de José Marí -> Mazatecochco de José María Morelos
    (29, 20, N'Sanctórum de Lázaro Cárdenas'), -- 29020: Sanctórum de Lázaro Cárde -> Sanctórum de Lázaro Cárdenas
    (29, 21, N'Nanacamilpa de Mariano Arista'), -- 29021: Nanacamilpa de Mariano Ar -> Nanacamilpa de Mariano Arista
    (29, 22, N'Acuamanala de Miguel Hidalgo'), -- 29022: Acuamanala de Miguel Hida -> Acuamanala de Miguel Hidalgo
    (29, 37, N'Ziltlaltépec de Trinidad Sánchez Santos'), -- 29037: Ziltlaltépec de Trinidad  -> Ziltlaltépec de Trinidad Sánchez Santos
    (30, 9, N'Alto Lucero de Gutiérrez Barrios'), -- 30009: Alto Lucero de Gutiérrez  -> Alto Lucero de Gutiérrez Barrios
    (30, 202, N'Zontecomatlán de López y Fuentes'), -- 30202: Zontecomatlán de López y  -> Zontecomatlán de López y Fuentes
    (30, 206, N'Nanchital de Lázaro Cárdenas del Río'), -- 30206: Nanchital de Lázaro Cárde -> Nanchital de Lázaro Cárdenas del Río
    (32, 6, N'Cañitas de Felipe Pescador'), -- 32006: Cañitas de Felipe Pescado -> Cañitas de Felipe Pescador
    (32, 11, N'Trinidad García de la Cadena'), -- 32011: Trinidad García de la Cad -> Trinidad García de la Cadena
    (32, 14, N'General Francisco R. Murguía'), -- 32014: General Francisco R. Murg -> General Francisco R. Murguía
    (32, 15, N'El Plateado de Joaquín Amaro'), -- 32015: El Plateado de Joaquín Am -> El Plateado de Joaquín Amaro
    (32, 48, N'Tlaltenango de Sánchez Román'); -- 32048: Tlaltenango de Sánchez Ro -> Tlaltenango de Sánchez Román

-- Actualiza nombres del catálogo nuevo para que coincidan con el Excel original de municipal-delitos.
UPDATE m
SET m.nombre = e.nombre_excel
FROM catalogo_municipio m
INNER JOIN @MunicipiosExcel e
    ON e.id_entidad_federativa = m.id_entidad_federativa
   AND e.clave_municipio = TRY_CONVERT(int, m.clave)
WHERE m.activo = 1
  AND ISNULL(m.nombre, N'') <> e.nombre_excel;

-- Validación: no debe regresar filas.
SELECT
    e.id_entidad_federativa,
    e.clave_municipio,
    m.nombre AS nombre_actual,
    e.nombre_excel AS nombre_esperado
FROM @MunicipiosExcel e
LEFT JOIN catalogo_municipio m
    ON m.id_entidad_federativa = e.id_entidad_federativa
   AND TRY_CONVERT(int, m.clave) = e.clave_municipio
   AND m.activo = 1
WHERE m.id_municipio IS NULL
   OR ISNULL(m.nombre, N'') <> e.nombre_excel
ORDER BY e.id_entidad_federativa, e.clave_municipio;

COMMIT;