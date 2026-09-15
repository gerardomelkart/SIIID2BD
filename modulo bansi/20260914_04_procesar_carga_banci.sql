USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_banci_procesar_carga
    @IdBanciCarga BIGINT,
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdEntidad TINYINT;
    DECLARE @Modalidad NVARCHAR(40);
    DECLARE @Origen NVARCHAR(40);
    DECLARE @Altas INT = 0;
    DECLARE @Actualizaciones INT = 0;
    DECLARE @SinCambio INT = 0;

    SELECT
        @IdEntidad = id_entidad_federativa,
        @Modalidad = modalidad_ingesta
    FROM dbo.banci_carga
    WHERE id_banci_carga = @IdBanciCarga
      AND activo = 1;

    IF @IdEntidad IS NULL THROW 52200, 'No existe la carga BANCI indicada.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.banci_carga
        WHERE id_banci_carga = @IdBanciCarga
          AND estado IN (N'PROCESADO', N'PROCESADO_CON_ADVERTENCIAS')
    )
        THROW 52201, 'La carga BANCI ya fue procesada.', 1;

    SET @Origen =
        CASE
            WHEN @Modalidad = N'FORMULARIO' THEN N'FORMULARIO'
            WHEN @Modalidad = N'COMPLEMENTO_CONSOLIDADO' THEN N'COMPLEMENTO_CONSOLIDADO'
            ELSE N'CARGA_MASIVA'
        END;

    /* ============================================================
       CARPETAS
       ============================================================ */

    SELECT
        id_entidad_federativa = @IdEntidad,
        entidad = NULLIF(LTRIM(RTRIM(entidad)), N''),
        id_ci = NULLIF(LTRIM(RTRIM(id_ci)), N''),
        ntra_ci = NULLIF(LTRIM(RTRIM(ntra_ci)), N''),
        fha_de_ini = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''))),
        hra_de_ini = TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(hra_de_ini)), N'')),
        rmen_de_hchos = NULLIF(LTRIM(RTRIM(rmen_de_hchos)), N''),
        ord_apreh = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(ord_apreh)), N'')),
        fgran = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(fgran)), N'')),
        ctaon = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(ctaon)), N'')),
        td_v_ap = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(td_v_ap)), N'')),
        proc_abrev = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(proc_abrev)), N'')),
        juc_oral = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(juc_oral)), N'')),
        td_sen_con = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(td_sen_con)), N'')),
        no_ejer_acc_pnal = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(no_ejer_acc_pnal)), N'')),
        otra = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(otra)), N'')),
        dic = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(dic)), N''))
    INTO #Carpetas
    FROM dbo.banci_carga_tmp_carpeta
    WHERE id_banci_carga = @IdBanciCarga
      AND activo = 1;

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro,
        id_registro,
        id_entidad_federativa,
        id_ci,
        id_delito,
        id_vicf,
        no_banci,
        tipo_movimiento,
        campo,
        valor_anterior,
        valor_nuevo,
        origen,
        id_banci_carga,
        id_usuario
    )
    SELECT
        N'CARPETA',
        t.id_banci_carpeta_investigacion,
        t.id_entidad_federativa,
        t.id_ci,
        NULL,
        NULL,
        NULL,
        N'MODIFICACION',
        v.campo,
        v.valor_anterior,
        v.valor_nuevo,
        @Origen,
        @IdBanciCarga,
        @IdUsuario
    FROM dbo.banci_carpeta_investigacion t
    INNER JOIN #Carpetas s ON s.id_entidad_federativa = t.id_entidad_federativa AND s.id_ci = t.id_ci
    CROSS APPLY
    (
        VALUES
        (N'ntra_ci', CONVERT(NVARCHAR(MAX), t.ntra_ci), CONVERT(NVARCHAR(MAX), COALESCE(s.ntra_ci, t.ntra_ci))),
        (N'fha_de_ini', CONVERT(NVARCHAR(MAX), t.fha_de_ini, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fha_de_ini, t.fha_de_ini), 23)),
        (N'hra_de_ini', CONVERT(NVARCHAR(MAX), t.hra_de_ini), CONVERT(NVARCHAR(MAX), COALESCE(s.hra_de_ini, t.hra_de_ini))),
        (N'rmen_de_hchos', t.rmen_de_hchos, COALESCE(s.rmen_de_hchos, t.rmen_de_hchos)),
        (N'ord_apreh', CONVERT(NVARCHAR(MAX), t.ord_apreh), CONVERT(NVARCHAR(MAX), COALESCE(s.ord_apreh, t.ord_apreh))),
        (N'fgran', CONVERT(NVARCHAR(MAX), t.fgran), CONVERT(NVARCHAR(MAX), COALESCE(s.fgran, t.fgran))),
        (N'ctaon', CONVERT(NVARCHAR(MAX), t.ctaon), CONVERT(NVARCHAR(MAX), COALESCE(s.ctaon, t.ctaon))),
        (N'td_v_ap', CONVERT(NVARCHAR(MAX), t.td_v_ap), CONVERT(NVARCHAR(MAX), COALESCE(s.td_v_ap, t.td_v_ap))),
        (N'proc_abrev', CONVERT(NVARCHAR(MAX), t.proc_abrev), CONVERT(NVARCHAR(MAX), COALESCE(s.proc_abrev, t.proc_abrev))),
        (N'juc_oral', CONVERT(NVARCHAR(MAX), t.juc_oral), CONVERT(NVARCHAR(MAX), COALESCE(s.juc_oral, t.juc_oral))),
        (N'td_sen_con', CONVERT(NVARCHAR(MAX), t.td_sen_con), CONVERT(NVARCHAR(MAX), COALESCE(s.td_sen_con, t.td_sen_con))),
        (N'no_ejer_acc_pnal', CONVERT(NVARCHAR(MAX), t.no_ejer_acc_pnal), CONVERT(NVARCHAR(MAX), COALESCE(s.no_ejer_acc_pnal, t.no_ejer_acc_pnal))),
        (N'otra', CONVERT(NVARCHAR(MAX), t.otra), CONVERT(NVARCHAR(MAX), COALESCE(s.otra, t.otra))),
        (N'dic', CONVERT(NVARCHAR(MAX), t.dic), CONVERT(NVARCHAR(MAX), COALESCE(s.dic, t.dic)))
    ) v(campo, valor_anterior, valor_nuevo)
    WHERE t.activo = 1
      AND ISNULL(v.valor_anterior, N'§NULL§') <> ISNULL(v.valor_nuevo, N'§NULL§');

    UPDATE t
    SET
        entidad = COALESCE(s.entidad, t.entidad),
        ntra_ci = COALESCE(s.ntra_ci, t.ntra_ci),
        fha_de_ini = COALESCE(s.fha_de_ini, t.fha_de_ini),
        hra_de_ini = COALESCE(s.hra_de_ini, t.hra_de_ini),
        rmen_de_hchos = COALESCE(s.rmen_de_hchos, t.rmen_de_hchos),
        ord_apreh = COALESCE(s.ord_apreh, t.ord_apreh),
        fgran = COALESCE(s.fgran, t.fgran),
        ctaon = COALESCE(s.ctaon, t.ctaon),
        td_v_ap = COALESCE(s.td_v_ap, t.td_v_ap),
        proc_abrev = COALESCE(s.proc_abrev, t.proc_abrev),
        juc_oral = COALESCE(s.juc_oral, t.juc_oral),
        td_sen_con = COALESCE(s.td_sen_con, t.td_sen_con),
        no_ejer_acc_pnal = COALESCE(s.no_ejer_acc_pnal, t.no_ejer_acc_pnal),
        otra = COALESCE(s.otra, t.otra),
        dic = COALESCE(s.dic, t.dic),
        id_banci_carga_ultima = @IdBanciCarga,
        id_usuario_modificacion = @IdUsuario,
        fecha_modificacion = SYSDATETIME()
    FROM dbo.banci_carpeta_investigacion t
    INNER JOIN #Carpetas s ON s.id_entidad_federativa = t.id_entidad_federativa AND s.id_ci = t.id_ci
    WHERE EXISTS
    (
        SELECT 1
        FROM dbo.banci_historial_cambio h
        WHERE h.id_banci_carga = @IdBanciCarga
          AND h.tipo_registro = N'CARPETA'
          AND h.tipo_movimiento = N'MODIFICACION'
          AND h.id_registro = t.id_banci_carpeta_investigacion
    );

    CREATE TABLE #AltasCarpetas(id BIGINT PRIMARY KEY);

    INSERT INTO dbo.banci_carpeta_investigacion
    (
        id_entidad_federativa, entidad, id_ci, ntra_ci, fha_de_ini, hra_de_ini,
        rmen_de_hchos, ord_apreh, fgran, ctaon, td_v_ap, proc_abrev, juc_oral,
        td_sen_con, no_ejer_acc_pnal, otra, dic, id_banci_carga_ultima,
        id_usuario_registro, id_usuario_modificacion
    )
    OUTPUT INSERTED.id_banci_carpeta_investigacion INTO #AltasCarpetas(id)
    SELECT
        s.id_entidad_federativa, s.entidad, s.id_ci, s.ntra_ci, s.fha_de_ini, s.hra_de_ini,
        s.rmen_de_hchos, s.ord_apreh, s.fgran, s.ctaon, s.td_v_ap, s.proc_abrev, s.juc_oral,
        s.td_sen_con, s.no_ejer_acc_pnal, s.otra, s.dic, @IdBanciCarga, @IdUsuario, @IdUsuario
    FROM #Carpetas s
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_carpeta_investigacion t
        WHERE t.id_entidad_federativa = s.id_entidad_federativa
          AND t.id_ci = s.id_ci
    );

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci,
        tipo_movimiento, origen, id_banci_carga, id_usuario
    )
    SELECT
        N'CARPETA', t.id_banci_carpeta_investigacion, t.id_entidad_federativa,
        t.id_ci, N'ALTA', @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_carpeta_investigacion t
    INNER JOIN #AltasCarpetas a ON a.id = t.id_banci_carpeta_investigacion;

    /* ============================================================
       DELITOS
       ============================================================ */

    SELECT
        id_ci = NULLIF(LTRIM(RTRIM(d.id_ci)), N''),
        id_delito = NULLIF(LTRIM(RTRIM(d.id_delito)), N''),
        dto = NULLIF(LTRIM(RTRIM(d.dto)), N''),
        moda_dto = NULLIF(LTRIM(RTRIM(d.moda_dto)), N''),
        forma_acc = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.forma_acc)), N'')),
        fha_de_hchos = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(d.fha_de_hchos)), N''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(d.fha_de_hchos)), N''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(d.fha_de_hchos)), N''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(d.fha_de_hchos)), N''))),
        hra_de_hchos = TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(d.hra_de_hchos)), N'')),
        emto_com_dto = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.emto_com_dto)), N'')),
        grdo_cons = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.grdo_cons)), N'')),
        clasf_de_dto = NULLIF(LTRIM(RTRIM(d.clasf_de_dto)), N''),
        nom_ent_hchos = NULLIF(LTRIM(RTRIM(d.nom_ent_hchos)), N''),
        id_ent_hchos = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.id_ent_hchos)), N'')),
        nom_mun_hchos = NULLIF(LTRIM(RTRIM(d.nom_mun_hchos)), N''),
        id_mun_hchos = m.clave,
        nom_loc_hchos = NULLIF(LTRIM(RTRIM(d.nom_loc_hchos)), N''),
        id_loc_hchos = NULLIF(LTRIM(RTRIM(d.id_loc_hchos)), N''),
        nom_col_hchos = NULLIF(LTRIM(RTRIM(d.nom_col_hchos)), N''),
        id_col_hchos = NULLIF(LTRIM(RTRIM(d.id_col_hchos)), N''),
        cp = NULLIF(LTRIM(RTRIM(d.cp)), N''),
        coord_x = TRY_CONVERT(DECIMAL(10,6), REPLACE(NULLIF(LTRIM(RTRIM(d.coord_x)), N''), N',', N'.')),
        coord_y = TRY_CONVERT(DECIMAL(10,6), REPLACE(NULLIF(LTRIM(RTRIM(d.coord_y)), N''), N',', N'.')),
        dom_hchos = NULLIF(LTRIM(RTRIM(d.dom_hchos)), N'')
    INTO #Delitos
    FROM dbo.banci_carga_tmp_delito d
    OUTER APPLY
    (
        SELECT TOP (1) cm.clave
        FROM dbo.catalogo_municipio cm
        WHERE cm.id_entidad_federativa = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(d.id_ent_hchos)), N''))
          AND cm.activo = 1
          AND
          (
                cm.clave = NULLIF(LTRIM(RTRIM(d.id_mun_hchos)), N'')
             OR TRY_CONVERT(INT, cm.clave) = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(d.id_mun_hchos)), N''))
          )
    ) m
    WHERE d.id_banci_carga = @IdBanciCarga
      AND d.activo = 1;

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci, id_delito,
        tipo_movimiento, campo, valor_anterior, valor_nuevo, origen,
        id_banci_carga, id_usuario
    )
    SELECT
        N'DELITO', t.id_banci_delito, c.id_entidad_federativa, c.id_ci, t.id_delito,
        N'MODIFICACION', v.campo, v.valor_anterior, v.valor_nuevo,
        @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_delito t
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = t.id_banci_carpeta_investigacion
    INNER JOIN #Delitos s ON s.id_ci = c.id_ci AND s.id_delito = t.id_delito
    CROSS APPLY
    (
        VALUES
        (N'dto', CONVERT(NVARCHAR(MAX), t.dto), CONVERT(NVARCHAR(MAX), COALESCE(s.dto, t.dto))),
        (N'moda_dto', t.moda_dto, COALESCE(s.moda_dto, t.moda_dto)),
        (N'forma_acc', CONVERT(NVARCHAR(MAX), t.forma_acc), CONVERT(NVARCHAR(MAX), COALESCE(s.forma_acc, t.forma_acc))),
        (N'fha_de_hchos', CONVERT(NVARCHAR(MAX), t.fha_de_hchos, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fha_de_hchos, t.fha_de_hchos), 23)),
        (N'hra_de_hchos', CONVERT(NVARCHAR(MAX), t.hra_de_hchos), CONVERT(NVARCHAR(MAX), COALESCE(s.hra_de_hchos, t.hra_de_hchos))),
        (N'emto_com_dto', CONVERT(NVARCHAR(MAX), t.emto_com_dto), CONVERT(NVARCHAR(MAX), COALESCE(s.emto_com_dto, t.emto_com_dto))),
        (N'grdo_cons', CONVERT(NVARCHAR(MAX), t.grdo_cons), CONVERT(NVARCHAR(MAX), COALESCE(s.grdo_cons, t.grdo_cons))),
        (N'clasf_de_dto', t.clasf_de_dto, COALESCE(s.clasf_de_dto, t.clasf_de_dto)),
        (N'nom_ent_hchos', t.nom_ent_hchos, COALESCE(s.nom_ent_hchos, t.nom_ent_hchos)),
        (N'id_ent_hchos', CONVERT(NVARCHAR(MAX), t.id_ent_hchos), CONVERT(NVARCHAR(MAX), COALESCE(s.id_ent_hchos, t.id_ent_hchos))),
        (N'nom_mun_hchos', t.nom_mun_hchos, COALESCE(s.nom_mun_hchos, t.nom_mun_hchos)),
        (N'id_mun_hchos', t.id_mun_hchos, COALESCE(s.id_mun_hchos, t.id_mun_hchos)),
        (N'nom_loc_hchos', t.nom_loc_hchos, COALESCE(s.nom_loc_hchos, t.nom_loc_hchos)),
        (N'id_loc_hchos', t.id_loc_hchos, COALESCE(s.id_loc_hchos, t.id_loc_hchos)),
        (N'nom_col_hchos', t.nom_col_hchos, COALESCE(s.nom_col_hchos, t.nom_col_hchos)),
        (N'id_col_hchos', t.id_col_hchos, COALESCE(s.id_col_hchos, t.id_col_hchos)),
        (N'cp', t.cp, COALESCE(s.cp, t.cp)),
        (N'coord_x', CONVERT(NVARCHAR(MAX), t.coord_x), CONVERT(NVARCHAR(MAX), COALESCE(s.coord_x, t.coord_x))),
        (N'coord_y', CONVERT(NVARCHAR(MAX), t.coord_y), CONVERT(NVARCHAR(MAX), COALESCE(s.coord_y, t.coord_y))),
        (N'dom_hchos', t.dom_hchos, COALESCE(s.dom_hchos, t.dom_hchos))
    ) v(campo, valor_anterior, valor_nuevo)
    WHERE c.id_entidad_federativa = @IdEntidad
      AND t.activo = 1
      AND ISNULL(v.valor_anterior, N'§NULL§') <> ISNULL(v.valor_nuevo, N'§NULL§');

    UPDATE t
    SET
        dto = COALESCE(s.dto, t.dto),
        moda_dto = COALESCE(s.moda_dto, t.moda_dto),
        forma_acc = COALESCE(s.forma_acc, t.forma_acc),
        fha_de_hchos = COALESCE(s.fha_de_hchos, t.fha_de_hchos),
        hra_de_hchos = COALESCE(s.hra_de_hchos, t.hra_de_hchos),
        emto_com_dto = COALESCE(s.emto_com_dto, t.emto_com_dto),
        grdo_cons = COALESCE(s.grdo_cons, t.grdo_cons),
        clasf_de_dto = COALESCE(s.clasf_de_dto, t.clasf_de_dto),
        nom_ent_hchos = COALESCE(s.nom_ent_hchos, t.nom_ent_hchos),
        id_ent_hchos = COALESCE(s.id_ent_hchos, t.id_ent_hchos),
        nom_mun_hchos = COALESCE(s.nom_mun_hchos, t.nom_mun_hchos),
        id_mun_hchos = COALESCE(s.id_mun_hchos, t.id_mun_hchos),
        nom_loc_hchos = COALESCE(s.nom_loc_hchos, t.nom_loc_hchos),
        id_loc_hchos = COALESCE(s.id_loc_hchos, t.id_loc_hchos),
        nom_col_hchos = COALESCE(s.nom_col_hchos, t.nom_col_hchos),
        id_col_hchos = COALESCE(s.id_col_hchos, t.id_col_hchos),
        cp = COALESCE(s.cp, t.cp),
        coord_x = COALESCE(s.coord_x, t.coord_x),
        coord_y = COALESCE(s.coord_y, t.coord_y),
        dom_hchos = COALESCE(s.dom_hchos, t.dom_hchos),
        id_banci_carga_ultima = @IdBanciCarga,
        id_usuario_modificacion = @IdUsuario,
        fecha_modificacion = SYSDATETIME()
    FROM dbo.banci_delito t
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = t.id_banci_carpeta_investigacion
    INNER JOIN #Delitos s ON s.id_ci = c.id_ci AND s.id_delito = t.id_delito
    WHERE c.id_entidad_federativa = @IdEntidad
      AND EXISTS
      (
          SELECT 1
          FROM dbo.banci_historial_cambio h
          WHERE h.id_banci_carga = @IdBanciCarga
            AND h.tipo_registro = N'DELITO'
            AND h.tipo_movimiento = N'MODIFICACION'
            AND h.id_registro = t.id_banci_delito
      );

    CREATE TABLE #AltasDelitos(id BIGINT PRIMARY KEY);

    INSERT INTO dbo.banci_delito
    (
        id_banci_carpeta_investigacion, id_delito, dto, moda_dto, forma_acc,
        fha_de_hchos, hra_de_hchos, emto_com_dto, grdo_cons, clasf_de_dto,
        nom_ent_hchos, id_ent_hchos, nom_mun_hchos, id_mun_hchos,
        nom_loc_hchos, id_loc_hchos, nom_col_hchos, id_col_hchos, cp,
        coord_x, coord_y, dom_hchos, id_banci_carga_ultima,
        id_usuario_registro, id_usuario_modificacion
    )
    OUTPUT INSERTED.id_banci_delito INTO #AltasDelitos(id)
    SELECT
        c.id_banci_carpeta_investigacion, s.id_delito, s.dto, s.moda_dto, s.forma_acc,
        s.fha_de_hchos, s.hra_de_hchos, s.emto_com_dto, s.grdo_cons, s.clasf_de_dto,
        s.nom_ent_hchos, s.id_ent_hchos, s.nom_mun_hchos, s.id_mun_hchos,
        s.nom_loc_hchos, s.id_loc_hchos, s.nom_col_hchos, s.id_col_hchos, s.cp,
        s.coord_x, s.coord_y, s.dom_hchos, @IdBanciCarga, @IdUsuario, @IdUsuario
    FROM #Delitos s
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = s.id_ci
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_delito t
        WHERE t.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion
          AND t.id_delito = s.id_delito
    );

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci, id_delito,
        tipo_movimiento, origen, id_banci_carga, id_usuario
    )
    SELECT
        N'DELITO', d.id_banci_delito, c.id_entidad_federativa, c.id_ci,
        d.id_delito, N'ALTA', @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_delito d
    INNER JOIN #AltasDelitos a ON a.id = d.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion;

    /* ============================================================
       VÍCTIMAS
       No_BANCI se ignora intencionalmente.
       ============================================================ */

    SELECT
        id_ci = NULLIF(LTRIM(RTRIM(v.id_ci)), N''),
        id_delito = NULLIF(LTRIM(RTRIM(v.id_delito)), N''),
        id_vicf = NULLIF(LTRIM(RTRIM(v.id_vicf)), N''),
        id_tv = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.id_tv)), N'')),
        id_tpm = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.id_tpm)), N'')),
        sexo = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.sexo)), N'')),
        genero = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.genero)), N'')),
        pob = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.pob)), N'')),
        disc = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.disc)), N'')),
        fha_nac = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fha_nac)), N''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fha_nac)), N''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fha_nac)), N''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fha_nac)), N''))),
        edad = TRY_CONVERT(SMALLINT, NULLIF(LTRIM(RTRIM(v.edad)), N'')),
        nacional = n.clave,
        folio_fotovolante = NULLIF(LTRIM(RTRIM(v.folio_fotovolante)), N''),
        folio_rnpdno = NULLIF(LTRIM(RTRIM(v.folio_rnpdno)), N''),
        pro_apellido = NULLIF(LTRIM(RTRIM(v.pro_apellido)), N''),
        sdo_apellido = NULLIF(LTRIM(RTRIM(v.sdo_apellido)), N''),
        nomb = NULLIF(LTRIM(RTRIM(v.nomb)), N''),
        entidad_nacimiento = NULLIF(LTRIM(RTRIM(v.entidad_nacimiento)), N''),
        estado_migratorio = NULLIF(LTRIM(RTRIM(v.estado_migratorio)), N''),
        curp = NULLIF(LTRIM(RTRIM(v.curp)), N''),
        rfc = NULLIF(LTRIM(RTRIM(v.rfc)), N''),
        fecha_ultimo_contacto = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_ultimo_contacto)), N''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_ultimo_contacto)), N''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_ultimo_contacto)), N''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_ultimo_contacto)), N''))),
        hora_ultimo_contacto = TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(v.hora_ultimo_contacto)), N'')),
        entidad_visto = NULLIF(LTRIM(RTRIM(v.entidad_visto)), N''),
        municipio_visto = NULLIF(LTRIM(RTRIM(v.municipio_visto)), N''),
        lugar_ultimo_contacto = NULLIF(LTRIM(RTRIM(v.lugar_ultimo_contacto)), N''),
        senas_tatuaje_datos_identificacion = NULLIF(LTRIM(RTRIM(v.senas_tatuaje_datos_identificacion)), N''),
        localizado_o_no_localizado = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.localizado_o_no_localizado)), N'')),
        con_o_sin_vida = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.con_o_sin_vida)), N'')),
        fecha_localizacion = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_localizacion)), N''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_localizacion)), N''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_localizacion)), N''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(v.fecha_localizacion)), N''))),
        voluntaria = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.voluntaria)), N'')),
        fue_delito = TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM(v.fue_delito)), N'')),
        delito = NULLIF(LTRIM(RTRIM(v.delito)), N''),
        obs = NULLIF(LTRIM(RTRIM(v.obs)), N'')
    INTO #Victimas
    FROM dbo.banci_carga_tmp_victima v
    OUTER APPLY
    (
        SELECT TOP (1) cn.clave
        FROM dbo.catalogo_nacionalidad cn
        WHERE cn.activo = 1
          AND
          (
                cn.clave = NULLIF(LTRIM(RTRIM(v.nacional)), N'')
             OR TRY_CONVERT(INT, cn.clave) = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(v.nacional)), N''))
          )
    ) n
    WHERE v.id_banci_carga = @IdBanciCarga
      AND v.activo = 1;

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci, id_delito,
        id_vicf, no_banci, tipo_movimiento, campo, valor_anterior, valor_nuevo,
        origen, id_banci_carga, id_usuario
    )
    SELECT
        N'VICTIMA', t.id_banci_victima, c.id_entidad_federativa, c.id_ci,
        d.id_delito, t.id_vicf, t.no_banci, N'MODIFICACION',
        x.campo, x.valor_anterior, x.valor_nuevo, @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_victima t
    INNER JOIN dbo.banci_delito d ON d.id_banci_delito = t.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion
    INNER JOIN #Victimas s ON s.id_ci = c.id_ci AND s.id_delito = d.id_delito AND s.id_vicf = t.id_vicf
    CROSS APPLY
    (
        VALUES
        (N'id_tv', CONVERT(NVARCHAR(MAX), t.id_tv), CONVERT(NVARCHAR(MAX), COALESCE(s.id_tv, t.id_tv))),
        (N'id_tpm', CONVERT(NVARCHAR(MAX), t.id_tpm), CONVERT(NVARCHAR(MAX), COALESCE(s.id_tpm, t.id_tpm))),
        (N'sexo', CONVERT(NVARCHAR(MAX), t.sexo), CONVERT(NVARCHAR(MAX), COALESCE(s.sexo, t.sexo))),
        (N'genero', CONVERT(NVARCHAR(MAX), t.genero), CONVERT(NVARCHAR(MAX), COALESCE(s.genero, t.genero))),
        (N'pob', CONVERT(NVARCHAR(MAX), t.pob), CONVERT(NVARCHAR(MAX), COALESCE(s.pob, t.pob))),
        (N'disc', CONVERT(NVARCHAR(MAX), t.disc), CONVERT(NVARCHAR(MAX), COALESCE(s.disc, t.disc))),
        (N'fha_nac', CONVERT(NVARCHAR(MAX), t.fha_nac, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fha_nac, t.fha_nac), 23)),
        (N'edad', CONVERT(NVARCHAR(MAX), t.edad), CONVERT(NVARCHAR(MAX), COALESCE(s.edad, t.edad))),
        (N'nacional', t.nacional, COALESCE(s.nacional, t.nacional)),
        (N'folio_fotovolante', t.folio_fotovolante, COALESCE(s.folio_fotovolante, t.folio_fotovolante)),
        (N'folio_rnpdno', t.folio_rnpdno, COALESCE(s.folio_rnpdno, t.folio_rnpdno)),
        (N'pro_apellido', t.pro_apellido, COALESCE(s.pro_apellido, t.pro_apellido)),
        (N'sdo_apellido', t.sdo_apellido, COALESCE(s.sdo_apellido, t.sdo_apellido)),
        (N'nomb', t.nomb, COALESCE(s.nomb, t.nomb)),
        (N'entidad_nacimiento', t.entidad_nacimiento, COALESCE(s.entidad_nacimiento, t.entidad_nacimiento)),
        (N'estado_migratorio', t.estado_migratorio, COALESCE(s.estado_migratorio, t.estado_migratorio)),
        (N'curp', t.curp, COALESCE(s.curp, t.curp)),
        (N'rfc', t.rfc, COALESCE(s.rfc, t.rfc)),
        (N'fecha_ultimo_contacto', CONVERT(NVARCHAR(MAX), t.fecha_ultimo_contacto, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fecha_ultimo_contacto, t.fecha_ultimo_contacto), 23)),
        (N'hora_ultimo_contacto', CONVERT(NVARCHAR(MAX), t.hora_ultimo_contacto), CONVERT(NVARCHAR(MAX), COALESCE(s.hora_ultimo_contacto, t.hora_ultimo_contacto))),
        (N'entidad_visto', t.entidad_visto, COALESCE(s.entidad_visto, t.entidad_visto)),
        (N'municipio_visto', t.municipio_visto, COALESCE(s.municipio_visto, t.municipio_visto)),
        (N'lugar_ultimo_contacto', t.lugar_ultimo_contacto, COALESCE(s.lugar_ultimo_contacto, t.lugar_ultimo_contacto)),
        (N'senas_tatuaje_datos_identificacion', t.senas_tatuaje_datos_identificacion, COALESCE(s.senas_tatuaje_datos_identificacion, t.senas_tatuaje_datos_identificacion)),
        (N'localizado_o_no_localizado', CONVERT(NVARCHAR(MAX), t.localizado_o_no_localizado), CONVERT(NVARCHAR(MAX), COALESCE(s.localizado_o_no_localizado, t.localizado_o_no_localizado))),
        (N'con_o_sin_vida', CONVERT(NVARCHAR(MAX), t.con_o_sin_vida), CONVERT(NVARCHAR(MAX), COALESCE(s.con_o_sin_vida, t.con_o_sin_vida))),
        (N'fecha_localizacion', CONVERT(NVARCHAR(MAX), t.fecha_localizacion, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fecha_localizacion, t.fecha_localizacion), 23)),
        (N'voluntaria', CONVERT(NVARCHAR(MAX), t.voluntaria), CONVERT(NVARCHAR(MAX), COALESCE(s.voluntaria, t.voluntaria))),
        (N'fue_delito', CONVERT(NVARCHAR(MAX), t.fue_delito), CONVERT(NVARCHAR(MAX), COALESCE(s.fue_delito, t.fue_delito))),
        (N'delito', t.delito, COALESCE(s.delito, t.delito)),
        (N'obs', t.obs, COALESCE(s.obs, t.obs))
    ) x(campo, valor_anterior, valor_nuevo)
    WHERE c.id_entidad_federativa = @IdEntidad
      AND t.activo = 1
      AND ISNULL(x.valor_anterior, N'§NULL§') <> ISNULL(x.valor_nuevo, N'§NULL§');

    UPDATE t
    SET
        id_tv = COALESCE(s.id_tv, t.id_tv),
        id_tpm = COALESCE(s.id_tpm, t.id_tpm),
        sexo = COALESCE(s.sexo, t.sexo),
        genero = COALESCE(s.genero, t.genero),
        pob = COALESCE(s.pob, t.pob),
        disc = COALESCE(s.disc, t.disc),
        fha_nac = COALESCE(s.fha_nac, t.fha_nac),
        edad = COALESCE(s.edad, t.edad),
        nacional = COALESCE(s.nacional, t.nacional),

        /* No_BANCI NO SE TOCA */

        folio_fotovolante = COALESCE(s.folio_fotovolante, t.folio_fotovolante),
        folio_rnpdno = COALESCE(s.folio_rnpdno, t.folio_rnpdno),
        pro_apellido = COALESCE(s.pro_apellido, t.pro_apellido),
        sdo_apellido = COALESCE(s.sdo_apellido, t.sdo_apellido),
        nomb = COALESCE(s.nomb, t.nomb),
        entidad_nacimiento = COALESCE(s.entidad_nacimiento, t.entidad_nacimiento),
        estado_migratorio = COALESCE(s.estado_migratorio, t.estado_migratorio),
        curp = COALESCE(s.curp, t.curp),
        rfc = COALESCE(s.rfc, t.rfc),
        fecha_ultimo_contacto = COALESCE(s.fecha_ultimo_contacto, t.fecha_ultimo_contacto),
        hora_ultimo_contacto = COALESCE(s.hora_ultimo_contacto, t.hora_ultimo_contacto),
        entidad_visto = COALESCE(s.entidad_visto, t.entidad_visto),
        municipio_visto = COALESCE(s.municipio_visto, t.municipio_visto),
        lugar_ultimo_contacto = COALESCE(s.lugar_ultimo_contacto, t.lugar_ultimo_contacto),
        senas_tatuaje_datos_identificacion = COALESCE(s.senas_tatuaje_datos_identificacion, t.senas_tatuaje_datos_identificacion),
        localizado_o_no_localizado = COALESCE(s.localizado_o_no_localizado, t.localizado_o_no_localizado),
        con_o_sin_vida = COALESCE(s.con_o_sin_vida, t.con_o_sin_vida),
        fecha_localizacion = COALESCE(s.fecha_localizacion, t.fecha_localizacion),
        voluntaria = COALESCE(s.voluntaria, t.voluntaria),
        fue_delito = COALESCE(s.fue_delito, t.fue_delito),
        delito = COALESCE(s.delito, t.delito),
        obs = COALESCE(s.obs, t.obs),
        id_banci_carga_ultima = @IdBanciCarga,
        id_usuario_modificacion = @IdUsuario,
        fecha_modificacion = SYSDATETIME()
    FROM dbo.banci_victima t
    INNER JOIN dbo.banci_delito d ON d.id_banci_delito = t.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion
    INNER JOIN #Victimas s ON s.id_ci = c.id_ci AND s.id_delito = d.id_delito AND s.id_vicf = t.id_vicf
    WHERE c.id_entidad_federativa = @IdEntidad
      AND EXISTS
      (
          SELECT 1
          FROM dbo.banci_historial_cambio h
          WHERE h.id_banci_carga = @IdBanciCarga
            AND h.tipo_registro = N'VICTIMA'
            AND h.tipo_movimiento = N'MODIFICACION'
            AND h.id_registro = t.id_banci_victima
      );

    CREATE TABLE #AltasVictimas(id BIGINT PRIMARY KEY);

    INSERT INTO dbo.banci_victima
    (
        id_banci_delito, id_vicf, id_tv, id_tpm, sexo, genero, pob, disc, fha_nac, edad,
        nacional, no_banci, folio_fotovolante, folio_rnpdno, pro_apellido,
        sdo_apellido, nomb, entidad_nacimiento, estado_migratorio, curp, rfc,
        fecha_ultimo_contacto, hora_ultimo_contacto, entidad_visto,
        municipio_visto, lugar_ultimo_contacto, senas_tatuaje_datos_identificacion,
        localizado_o_no_localizado, con_o_sin_vida, fecha_localizacion,
        voluntaria, fue_delito, delito, obs, id_banci_carga_ultima,
        id_usuario_registro, id_usuario_modificacion
    )
    OUTPUT INSERTED.id_banci_victima INTO #AltasVictimas(id)
    SELECT
        d.id_banci_delito, s.id_vicf, s.id_tv, s.id_tpm, s.sexo, s.genero, s.pob, s.disc,
        s.fha_nac, s.edad, s.nacional,

        /* No_BANCI reservado para asignación posterior SESNSP */
        NULL,

        s.folio_fotovolante, s.folio_rnpdno, s.pro_apellido, s.sdo_apellido,
        s.nomb, s.entidad_nacimiento, s.estado_migratorio, s.curp, s.rfc,
        s.fecha_ultimo_contacto, s.hora_ultimo_contacto, s.entidad_visto,
        s.municipio_visto, s.lugar_ultimo_contacto,
        s.senas_tatuaje_datos_identificacion, s.localizado_o_no_localizado,
        s.con_o_sin_vida, s.fecha_localizacion, s.voluntaria, s.fue_delito,
        s.delito, s.obs, @IdBanciCarga, @IdUsuario, @IdUsuario
    FROM #Victimas s
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = s.id_ci
    INNER JOIN dbo.banci_delito d ON d.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion AND d.id_delito = s.id_delito
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_victima t
        WHERE t.id_banci_delito = d.id_banci_delito
          AND t.id_vicf = s.id_vicf
    );

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci, id_delito,
        id_vicf, no_banci, tipo_movimiento, origen, id_banci_carga, id_usuario
    )
    SELECT
        N'VICTIMA', v.id_banci_victima, c.id_entidad_federativa, c.id_ci,
        d.id_delito, v.id_vicf, NULL, N'ALTA', @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_victima v
    INNER JOIN #AltasVictimas a ON a.id = v.id_banci_victima
    INNER JOIN dbo.banci_delito d ON d.id_banci_delito = v.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion;

    /* ============================================================
       TOTALES Y FINALIZACIÓN
       ============================================================ */

    DECLARE @AltasCarpetas INT = (SELECT COUNT(*) FROM #AltasCarpetas);
    DECLARE @AltasDelitos INT = (SELECT COUNT(*) FROM #AltasDelitos);
    DECLARE @AltasVictimas INT = (SELECT COUNT(*) FROM #AltasVictimas);

    DECLARE @ActualizacionesCarpetas INT =
    (
        SELECT COUNT(DISTINCT id_registro)
        FROM dbo.banci_historial_cambio
        WHERE id_banci_carga = @IdBanciCarga
          AND tipo_registro = N'CARPETA'
          AND tipo_movimiento = N'MODIFICACION'
    );

    DECLARE @ActualizacionesDelitos INT =
    (
        SELECT COUNT(DISTINCT id_registro)
        FROM dbo.banci_historial_cambio
        WHERE id_banci_carga = @IdBanciCarga
          AND tipo_registro = N'DELITO'
          AND tipo_movimiento = N'MODIFICACION'
    );

    DECLARE @ActualizacionesVictimas INT =
    (
        SELECT COUNT(DISTINCT id_registro)
        FROM dbo.banci_historial_cambio
        WHERE id_banci_carga = @IdBanciCarga
          AND tipo_registro = N'VICTIMA'
          AND tipo_movimiento = N'MODIFICACION'
    );

    SET @Altas = @AltasCarpetas + @AltasDelitos + @AltasVictimas;
    SET @Actualizaciones = @ActualizacionesCarpetas + @ActualizacionesDelitos + @ActualizacionesVictimas;

    SET @SinCambio =
          ((SELECT COUNT(*) FROM #Carpetas) - @AltasCarpetas - @ActualizacionesCarpetas)
        + ((SELECT COUNT(*) FROM #Delitos) - @AltasDelitos - @ActualizacionesDelitos)
        + ((SELECT COUNT(*) FROM #Victimas) - @AltasVictimas - @ActualizacionesVictimas);

    UPDATE dbo.banci_carga_tmp_carpeta SET estado = N'VALIDO', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;
    UPDATE dbo.banci_carga_tmp_delito SET estado = N'VALIDO', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;
    UPDATE dbo.banci_carga_tmp_victima SET estado = N'VALIDO', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;

    UPDATE dbo.banci_carga
    SET
        total_altas = @Altas,
        total_actualizaciones = @Actualizaciones,
        total_sin_cambio = @SinCambio,
        estado = CASE WHEN total_advertencias > 0 THEN N'PROCESADO_CON_ADVERTENCIAS' ELSE N'PROCESADO' END,
        fecha_fin_procesamiento = SYSDATETIME(),
        mensaje_error = NULL
    WHERE id_banci_carga = @IdBanciCarga;

    SELECT
        @IdBanciCarga AS id_banci_carga,
        @Altas AS total_altas,
        @Actualizaciones AS total_actualizaciones,
        @SinCambio AS total_sin_cambio;
END;
GO