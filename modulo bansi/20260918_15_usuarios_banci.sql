USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Aplicar tras 14 en desarrollo. No activa BANCI, no copia permisos mensuales a enlaces o consulta.
IF @@TRANCOUNT <> 0 THROW 52431, 'Use una ventana sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sp_banci_vista_previa', N'P') IS NULL OR OBJECT_ID(N'dbo.banci_carga', N'U') IS NULL
    THROW 52432, 'Aplique primero los scripts BANCI hasta el 14.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.catalogo_modulo WHERE clave = N'BANCI') THROW 52432, 'No existe BANCI en el catálogo.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_vista_previa
    @CodigoReferencia NVARCHAR(50), @IdUsuario INT, @Huella VARCHAR(64) = NULL OUTPUT, @EmitirResultado BIT = 1, @PuedeAceptar BIT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @Propia BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @IdBanciCarga BIGINT, @IdEntidad TINYINT, @Bloqueo INT, @Recurso NVARCHAR(255), @Modalidad NVARCHAR(40);
    BEGIN TRY
        IF @Propia = 1 BEGIN TRANSACTION;
        SELECT @IdEntidad = id_entidad_federativa FROM dbo.banci_carga WHERE codigo_referencia = @CodigoReferencia AND id_usuario_carga = @IdUsuario AND activo = 1;
        IF @IdEntidad IS NULL THROW 52404, ''La carga no está disponible para este usuario.'', 1;
        SET @Recurso = CONCAT(N''BANCI:ENTIDAD:'', @IdEntidad);
        -- La confirmación ya tiene el bloqueo exclusivo; no intentar rebajarlo.
        IF ISNULL(APPLOCK_MODE(N''public'', @Recurso, N''Transaction''), N''NoLock'') <> N''Exclusive''
        BEGIN
            EXEC @Bloqueo = sys.sp_getapplock @Resource = @Recurso, @LockMode = N''Shared'', @LockOwner = N''Transaction'', @LockTimeout = 10000;
            IF @Bloqueo < 0 THROW 52403, ''Hay una integración en curso. Reintente la consulta.'', 1;
        END;
        SELECT @IdBanciCarga = id_banci_carga, @Modalidad = modalidad_ingesta FROM dbo.banci_carga WITH (HOLDLOCK)
        WHERE codigo_referencia = @CodigoReferencia AND id_usuario_carga = @IdUsuario AND activo = 1 AND estado = N''VALIDADO_PENDIENTE'';
        IF @IdBanciCarga IS NULL THROW 52409, ''La carga ya no está pendiente. Actualice su estado.'', 1;
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.usuario u WITH (HOLDLOCK)
            INNER JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
            INNER JOIN dbo.catalogo_modulo banci WITH (HOLDLOCK) ON banci.clave = N''BANCI'' AND banci.activo = 1
            LEFT JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = banci.id_modulo AND um.habilitado = 1 AND um.activo = 1
            WHERE u.id_usuario = @IdUsuario AND u.activo = 1
              AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad AND um.id_usuario IS NOT NULL))
        )
            THROW 52405, ''El usuario ya no tiene acceso BANCI vigente para la entidad de esta carga.'', 1;
    IF @Modalidad = N''FORMULARIO'' AND
    (
        (SELECT COUNT(*) FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1) <> 1
        OR EXISTS
        (
            SELECT 1 FROM dbo.banci_carga_tmp_carpeta s
            INNER JOIN dbo.banci_carpeta_investigacion c WITH (HOLDLOCK)
                ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = LTRIM(RTRIM(s.id_ci))
            WHERE s.id_banci_carga = @IdBanciCarga AND s.activo = 1
        )
    ) THROW 52424, ''La carpeta ya existe o el formulario no contiene exactamente una carpeta nueva.'', 1;
        CREATE TABLE #Cambios (Tipo NVARCHAR(10) COLLATE DATABASE_DEFAULT, IdCi NVARCHAR(250) COLLATE DATABASE_DEFAULT, IdDelito NVARCHAR(250) COLLATE DATABASE_DEFAULT, IdVictima NVARCHAR(250) COLLATE DATABASE_DEFAULT, Campo NVARCHAR(100) COLLATE DATABASE_DEFAULT, Anterior NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, Nuevo NVARCHAR(MAX) COLLATE DATABASE_DEFAULT);
        CREATE INDEX IX_Cambios_Registro ON #Cambios (Tipo, IdCi, IdDelito, IdVictima);
        CREATE TABLE #Registros (Tipo NVARCHAR(10) COLLATE DATABASE_DEFAULT, IdCi NVARCHAR(250) COLLATE DATABASE_DEFAULT, IdDelito NVARCHAR(250) COLLATE DATABASE_DEFAULT, IdVictima NVARCHAR(250) COLLATE DATABASE_DEFAULT, Accion NVARCHAR(20) COLLATE DATABASE_DEFAULT);

    SELECT
        id_entidad_federativa = @IdEntidad,
        entidad = NULLIF(LTRIM(RTRIM(entidad)), N''''),
        id_ci = NULLIF(LTRIM(RTRIM(id_ci)), N''''),
        ntra_ci = NULLIF(LTRIM(RTRIM(ntra_ci)), N''''),
        fha_de_ini = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''''))),
        hra_de_ini = TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(hra_de_ini)), N'''')),
        rmen_de_hchos = NULLIF(LTRIM(RTRIM(rmen_de_hchos)), N''''),
        ord_apreh = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(ord_apreh)), N'''')),
        fgran = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(fgran)), N'''')),
        ctaon = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(ctaon)), N'''')),
        td_v_ap = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(td_v_ap)), N'''')),
        proc_abrev = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(proc_abrev)), N'''')),
        juc_oral = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(juc_oral)), N'''')),
        td_sen_con = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(td_sen_con)), N'''')),
        no_ejer_acc_pnal = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(no_ejer_acc_pnal)), N'''')),
        otra = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(otra)), N'''')),
        dic = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(dic)), N''''))
    INTO #Carpetas
    FROM dbo.banci_carga_tmp_carpeta
    WHERE id_banci_carga = @IdBanciCarga
      AND activo = 1;
    INSERT INTO #Cambios (Tipo, IdCi, IdDelito, IdVictima, Campo, Anterior, Nuevo)
    SELECT N''CARPETA'', s.id_ci, NULL, NULL, v.campo, v.valor_anterior, v.valor_nuevo
    FROM #Carpetas s LEFT JOIN dbo.banci_carpeta_investigacion t ON t.id_entidad_federativa = @IdEntidad AND t.id_ci = s.id_ci
    CROSS APPLY (VALUES (N''ntra_ci'', CONVERT(NVARCHAR(MAX), t.ntra_ci), CONVERT(NVARCHAR(MAX), COALESCE(s.ntra_ci, t.ntra_ci))),
        (N''fha_de_ini'', CONVERT(NVARCHAR(MAX), t.fha_de_ini, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fha_de_ini, t.fha_de_ini), 23)),
        (N''hra_de_ini'', CONVERT(NVARCHAR(MAX), t.hra_de_ini), CONVERT(NVARCHAR(MAX), COALESCE(s.hra_de_ini, t.hra_de_ini))),
        (N''rmen_de_hchos'', t.rmen_de_hchos, COALESCE(s.rmen_de_hchos, t.rmen_de_hchos)),
        (N''ord_apreh'', CONVERT(NVARCHAR(MAX), t.ord_apreh), CONVERT(NVARCHAR(MAX), COALESCE(s.ord_apreh, t.ord_apreh))),
        (N''fgran'', CONVERT(NVARCHAR(MAX), t.fgran), CONVERT(NVARCHAR(MAX), COALESCE(s.fgran, t.fgran))),
        (N''ctaon'', CONVERT(NVARCHAR(MAX), t.ctaon), CONVERT(NVARCHAR(MAX), COALESCE(s.ctaon, t.ctaon))),
        (N''td_v_ap'', CONVERT(NVARCHAR(MAX), t.td_v_ap), CONVERT(NVARCHAR(MAX), COALESCE(s.td_v_ap, t.td_v_ap))),
        (N''proc_abrev'', CONVERT(NVARCHAR(MAX), t.proc_abrev), CONVERT(NVARCHAR(MAX), COALESCE(s.proc_abrev, t.proc_abrev))),
        (N''juc_oral'', CONVERT(NVARCHAR(MAX), t.juc_oral), CONVERT(NVARCHAR(MAX), COALESCE(s.juc_oral, t.juc_oral))),
        (N''td_sen_con'', CONVERT(NVARCHAR(MAX), t.td_sen_con), CONVERT(NVARCHAR(MAX), COALESCE(s.td_sen_con, t.td_sen_con))),
        (N''no_ejer_acc_pnal'', CONVERT(NVARCHAR(MAX), t.no_ejer_acc_pnal), CONVERT(NVARCHAR(MAX), COALESCE(s.no_ejer_acc_pnal, t.no_ejer_acc_pnal))),
        (N''otra'', CONVERT(NVARCHAR(MAX), t.otra), CONVERT(NVARCHAR(MAX), COALESCE(s.otra, t.otra))),
        (N''dic'', CONVERT(NVARCHAR(MAX), t.dic), CONVERT(NVARCHAR(MAX), COALESCE(s.dic, t.dic)))) v(campo, valor_anterior, valor_nuevo)
    WHERE t.activo = 1 AND ISNULL(v.valor_anterior, N''§NULL§'') <> ISNULL(v.valor_nuevo, N''§NULL§'');

    INSERT INTO #Registros (Tipo, IdCi, IdDelito, IdVictima, Accion)
    SELECT N''CARPETA'', s.id_ci, NULL, NULL, CASE WHEN t.id_banci_carpeta_investigacion IS NULL THEN N''ALTA''
        WHEN EXISTS (SELECT 1 FROM #Cambios x WHERE x.Tipo = N''CARPETA'' AND x.IdCi = s.id_ci) THEN N''ACTUALIZACION'' ELSE N''SIN_CAMBIO'' END
    FROM #Carpetas s LEFT JOIN dbo.banci_carpeta_investigacion t ON t.id_entidad_federativa = @IdEntidad AND t.id_ci = s.id_ci;

    SELECT
        id_ci = NULLIF(LTRIM(RTRIM(d.id_ci)), N''''),
        id_delito = NULLIF(LTRIM(RTRIM(d.id_delito)), N''''),
        dto = NULLIF(LTRIM(RTRIM(d.dto)), N''''),
        moda_dto = NULLIF(LTRIM(RTRIM(d.moda_dto)), N''''),
        forma_acc = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.forma_acc)), N'''')),
        fha_de_hchos = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(d.fha_de_hchos)), N''''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(d.fha_de_hchos)), N''''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(d.fha_de_hchos)), N''''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(d.fha_de_hchos)), N''''))),
        hra_de_hchos = TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(d.hra_de_hchos)), N'''')),
        emto_com_dto = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.emto_com_dto)), N'''')),
        grdo_cons = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.grdo_cons)), N'''')),
        clasf_de_dto = NULLIF(LTRIM(RTRIM(d.clasf_de_dto)), N''''),
        nom_ent_hchos = NULLIF(LTRIM(RTRIM(d.nom_ent_hchos)), N''''),
        id_ent_hchos = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.id_ent_hchos)), N'''')),
        nom_mun_hchos = NULLIF(LTRIM(RTRIM(d.nom_mun_hchos)), N''''),
        id_mun_hchos = m.clave,
        nom_loc_hchos = NULLIF(LTRIM(RTRIM(d.nom_loc_hchos)), N''''),
        id_loc_hchos = NULLIF(LTRIM(RTRIM(d.id_loc_hchos)), N''''),
        nom_col_hchos = NULLIF(LTRIM(RTRIM(d.nom_col_hchos)), N''''),
        id_col_hchos = NULLIF(LTRIM(RTRIM(d.id_col_hchos)), N''''),
        cp = NULLIF(LTRIM(RTRIM(d.cp)), N''''),
        coord_x = TRY_CONVERT(DECIMAL(10,6), REPLACE(NULLIF(LTRIM(RTRIM(d.coord_x)), N''''), N'','', N''.'')),
        coord_y = TRY_CONVERT(DECIMAL(10,6), REPLACE(NULLIF(LTRIM(RTRIM(d.coord_y)), N''''), N'','', N''.'')),
        dom_hchos = NULLIF(LTRIM(RTRIM(d.dom_hchos)), N'''')
    INTO #Delitos
    FROM dbo.banci_carga_tmp_delito d
    OUTER APPLY
    (
        SELECT TOP (1) cm.clave
        FROM dbo.catalogo_municipio cm
        WHERE cm.id_entidad_federativa = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.id_ent_hchos)), N''''))
          AND cm.activo = 1
          AND
          (
                cm.clave = NULLIF(LTRIM(RTRIM(d.id_mun_hchos)), N'''')
             OR TRY_CONVERT(INT, cm.clave) = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(d.id_mun_hchos)), N''''))
          )
    ) m
    WHERE d.id_banci_carga = @IdBanciCarga
      AND d.activo = 1;
    INSERT INTO #Cambios (Tipo, IdCi, IdDelito, IdVictima, Campo, Anterior, Nuevo)
    SELECT N''DELITO'', s.id_ci, s.id_delito, NULL, v.campo, v.valor_anterior, v.valor_nuevo
    FROM #Delitos s LEFT JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = s.id_ci LEFT JOIN dbo.banci_delito t ON t.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion AND t.id_delito = s.id_delito
    CROSS APPLY (VALUES (N''dto'', CONVERT(NVARCHAR(MAX), t.dto), CONVERT(NVARCHAR(MAX), COALESCE(s.dto, t.dto))),
        (N''moda_dto'', t.moda_dto, COALESCE(s.moda_dto, t.moda_dto)),
        (N''forma_acc'', CONVERT(NVARCHAR(MAX), t.forma_acc), CONVERT(NVARCHAR(MAX), COALESCE(s.forma_acc, t.forma_acc))),
        (N''fha_de_hchos'', CONVERT(NVARCHAR(MAX), t.fha_de_hchos, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fha_de_hchos, t.fha_de_hchos), 23)),
        (N''hra_de_hchos'', CONVERT(NVARCHAR(MAX), t.hra_de_hchos), CONVERT(NVARCHAR(MAX), COALESCE(s.hra_de_hchos, t.hra_de_hchos))),
        (N''emto_com_dto'', CONVERT(NVARCHAR(MAX), t.emto_com_dto), CONVERT(NVARCHAR(MAX), COALESCE(s.emto_com_dto, t.emto_com_dto))),
        (N''grdo_cons'', CONVERT(NVARCHAR(MAX), t.grdo_cons), CONVERT(NVARCHAR(MAX), COALESCE(s.grdo_cons, t.grdo_cons))),
        (N''clasf_de_dto'', t.clasf_de_dto, COALESCE(s.clasf_de_dto, t.clasf_de_dto)),
        (N''nom_ent_hchos'', t.nom_ent_hchos, COALESCE(s.nom_ent_hchos, t.nom_ent_hchos)),
        (N''id_ent_hchos'', CONVERT(NVARCHAR(MAX), t.id_ent_hchos), CONVERT(NVARCHAR(MAX), COALESCE(s.id_ent_hchos, t.id_ent_hchos))),
        (N''nom_mun_hchos'', t.nom_mun_hchos, COALESCE(s.nom_mun_hchos, t.nom_mun_hchos)),
        (N''id_mun_hchos'', t.id_mun_hchos, COALESCE(s.id_mun_hchos, t.id_mun_hchos)),
        (N''nom_loc_hchos'', t.nom_loc_hchos, COALESCE(s.nom_loc_hchos, t.nom_loc_hchos)),
        (N''id_loc_hchos'', t.id_loc_hchos, COALESCE(s.id_loc_hchos, t.id_loc_hchos)),
        (N''nom_col_hchos'', t.nom_col_hchos, COALESCE(s.nom_col_hchos, t.nom_col_hchos)),
        (N''id_col_hchos'', t.id_col_hchos, COALESCE(s.id_col_hchos, t.id_col_hchos)),
        (N''cp'', t.cp, COALESCE(s.cp, t.cp)),
        (N''coord_x'', CONVERT(NVARCHAR(MAX), t.coord_x), CONVERT(NVARCHAR(MAX), COALESCE(s.coord_x, t.coord_x))),
        (N''coord_y'', CONVERT(NVARCHAR(MAX), t.coord_y), CONVERT(NVARCHAR(MAX), COALESCE(s.coord_y, t.coord_y))),
        (N''dom_hchos'', t.dom_hchos, COALESCE(s.dom_hchos, t.dom_hchos))) v(campo, valor_anterior, valor_nuevo)
    WHERE t.activo = 1 AND ISNULL(v.valor_anterior, N''§NULL§'') <> ISNULL(v.valor_nuevo, N''§NULL§'');

    INSERT INTO #Registros (Tipo, IdCi, IdDelito, IdVictima, Accion)
    SELECT N''DELITO'', s.id_ci, s.id_delito, NULL, CASE WHEN t.id_banci_delito IS NULL THEN N''ALTA''
        WHEN EXISTS (SELECT 1 FROM #Cambios x WHERE x.Tipo = N''DELITO'' AND x.IdCi = s.id_ci AND x.IdDelito = s.id_delito) THEN N''ACTUALIZACION'' ELSE N''SIN_CAMBIO'' END
    FROM #Delitos s LEFT JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = s.id_ci LEFT JOIN dbo.banci_delito t ON t.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion AND t.id_delito = s.id_delito;

    SELECT
        id_ci = NULLIF(LTRIM(RTRIM(v.id_ci)), N''''),
        id_delito = NULLIF(LTRIM(RTRIM(v.id_delito)), N''''),
        id_vicf = NULLIF(LTRIM(RTRIM(v.id_vicf)), N''''),
        id_tv = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.id_tv)), N'''')),
        id_tpm = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.id_tpm)), N'''')),
        sexo = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.sexo)), N'''')),
        genero = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.genero)), N'''')),
        pob = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.pob)), N'''')),
        disc = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.disc)), N'''')),
        fha_nac = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fha_nac)), N''''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fha_nac)), N''''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fha_nac)), N''''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fha_nac)), N''''))),
        edad = TRY_CONVERT(SMALLINT, NULLIF(LTRIM(RTRIM(v.edad)), N'''')),
        nacional = n.clave,
        folio_fotovolante = NULLIF(LTRIM(RTRIM(v.folio_fotovolante)), N''''),
        folio_rnpdno = NULLIF(LTRIM(RTRIM(v.folio_rnpdno)), N''''),
        pro_apellido = NULLIF(LTRIM(RTRIM(v.pro_apellido)), N''''),
        sdo_apellido = NULLIF(LTRIM(RTRIM(v.sdo_apellido)), N''''),
        nomb = NULLIF(LTRIM(RTRIM(v.nomb)), N''''),
        entidad_nacimiento = NULLIF(LTRIM(RTRIM(v.entidad_nacimiento)), N''''),
        estado_migratorio = NULLIF(LTRIM(RTRIM(v.estado_migratorio)), N''''),
        curp = NULLIF(LTRIM(RTRIM(v.curp)), N''''),
        rfc = NULLIF(LTRIM(RTRIM(v.rfc)), N''''),
        fecha_ultimo_contacto = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_ultimo_contacto)), N''''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_ultimo_contacto)), N''''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_ultimo_contacto)), N''''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_ultimo_contacto)), N''''))),
        hora_ultimo_contacto = TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(v.hora_ultimo_contacto)), N'''')),
        entidad_visto = NULLIF(LTRIM(RTRIM(v.entidad_visto)), N''''),
        municipio_visto = NULLIF(LTRIM(RTRIM(v.municipio_visto)), N''''),
        lugar_ultimo_contacto = NULLIF(LTRIM(RTRIM(v.lugar_ultimo_contacto)), N''''),
        senas_tatuaje_datos_identificacion = NULLIF(LTRIM(RTRIM(v.senas_tatuaje_datos_identificacion)), N''''),
        localizado_o_no_localizado = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.localizado_o_no_localizado)), N'''')),
        con_o_sin_vida = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.con_o_sin_vida)), N'''')),
        fecha_localizacion = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_localizacion)), N''''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_localizacion)), N''''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_localizacion)), N''''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_localizacion)), N''''))),
        voluntaria = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.voluntaria)), N'''')),
        fue_delito = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.fue_delito)), N'''')),
        delito = NULLIF(LTRIM(RTRIM(v.delito)), N''''),
        obs = NULLIF(LTRIM(RTRIM(v.obs)), N'''')
    INTO #Victimas
    FROM dbo.banci_carga_tmp_victima v
    OUTER APPLY
    (
        SELECT TOP (1) cn.clave
        FROM dbo.catalogo_nacionalidad cn
        WHERE cn.activo = 1
          AND
          (
                cn.clave = NULLIF(LTRIM(RTRIM(v.nacional)), N'''')
             OR TRY_CONVERT(INT, cn.clave) = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(v.nacional)), N''''))
          )
    ) n
    WHERE v.id_banci_carga = @IdBanciCarga
      AND v.activo = 1;
    INSERT INTO #Cambios (Tipo, IdCi, IdDelito, IdVictima, Campo, Anterior, Nuevo)
    SELECT N''VICTIMA'', s.id_ci, s.id_delito, s.id_vicf, v.campo, v.valor_anterior, v.valor_nuevo
    FROM #Victimas s LEFT JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = s.id_ci LEFT JOIN dbo.banci_delito d ON d.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion AND d.id_delito = s.id_delito LEFT JOIN dbo.banci_victima t ON t.id_banci_delito = d.id_banci_delito AND t.id_vicf = s.id_vicf
    CROSS APPLY (VALUES (N''id_tv'', CONVERT(NVARCHAR(MAX), t.id_tv), CONVERT(NVARCHAR(MAX), COALESCE(s.id_tv, t.id_tv))),
        (N''id_tpm'', CONVERT(NVARCHAR(MAX), t.id_tpm), CONVERT(NVARCHAR(MAX), COALESCE(s.id_tpm, t.id_tpm))),
        (N''sexo'', CONVERT(NVARCHAR(MAX), t.sexo), CONVERT(NVARCHAR(MAX), COALESCE(s.sexo, t.sexo))),
        (N''genero'', CONVERT(NVARCHAR(MAX), t.genero), CONVERT(NVARCHAR(MAX), COALESCE(s.genero, t.genero))),
        (N''pob'', CONVERT(NVARCHAR(MAX), t.pob), CONVERT(NVARCHAR(MAX), COALESCE(s.pob, t.pob))),
        (N''disc'', CONVERT(NVARCHAR(MAX), t.disc), CONVERT(NVARCHAR(MAX), COALESCE(s.disc, t.disc))),
        (N''fha_nac'', CONVERT(NVARCHAR(MAX), t.fha_nac, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fha_nac, t.fha_nac), 23)),
        (N''edad'', CONVERT(NVARCHAR(MAX), t.edad), CONVERT(NVARCHAR(MAX), COALESCE(s.edad, t.edad))),
        (N''nacional'', t.nacional, COALESCE(s.nacional, t.nacional)),
        (N''folio_fotovolante'', t.folio_fotovolante, COALESCE(s.folio_fotovolante, t.folio_fotovolante)),
        (N''folio_rnpdno'', t.folio_rnpdno, COALESCE(s.folio_rnpdno, t.folio_rnpdno)),
        (N''pro_apellido'', t.pro_apellido, COALESCE(s.pro_apellido, t.pro_apellido)),
        (N''sdo_apellido'', t.sdo_apellido, COALESCE(s.sdo_apellido, t.sdo_apellido)),
        (N''nomb'', t.nomb, COALESCE(s.nomb, t.nomb)),
        (N''entidad_nacimiento'', t.entidad_nacimiento, COALESCE(s.entidad_nacimiento, t.entidad_nacimiento)),
        (N''estado_migratorio'', t.estado_migratorio, COALESCE(s.estado_migratorio, t.estado_migratorio)),
        (N''curp'', t.curp, COALESCE(s.curp, t.curp)),
        (N''rfc'', t.rfc, COALESCE(s.rfc, t.rfc)),
        (N''fecha_ultimo_contacto'', CONVERT(NVARCHAR(MAX), t.fecha_ultimo_contacto, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fecha_ultimo_contacto, t.fecha_ultimo_contacto), 23)),
        (N''hora_ultimo_contacto'', CONVERT(NVARCHAR(MAX), t.hora_ultimo_contacto), CONVERT(NVARCHAR(MAX), COALESCE(s.hora_ultimo_contacto, t.hora_ultimo_contacto))),
        (N''entidad_visto'', t.entidad_visto, COALESCE(s.entidad_visto, t.entidad_visto)),
        (N''municipio_visto'', t.municipio_visto, COALESCE(s.municipio_visto, t.municipio_visto)),
        (N''lugar_ultimo_contacto'', t.lugar_ultimo_contacto, COALESCE(s.lugar_ultimo_contacto, t.lugar_ultimo_contacto)),
        (N''senas_tatuaje_datos_identificacion'', t.senas_tatuaje_datos_identificacion, COALESCE(s.senas_tatuaje_datos_identificacion, t.senas_tatuaje_datos_identificacion)),
        (N''localizado_o_no_localizado'', CONVERT(NVARCHAR(MAX), t.localizado_o_no_localizado), CONVERT(NVARCHAR(MAX), COALESCE(s.localizado_o_no_localizado, t.localizado_o_no_localizado))),
        (N''con_o_sin_vida'', CONVERT(NVARCHAR(MAX), t.con_o_sin_vida), CONVERT(NVARCHAR(MAX), COALESCE(s.con_o_sin_vida, t.con_o_sin_vida))),
        (N''fecha_localizacion'', CONVERT(NVARCHAR(MAX), t.fecha_localizacion, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fecha_localizacion, t.fecha_localizacion), 23)),
        (N''voluntaria'', CONVERT(NVARCHAR(MAX), t.voluntaria), CONVERT(NVARCHAR(MAX), COALESCE(s.voluntaria, t.voluntaria))),
        (N''fue_delito'', CONVERT(NVARCHAR(MAX), t.fue_delito), CONVERT(NVARCHAR(MAX), COALESCE(s.fue_delito, t.fue_delito))),
        (N''delito'', t.delito, COALESCE(s.delito, t.delito)),
        (N''obs'', t.obs, COALESCE(s.obs, t.obs))) v(campo, valor_anterior, valor_nuevo)
    WHERE t.activo = 1 AND ISNULL(v.valor_anterior, N''§NULL§'') <> ISNULL(v.valor_nuevo, N''§NULL§'');

    INSERT INTO #Registros (Tipo, IdCi, IdDelito, IdVictima, Accion)
    SELECT N''VICTIMA'', s.id_ci, s.id_delito, s.id_vicf, CASE WHEN t.id_banci_victima IS NULL THEN N''ALTA''
        WHEN EXISTS (SELECT 1 FROM #Cambios x WHERE x.Tipo = N''VICTIMA'' AND x.IdCi = s.id_ci AND x.IdDelito = s.id_delito AND x.IdVictima = s.id_vicf) THEN N''ACTUALIZACION'' ELSE N''SIN_CAMBIO'' END
    FROM #Victimas s LEFT JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = s.id_ci LEFT JOIN dbo.banci_delito d ON d.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion AND d.id_delito = s.id_delito LEFT JOIN dbo.banci_victima t ON t.id_banci_delito = d.id_banci_delito AND t.id_vicf = s.id_vicf;

        DECLARE @CargaPermitida BIT = 0, @ModificacionPermitida BIT = 0;
        SELECT @CargaPermitida = CASE WHEN r.rol = N''SUPER_USUARIO'' THEN 1 ELSE ISNULL(um.habilita_carga, 0) END,
            @ModificacionPermitida = CASE WHEN r.rol = N''SUPER_USUARIO'' THEN 1 ELSE ISNULL(um.habilita_modificacion, 0) END
        FROM dbo.usuario u WITH (HOLDLOCK)
        INNER JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
        INNER JOIN dbo.catalogo_modulo m WITH (HOLDLOCK) ON m.clave = N''BANCI'' AND m.activo = 1
        LEFT JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = m.id_modulo AND um.activo = 1 AND um.habilitado = 1
        WHERE u.id_usuario = @IdUsuario AND u.activo = 1;
        SET @PuedeAceptar = CASE WHEN @CargaPermitida = 1 AND (@ModificacionPermitida = 1 OR NOT EXISTS (SELECT 1 FROM #Registros WHERE Accion = N''ACTUALIZACION'')) THEN 1 ELSE 0 END;
        DECLARE @MotivoBloqueo NVARCHAR(300) = CASE WHEN @CargaPermitida = 0 THEN N''No tiene habilitado el permiso de carga BANCI. Puede rechazar esta carga.''
            WHEN @PuedeAceptar = 0 THEN N''Esta carga modifica registros existentes y no tiene habilitado el permiso de actualización BANCI. Puede rechazarla.'' ELSE NULL END;
        -- La huella cubre todos los registros y campos modificados, no sólo la muestra visible.
        DECLARE @Contenido NVARCHAR(MAX) = CONCAT(
            @CodigoReferencia, N''|'', @IdUsuario, N''|'',
            (SELECT * FROM #Carpetas ORDER BY id_ci FOR JSON PATH, INCLUDE_NULL_VALUES),
            (SELECT * FROM #Delitos ORDER BY id_ci, id_delito FOR JSON PATH, INCLUDE_NULL_VALUES),
            (SELECT * FROM #Victimas ORDER BY id_ci, id_delito, id_vicf FOR JSON PATH, INCLUDE_NULL_VALUES),
            (SELECT * FROM #Registros ORDER BY Tipo, IdCi, IdDelito, IdVictima FOR JSON PATH, INCLUDE_NULL_VALUES),
            (SELECT * FROM #Cambios ORDER BY Tipo, IdCi, IdDelito, IdVictima, Campo FOR JSON PATH, INCLUDE_NULL_VALUES));
        SET @Huella = CONVERT(VARCHAR(64), HASHBYTES(''SHA2_256'', @Contenido), 2);
        IF @Propia = 1 COMMIT TRANSACTION;
        IF @EmitirResultado = 1
        BEGIN
            SELECT @Huella AS Huella, @PuedeAceptar AS PuedeAceptar, @MotivoBloqueo AS MotivoBloqueo, (SELECT COUNT(*) FROM #Cambios) AS TotalCambios;
            SELECT Tipo, SUM(CASE WHEN Accion = N''ALTA'' THEN 1 ELSE 0 END) AS Altas,
                SUM(CASE WHEN Accion = N''ACTUALIZACION'' THEN 1 ELSE 0 END) AS Actualizaciones,
                SUM(CASE WHEN Accion = N''SIN_CAMBIO'' THEN 1 ELSE 0 END) AS SinCambio
            FROM #Registros GROUP BY Tipo ORDER BY Tipo;
            SELECT TOP (200) Tipo, IdCi, IdDelito, IdVictima, Campo, Anterior, Nuevo
            FROM #Cambios ORDER BY Tipo, IdCi, IdDelito, IdVictima, Campo;
        END;
    END TRY
    BEGIN CATCH
        IF @Propia = 1 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';
    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_confirmar_carga
    @CodigoReferencia NVARCHAR(50),
    @Aceptar BIT,
    @IdUsuario INT,
    @HuellaVistaPrevia VARCHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- El procedimiento es dueño de la transacción. La API lo llama sin otra transacción.
    IF @@TRANCOUNT <> 0
        THROW 52400, ''Ejecute la decisión BANCI sin una transacción externa abierta.'', 1;
    IF @Aceptar IS NULL OR @IdUsuario IS NULL OR @IdUsuario <= 0 OR NULLIF(LTRIM(RTRIM(@CodigoReferencia)), N'''') IS NULL
        THROW 52401, ''Debe indicar referencia, usuario y decisión BANCI.'', 1;

    SET @CodigoReferencia = LTRIM(RTRIM(@CodigoReferencia));

    DECLARE @IdBanciCarga BIGINT;
    DECLARE @IdEntidad TINYINT;
    DECLARE @IdUsuarioCarga INT;
    DECLARE @Estado NVARCHAR(40);
    DECLARE @AceptadaAnterior BIT;
    DECLARE @YaResuelta BIT = 0;
    DECLARE @Mensaje NVARCHAR(1000);
    DECLARE @Recurso NVARCHAR(255);
    DECLARE @Bloqueo INT;
    DECLARE @Resultado TABLE
    (
        es_valido BIT, id_banci_carga BIGINT, codigo_referencia NVARCHAR(50),
        estado NVARCHAR(40), aceptada_usuario BIT, ya_resuelta BIT,
        id_usuario_confirmacion INT, fecha_confirmacion DATETIME2(7),
        total_carpetas INT, total_delitos INT, total_victimas INT,
        total_altas INT, total_actualizaciones INT, total_sin_cambio INT,
        total_advertencias INT, mensaje NVARCHAR(1000)
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @IdEntidad = id_entidad_federativa
        FROM dbo.banci_carga
        WHERE codigo_referencia = @CodigoReferencia AND activo = 1;

        IF @IdEntidad IS NULL
            THROW 52402, ''No existe una carga BANCI disponible para esa referencia.'', 1;

        -- Misma entidad: serializa también dos referencias distintas con llaves coincidentes.
        SET @Recurso = CONCAT(N''BANCI:ENTIDAD:'', @IdEntidad);
        EXEC @Bloqueo = sys.sp_getapplock
            @Resource = @Recurso,
            @LockMode = N''Exclusive'',
            @LockOwner = N''Transaction'',
            @LockTimeout = 10000,
            @DbPrincipal = N''public'';

        IF @Bloqueo < 0
            THROW 52403, ''Hay otra integración BANCI en curso para la entidad. Reintente la misma referencia.'', 1;

        SELECT
            @IdBanciCarga = id_banci_carga,
            @IdUsuarioCarga = id_usuario_carga,
            @Estado = estado,
            @AceptadaAnterior = aceptada_usuario
        FROM dbo.banci_carga WITH (UPDLOCK, HOLDLOCK)
        WHERE codigo_referencia = @CodigoReferencia
          AND id_entidad_federativa = @IdEntidad
          AND activo = 1;

        IF @IdBanciCarga IS NULL OR @IdUsuarioCarga <> @IdUsuario
            THROW 52404, ''Sólo el usuario que preparó la carga puede aceptar o rechazar esta referencia.'', 1;

        -- Se comprueba nuevamente el acceso; no basta con haber validado anteriormente.
        -- BANCI utiliza su propia membresía; superusuarios tienen acceso automático.
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.usuario u WITH (HOLDLOCK)
            INNER JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
            INNER JOIN dbo.catalogo_modulo banci WITH (HOLDLOCK) ON banci.clave = N''BANCI'' AND banci.activo = 1
            LEFT JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = banci.id_modulo AND um.habilitado = 1 AND um.activo = 1
            WHERE u.id_usuario = @IdUsuario AND u.activo = 1
              AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad AND um.id_usuario IS NOT NULL))
        )
            THROW 52405, ''El usuario ya no tiene acceso BANCI vigente para la entidad de esta carga.'', 1;

        IF @Estado IN (N''PROCESADO'', N''PROCESADO_CON_ADVERTENCIAS'')
        BEGIN
            IF @Aceptar = 0
                THROW 52406, ''Una carga integrada no puede rechazarse.'', 1;
            IF @AceptadaAnterior IS NULL OR @AceptadaAnterior <> 1
                THROW 52407, ''La carga pertenece al flujo anterior y ya está procesada. No se modifica su decisión histórica.'', 1;
            SET @YaResuelta = 1;
            SET @Mensaje = N''La carga BANCI ya estaba integrada. Se devuelve el resultado existente sin procesar nuevamente.'';
        END
        ELSE IF @Estado = N''RECHAZADO_VALIDACION''
        BEGIN
            IF @Aceptar = 1
                THROW 52408, ''Una carga rechazada no puede integrarse. Debe validar una nueva operación.'', 1;
            SET @YaResuelta = 1;
            SET @Mensaje = N''La carga BANCI ya estaba rechazada. No se modificó la operación.'';
        END
        ELSE
        BEGIN
            IF @Estado <> N''VALIDADO_PENDIENTE'' OR @AceptadaAnterior IS NOT NULL
                THROW 52409, ''La carga BANCI no está pendiente de decisión.'', 1;

            IF @Aceptar = 0
            BEGIN
                UPDATE dbo.banci_carga
                SET estado = N''RECHAZADO_VALIDACION'',
                    aceptada_usuario = 0,
                    id_usuario_confirmacion = @IdUsuario,
                    fecha_confirmacion = SYSDATETIME(),
                    mensaje_error = NULL
                WHERE id_banci_carga = @IdBanciCarga;

                INSERT INTO dbo.banci_carga_bitacora_estado
                    (id_banci_carga, estado_anterior, estado_nuevo, id_usuario, comentario)
                VALUES
                    (@IdBanciCarga, @Estado, N''RECHAZADO_VALIDACION'', @IdUsuario, N''El usuario rechazó la carga antes de integrar. Se conservan temporales y observaciones.'');

                SET @Mensaje = N''La carga BANCI fue rechazada. No se integraron datos definitivos.'';
            END
            ELSE
            BEGIN
                DECLARE @HuellaActual VARCHAR(64), @PuedeAceptar BIT;
                EXEC dbo.sp_banci_vista_previa @CodigoReferencia = @CodigoReferencia, @IdUsuario = @IdUsuario, @Huella = @HuellaActual OUTPUT, @EmitirResultado = 0, @PuedeAceptar = @PuedeAceptar OUTPUT;
                IF ISNULL(@PuedeAceptar, 0) = 0 THROW 52426, ''Los permisos BANCI actuales no permiten integrar esta carga.'', 1;
                IF @HuellaVistaPrevia IS NULL OR @HuellaVistaPrevia <> @HuellaActual
                    THROW 52425, ''La vista previa cambió o no fue consultada. Actualice el estado y revise los cambios antes de aceptar.'', 1;
                UPDATE dbo.banci_carga
                SET estado = N''PROCESANDO'',
                    aceptada_usuario = 1,
                    id_usuario_confirmacion = @IdUsuario,
                    fecha_confirmacion = SYSDATETIME(),
                    fecha_inicio_procesamiento = SYSDATETIME(),
                    fecha_fin_procesamiento = NULL,
                    mensaje_error = NULL
                WHERE id_banci_carga = @IdBanciCarga;

                INSERT INTO dbo.banci_carga_bitacora_estado
                    (id_banci_carga, estado_anterior, estado_nuevo, id_usuario, comentario)
                VALUES
                    (@IdBanciCarga, @Estado, N''PROCESANDO'', @IdUsuario, N''El usuario aceptó la carga y sus advertencias. Inicia integración atómica.'');

                EXEC dbo.sp_banci_procesar_carga
                    @IdBanciCarga = @IdBanciCarga,
                    @IdUsuario = @IdUsuario,
                    @EmitirResultado = 0;

                SELECT @Estado = estado FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga;
                IF @Estado NOT IN (N''PROCESADO'', N''PROCESADO_CON_ADVERTENCIAS'')
                    THROW 52410, ''La integración BANCI no terminó correctamente. Se revierte la operación.'', 1;

                INSERT INTO dbo.banci_carga_bitacora_estado
                    (id_banci_carga, estado_anterior, estado_nuevo, id_usuario, comentario)
                VALUES
                    (@IdBanciCarga, N''PROCESANDO'', @Estado, @IdUsuario, N''Integración BANCI terminada. Los totales corresponden a los cambios aplicados.'');

                SET @Mensaje = N''La carga BANCI fue aceptada e integrada correctamente.'';
            END;
        END;

        INSERT INTO @Resultado
        SELECT CONVERT(BIT, 1), id_banci_carga, codigo_referencia,
               estado, aceptada_usuario, @YaResuelta,
               id_usuario_confirmacion, fecha_confirmacion,
               total_carpetas, total_delitos, total_victimas,
               total_altas, total_actualizaciones, total_sin_cambio,
               total_advertencias, @Mensaje
        FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga;

        COMMIT TRANSACTION;
        SELECT * FROM @Resultado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';
    -- Sin modificar datos personales ni cargas: sólo permisos del rol SUPER_USUARIO.
    UPDATE um SET habilitado = 1, habilita_carga = 1, habilita_modificacion = 1, administra_delitos = 1, activo = 1, fecha_modificacion = SYSDATETIME()
    FROM dbo.usuario_modulo um INNER JOIN dbo.usuario u ON u.id_usuario = um.id_usuario
    INNER JOIN dbo.roles r ON r.id_rol = u.id_rol AND r.activo = 1 AND r.rol = N'SUPER_USUARIO'
    INNER JOIN dbo.catalogo_modulo m ON m.id_modulo = um.id_modulo AND m.activo = 1 WHERE u.activo = 1;
    INSERT INTO dbo.usuario_modulo (id_usuario, id_modulo, habilitado, habilita_carga, habilita_modificacion, administra_delitos, activo)
    SELECT u.id_usuario, m.id_modulo, 1, 1, 1, 1, 1 FROM dbo.usuario u
    INNER JOIN dbo.roles r ON r.id_rol = u.id_rol AND r.activo = 1 AND r.rol = N'SUPER_USUARIO'
    CROSS JOIN dbo.catalogo_modulo m
    WHERE u.activo = 1 AND m.activo = 1 AND NOT EXISTS (SELECT 1 FROM dbo.usuario_modulo um WITH (UPDLOCK, HOLDLOCK) WHERE um.id_usuario = u.id_usuario AND um.id_modulo = m.id_modulo);
    UPDATE h SET habilita_carga = 1, habilita_modificacion = 1, activo = 1
    FROM dbo.habilita_carga_modificacion h INNER JOIN dbo.usuario u ON u.id_usuario = h.id_usuario
    INNER JOIN dbo.roles r ON r.id_rol = u.id_rol AND r.activo = 1 AND r.rol = N'SUPER_USUARIO' WHERE u.activo = 1;
    INSERT INTO dbo.habilita_carga_modificacion (id_usuario, habilita_carga, habilita_modificacion, activo)
    SELECT u.id_usuario, 1, 1, 1 FROM dbo.usuario u INNER JOIN dbo.roles r ON r.id_rol = u.id_rol AND r.activo = 1 AND r.rol = N'SUPER_USUARIO'
    WHERE u.activo = 1 AND NOT EXISTS (SELECT 1 FROM dbo.habilita_carga_modificacion h WITH (UPDLOCK, HOLDLOCK) WHERE h.id_usuario = u.id_usuario);
    COMMIT TRANSACTION;
    SELECT m.clave, u.usuario, r.rol, um.habilitado, um.habilita_carga, um.habilita_modificacion, um.activo
    FROM dbo.usuario_modulo um INNER JOIN dbo.usuario u ON u.id_usuario = um.id_usuario INNER JOIN dbo.roles r ON r.id_rol = u.id_rol
    INNER JOIN dbo.catalogo_modulo m ON m.id_modulo = um.id_modulo WHERE m.clave = N'BANCI' ORDER BY r.rol, u.usuario;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
