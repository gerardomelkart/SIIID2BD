-- SOLO DESARROLLO: ajustes de estructura y procedimientos para BANCI v3.
-- Ejecutar DESPUÉS de 01_borrar_registros_banci.sql, con la API detenida.
-- No migra ni conserva datos: requiere las tablas operativas vacías.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF LOWER(DB_NAME()) NOT IN (N'siiid2',N'siiid2_qa') THROW 52600, 'Seleccione la base de desarrollo en la conexión.', 1;
IF @@TRANCOUNT <> 0 THROW 52600, 'Ejecute sin una transacción abierta.', 1;
IF OBJECT_ID(N'dbo.sp_banci_procesar_carga_v2', N'P') IS NULL THROW 52600, 'Falta la estructura BANCI v2.', 1;
BEGIN TRY
BEGIN TRANSACTION;
IF EXISTS (SELECT 1 FROM dbo.banci_historial_cambio)
 OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima)
 OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_delito)
 OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta)
 OR EXISTS (SELECT 1 FROM dbo.banci_carga_observacion)
 OR EXISTS (SELECT 1 FROM dbo.banci_carga_archivo)
 OR EXISTS (SELECT 1 FROM dbo.banci_carga_bitacora_estado)
 OR EXISTS (SELECT 1 FROM dbo.banci_victima)
 OR EXISTS (SELECT 1 FROM dbo.banci_delito)
 OR EXISTS (SELECT 1 FROM dbo.banci_carpeta_investigacion)
 OR EXISTS (SELECT 1 FROM dbo.banci_actualizacion_v2)
 OR EXISTS (SELECT 1 FROM dbo.banci_carga)
 OR EXISTS (SELECT 1 FROM dbo.banci_consecutivo_carpeta)
 THROW 52601, 'Ejecute primero 01_borrar_registros_banci.sql en desarrollo.', 1;
IF COL_LENGTH(N'dbo.banci_victima', N'fub') IS NULL
 EXEC sys.sp_rename N'dbo.banci_victima.folio_rnpdno', N'fub', N'COLUMN';
IF COL_LENGTH(N'dbo.banci_carga_tmp_victima', N'fub') IS NULL
 EXEC sys.sp_rename N'dbo.banci_carga_tmp_victima.folio_rnpdno', N'fub', N'COLUMN';
-- Únicos en todo BANCI, no sólo dentro de su padre o entidad. Incluye inactivos.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.banci_carpeta_investigacion') AND name=N'UX_banci_carpeta_investigacion_id_ci_v3')
 CREATE UNIQUE INDEX UX_banci_carpeta_investigacion_id_ci_v3 ON dbo.banci_carpeta_investigacion(id_ci);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.banci_delito') AND name=N'UX_banci_delito_id_delito_v3')
 CREATE UNIQUE INDEX UX_banci_delito_id_delito_v3 ON dbo.banci_delito(id_delito);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.banci_victima') AND name=N'UX_banci_victima_id_vicf_v3')
 CREATE UNIQUE INDEX UX_banci_victima_id_vicf_v3 ON dbo.banci_victima(id_vicf);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.banci_delito') AND name=N'UX_banci_delito_id_banci_carpeta_investigacion_v3')
 CREATE UNIQUE INDEX UX_banci_delito_id_banci_carpeta_investigacion_v3 ON dbo.banci_delito(id_banci_carpeta_investigacion);
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.banci_victima') AND parent_column_id=COLUMNPROPERTY(OBJECT_ID(N'dbo.banci_victima'),N'localizado_o_no_localizado','ColumnId'))
 ALTER TABLE dbo.banci_victima ADD CONSTRAINT DF_banci_victima_localizacion_v3 DEFAULT (1) FOR localizado_o_no_localizado;

-- Definición completa: sp_banci_procesar_carga
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_procesar_carga
    @IdBanciCarga BIGINT,
    @IdUsuario INT,
    @EmitirResultado BIT = 1
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

    IF @IdEntidad IS NULL THROW 52200, ''No existe la carga BANCI indicada.'', 1;

    -- Sólo se integra dentro de la decisión atómica de sp_banci_confirmar_carga.
    IF @@TRANCOUNT = 0 OR XACT_STATE() <> 1
        THROW 52420, ''La integración BANCI requiere una transacción de confirmación activa.'', 1;

    DECLARE @Recurso NVARCHAR(255) = CONCAT(N''BANCI:ENTIDAD:'', @IdEntidad);
    IF ISNULL(APPLOCK_MODE(N''public'', @Recurso, N''Transaction''), N''NoLock'') <> N''Exclusive''
        THROW 52421, ''La integración BANCI requiere el bloqueo de confirmación por entidad.'', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_carga WITH (UPDLOCK, HOLDLOCK)
        WHERE id_banci_carga = @IdBanciCarga
          AND activo = 1
          AND estado = N''PROCESANDO''
          AND aceptada_usuario = 1
          AND id_usuario_confirmacion = @IdUsuario
          AND id_usuario_carga = @IdUsuario
          AND fecha_confirmacion IS NOT NULL
    )
        THROW 52422, ''La carga BANCI no tiene una aceptación válida para integrar.'', 1;

    -- Verificar que el staging completo sigue disponible antes de tocar datos vivos.
    IF EXISTS
    (
        SELECT 1 FROM dbo.banci_carga c
        WHERE c.id_banci_carga = @IdBanciCarga
          AND
          (
              c.total_errores <> 0 OR c.total_carpetas <= 0 OR c.total_delitos <= 0 OR c.total_victimas <= 0
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N''PENDIENTE'')
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_delito t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N''PENDIENTE'')
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N''PENDIENTE'')
              OR c.total_carpetas <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_carpeta t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N''PENDIENTE'')
              OR c.total_delitos <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_delito t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N''PENDIENTE'')
              OR c.total_victimas <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_victima t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N''PENDIENTE'')
              OR c.total_advertencias <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_observacion o WHERE o.id_banci_carga = c.id_banci_carga AND o.activo = 1 AND o.severidad = N''ADVERTENCIA'')
          )
    )
        THROW 52423, ''Los temporales u observaciones BANCI no coinciden con la carga validada.'', 1;

    -- Alta individual: la comprobación se hace bajo el bloqueo exclusivo de entidad.
    -- Incluye carpetas inactivas porque la llave única también las protege.
    IF @Modalidad = N''FORMULARIO'' AND
    (
        (SELECT COUNT(*) FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1) <> 1
        OR EXISTS
        (
            SELECT 1 FROM dbo.banci_carga_tmp_carpeta s
            INNER JOIN dbo.banci_carpeta_investigacion c WITH (UPDLOCK, HOLDLOCK)
                ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = LTRIM(RTRIM(s.id_ci))
            WHERE s.id_banci_carga = @IdBanciCarga AND s.activo = 1
        )
    ) THROW 52424, ''La carpeta ya existe o el formulario no contiene exactamente una carpeta nueva.'', 1;

    SET @Origen =
        CASE
            WHEN @Modalidad = N''FORMULARIO'' THEN N''FORMULARIO''
            WHEN @Modalidad = N''COMPLEMENTO_CONSOLIDADO'' THEN N''COMPLEMENTO_CONSOLIDADO''
            ELSE N''CARGA_MASIVA''
        END;

    /* ============================================================
       CARPETAS
       ============================================================ */

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
        N''CARPETA'',
        t.id_banci_carpeta_investigacion,
        t.id_entidad_federativa,
        t.id_ci,
        NULL,
        NULL,
        NULL,
        N''MODIFICACION'',
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
        (N''ntra_ci'', CONVERT(NVARCHAR(MAX), t.ntra_ci), CONVERT(NVARCHAR(MAX), COALESCE(s.ntra_ci, t.ntra_ci))),
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
        (N''dic'', CONVERT(NVARCHAR(MAX), t.dic), CONVERT(NVARCHAR(MAX), COALESCE(s.dic, t.dic)))
    ) v(campo, valor_anterior, valor_nuevo)
    WHERE t.activo = 1
      AND ISNULL(v.valor_anterior, N''§NULL§'') <> ISNULL(v.valor_nuevo, N''§NULL§'');

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
          AND h.tipo_registro = N''CARPETA''
          AND h.tipo_movimiento = N''MODIFICACION''
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
        N''CARPETA'', t.id_banci_carpeta_investigacion, t.id_entidad_federativa,
        t.id_ci, N''ALTA'', @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_carpeta_investigacion t
    INNER JOIN #AltasCarpetas a ON a.id = t.id_banci_carpeta_investigacion;

    /* ============================================================
       DELITOS
       ============================================================ */

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

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci, id_delito,
        tipo_movimiento, campo, valor_anterior, valor_nuevo, origen,
        id_banci_carga, id_usuario
    )
    SELECT
        N''DELITO'', t.id_banci_delito, c.id_entidad_federativa, c.id_ci, t.id_delito,
        N''MODIFICACION'', v.campo, v.valor_anterior, v.valor_nuevo,
        @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_delito t
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = t.id_banci_carpeta_investigacion
    INNER JOIN #Delitos s ON s.id_ci = c.id_ci AND s.id_delito = t.id_delito
    CROSS APPLY
    (
        VALUES
        (N''dto'', CONVERT(NVARCHAR(MAX), t.dto), CONVERT(NVARCHAR(MAX), COALESCE(s.dto, t.dto))),
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
        (N''dom_hchos'', t.dom_hchos, COALESCE(s.dom_hchos, t.dom_hchos))
    ) v(campo, valor_anterior, valor_nuevo)
    WHERE c.id_entidad_federativa = @IdEntidad
      AND t.activo = 1
      AND ISNULL(v.valor_anterior, N''§NULL§'') <> ISNULL(v.valor_nuevo, N''§NULL§'');

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
            AND h.tipo_registro = N''DELITO''
            AND h.tipo_movimiento = N''MODIFICACION''
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
        N''DELITO'', d.id_banci_delito, c.id_entidad_federativa, c.id_ci,
        d.id_delito, N''ALTA'', @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_delito d
    INNER JOIN #AltasDelitos a ON a.id = d.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion;

    /* ============================================================
       VÍCTIMAS
       No_BANCI se ignora intencionalmente.
       ============================================================ */

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
        fub = NULLIF(LTRIM(RTRIM(v.fub)), N''''),
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

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci, id_delito,
        id_vicf, no_banci, tipo_movimiento, campo, valor_anterior, valor_nuevo,
        origen, id_banci_carga, id_usuario
    )
    SELECT
        N''VICTIMA'', t.id_banci_victima, c.id_entidad_federativa, c.id_ci,
        d.id_delito, t.id_vicf, t.no_banci, N''MODIFICACION'',
        x.campo, x.valor_anterior, x.valor_nuevo, @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_victima t
    INNER JOIN dbo.banci_delito d ON d.id_banci_delito = t.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion
    INNER JOIN #Victimas s ON s.id_ci = c.id_ci AND s.id_delito = d.id_delito AND s.id_vicf = t.id_vicf
    CROSS APPLY
    (
        VALUES
        (N''id_tv'', CONVERT(NVARCHAR(MAX), t.id_tv), CONVERT(NVARCHAR(MAX), COALESCE(s.id_tv, t.id_tv))),
        (N''id_tpm'', CONVERT(NVARCHAR(MAX), t.id_tpm), CONVERT(NVARCHAR(MAX), COALESCE(s.id_tpm, t.id_tpm))),
        (N''sexo'', CONVERT(NVARCHAR(MAX), t.sexo), CONVERT(NVARCHAR(MAX), COALESCE(s.sexo, t.sexo))),
        (N''genero'', CONVERT(NVARCHAR(MAX), t.genero), CONVERT(NVARCHAR(MAX), COALESCE(s.genero, t.genero))),
        (N''pob'', CONVERT(NVARCHAR(MAX), t.pob), CONVERT(NVARCHAR(MAX), COALESCE(s.pob, t.pob))),
        (N''disc'', CONVERT(NVARCHAR(MAX), t.disc), CONVERT(NVARCHAR(MAX), COALESCE(s.disc, t.disc))),
        (N''fha_nac'', CONVERT(NVARCHAR(MAX), t.fha_nac, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fha_nac, t.fha_nac), 23)),
        (N''edad'', CONVERT(NVARCHAR(MAX), t.edad), CONVERT(NVARCHAR(MAX), COALESCE(s.edad, t.edad))),
        (N''nacional'', t.nacional, COALESCE(s.nacional, t.nacional)),
        (N''folio_fotovolante'', t.folio_fotovolante, COALESCE(s.folio_fotovolante, t.folio_fotovolante)),
        (N''fub'', t.fub, COALESCE(s.fub, t.fub)),
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
        (N''obs'', t.obs, COALESCE(s.obs, t.obs))
    ) x(campo, valor_anterior, valor_nuevo)
    WHERE c.id_entidad_federativa = @IdEntidad
      AND t.activo = 1
      AND ISNULL(x.valor_anterior, N''§NULL§'') <> ISNULL(x.valor_nuevo, N''§NULL§'');

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
        fub = COALESCE(s.fub, t.fub),
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
            AND h.tipo_registro = N''VICTIMA''
            AND h.tipo_movimiento = N''MODIFICACION''
            AND h.id_registro = t.id_banci_victima
      );

    CREATE TABLE #AltasVictimas(id BIGINT PRIMARY KEY);

    INSERT INTO dbo.banci_victima
    (
        id_banci_delito, id_vicf, id_tv, id_tpm, sexo, genero, pob, disc, fha_nac, edad,
        nacional, no_banci, folio_fotovolante, fub, pro_apellido,
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

        s.folio_fotovolante, s.fub, s.pro_apellido, s.sdo_apellido,
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
        N''VICTIMA'', v.id_banci_victima, c.id_entidad_federativa, c.id_ci,
        d.id_delito, v.id_vicf, NULL, N''ALTA'', @Origen, @IdBanciCarga, @IdUsuario
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
          AND tipo_registro = N''CARPETA''
          AND tipo_movimiento = N''MODIFICACION''
    );

    DECLARE @ActualizacionesDelitos INT =
    (
        SELECT COUNT(DISTINCT id_registro)
        FROM dbo.banci_historial_cambio
        WHERE id_banci_carga = @IdBanciCarga
          AND tipo_registro = N''DELITO''
          AND tipo_movimiento = N''MODIFICACION''
    );

    DECLARE @ActualizacionesVictimas INT =
    (
        SELECT COUNT(DISTINCT id_registro)
        FROM dbo.banci_historial_cambio
        WHERE id_banci_carga = @IdBanciCarga
          AND tipo_registro = N''VICTIMA''
          AND tipo_movimiento = N''MODIFICACION''
    );

    SET @Altas = @AltasCarpetas + @AltasDelitos + @AltasVictimas;
    SET @Actualizaciones = @ActualizacionesCarpetas + @ActualizacionesDelitos + @ActualizacionesVictimas;

    SET @SinCambio =
          ((SELECT COUNT(*) FROM #Carpetas) - @AltasCarpetas - @ActualizacionesCarpetas)
        + ((SELECT COUNT(*) FROM #Delitos) - @AltasDelitos - @ActualizacionesDelitos)
        + ((SELECT COUNT(*) FROM #Victimas) - @AltasVictimas - @ActualizacionesVictimas);

    UPDATE dbo.banci_carga_tmp_carpeta SET estado = N''VALIDO'', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;
    UPDATE dbo.banci_carga_tmp_delito SET estado = N''VALIDO'', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;
    UPDATE dbo.banci_carga_tmp_victima SET estado = N''VALIDO'', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;

    UPDATE dbo.banci_carga
    SET
        total_altas = @Altas,
        total_actualizaciones = @Actualizaciones,
        total_sin_cambio = @SinCambio,
        estado = CASE WHEN total_advertencias > 0 THEN N''PROCESADO_CON_ADVERTENCIAS'' ELSE N''PROCESADO'' END,
        fecha_fin_procesamiento = SYSDATETIME(),
        mensaje_error = NULL
    WHERE id_banci_carga = @IdBanciCarga;

    IF @EmitirResultado = 1
    SELECT
        @IdBanciCarga AS id_banci_carga,
        @Altas AS total_altas,
        @Actualizaciones AS total_actualizaciones,
        @SinCambio AS total_sin_cambio;
END;';

-- Definición completa: sp_banci_vista_previa
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
        fub = NULLIF(LTRIM(RTRIM(v.fub)), N''''),
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
        (N''fub'', t.fub, COALESCE(s.fub, t.fub)),
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

-- Definición completa: banci_vw_victimas_v2
EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_victimas_v2 AS
SELECT c.id_entidad_federativa, c.no_banci, c.id_ci, c.ntra_ci, c.fha_de_ini,
    c.id_banci_carpeta_investigacion, d.id_banci_delito, d.id_delito, v.id_banci_victima, v.id_vicf,
    v.id_tv, v.id_tpm, v.sexo, v.genero, v.pob, v.disc, v.fha_nac, v.edad, v.nacional,
    v.fub, v.pro_apellido, v.sdo_apellido, v.nomb, v.entidad_nacimiento, v.estado_migratorio, v.curp, v.rfc,
    v.localizado_o_no_localizado, v.con_o_sin_vida, v.fecha_localizacion, v.voluntaria_o_fue_delito, v.delito, v.acciones_busqueda, v.obs,
    v.version_banci, v.fecha_modificacion, d.fha_de_hchos
FROM dbo.banci_carpeta_investigacion c JOIN dbo.banci_delito d ON d.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion
JOIN dbo.banci_victima v ON v.id_banci_delito = d.id_banci_delito WHERE c.activo = 1 AND d.activo = 1 AND v.activo = 1;';

-- Definición completa: sp_banci_procesar_carga_v2
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_procesar_carga_v2
    @IdBanciCarga BIGINT,
    @IdUsuario INT,
    @EmitirResultado BIT = 1
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

    IF @IdEntidad IS NULL THROW 52200, ''No existe la carga BANCI indicada.'', 1;

    -- Sólo se integra dentro de la decisión atómica de sp_banci_confirmar_carga_v2.
    IF @@TRANCOUNT = 0 OR XACT_STATE() <> 1
        THROW 52420, ''La integración BANCI requiere una transacción de confirmación activa.'', 1;

    DECLARE @Recurso NVARCHAR(255) = CONCAT(N''BANCI:ENTIDAD:'', @IdEntidad);
    IF ISNULL(APPLOCK_MODE(N''public'', @Recurso, N''Transaction''), N''NoLock'') <> N''Exclusive''
        THROW 52421, ''La integración BANCI requiere el bloqueo de confirmación por entidad.'', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_carga WITH (UPDLOCK, HOLDLOCK)
        WHERE id_banci_carga = @IdBanciCarga
          AND activo = 1
          AND estado = N''PROCESANDO''
          AND aceptada_usuario = 1
          AND id_usuario_confirmacion = @IdUsuario
          AND id_usuario_carga = @IdUsuario
          AND fecha_confirmacion IS NOT NULL
    )
        THROW 52422, ''La carga BANCI no tiene una aceptación válida para integrar.'', 1;

    -- Verificar que el staging completo sigue disponible antes de tocar datos vivos.
    IF EXISTS
    (
        SELECT 1 FROM dbo.banci_carga c
        WHERE c.id_banci_carga = @IdBanciCarga
          AND
          (
              c.total_errores <> 0 OR c.total_carpetas <= 0 OR c.total_delitos <= 0 OR c.total_victimas <= 0
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N''PENDIENTE'')
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_delito t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N''PENDIENTE'')
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N''PENDIENTE'')
              OR c.total_carpetas <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_carpeta t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N''PENDIENTE'')
              OR c.total_delitos <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_delito t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N''PENDIENTE'')
              OR c.total_victimas <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_victima t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N''PENDIENTE'')
              OR c.total_advertencias <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_observacion o WHERE o.id_banci_carga = c.id_banci_carga AND o.activo = 1 AND o.severidad = N''ADVERTENCIA'')
          )
    )
        THROW 52423, ''Los temporales u observaciones BANCI no coinciden con la carga validada.'', 1;

    -- Alta inicial de cualquier modalidad: la comprobación se hace bajo el bloqueo exclusivo de entidad.
    -- Incluye carpetas inactivas porque la llave única también las protege.
    IF
    (
        (@Modalidad = N''FORMULARIO'' AND (SELECT COUNT(*) FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1) <> 1)
        OR EXISTS
        (
            SELECT 1 FROM dbo.banci_carga_tmp_carpeta s
            INNER JOIN dbo.banci_carpeta_investigacion c WITH (UPDLOCK, HOLDLOCK)
                ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = LTRIM(RTRIM(s.id_ci))
            WHERE s.id_banci_carga = @IdBanciCarga AND s.activo = 1
        )
    ) THROW 52424, ''La carga inicial sólo admite carpetas nuevas. Hay una carpeta ya registrada o el formulario no contiene exactamente una carpeta.'', 1;



    -- Se comprueba en vista previa y de nuevo al integrar bajo bloqueo de entidad.
    DECLARE @HoyBanci DATE = CONVERT(DATE, SYSUTCDATETIME() AT TIME ZONE ''UTC'' AT TIME ZONE ''Central Standard Time (Mexico)'');
    DECLARE @MesBanci DATE = DATEFROMPARTS(YEAR(@HoyBanci), MONTH(@HoyBanci), 1);
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga=@IdBanciCarga AND activo=1
        AND (TRY_CONVERT(DATE,fha_de_ini,23) IS NULL OR TRY_CONVERT(DATE,fha_de_ini,23)<DATEADD(MONTH,-1,@MesBanci) OR TRY_CONVERT(DATE,fha_de_ini,23)>=DATEADD(MONTH,1,@MesBanci)))
        THROW 52610, ''La fecha de inicio debe pertenecer al mes en curso o al anterior. Vuelva a validar si cambió el periodo.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga=@IdBanciCarga AND activo=1 GROUP BY LTRIM(RTRIM(ntra_ci)) HAVING COUNT_BIG(*)>1)
        THROW 52611, ''No repita NTRA_CI en Carpetas.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta c WHERE c.id_banci_carga=@IdBanciCarga AND c.activo=1
        AND (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_delito d WHERE d.id_banci_carga=@IdBanciCarga AND d.activo=1 AND d.id_ci=c.id_ci)<>1)
        THROW 52612, ''Cada carpeta requiere exactamente un delito.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta s JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa=@IdEntidad AND LTRIM(RTRIM(c.ntra_ci))=LTRIM(RTRIM(s.ntra_ci)) WHERE s.id_banci_carga=@IdBanciCarga AND s.activo=1)
        THROW 52424, ''La carpeta NTRA_CI ya está registrada en la entidad. Use Actualización de víctimas.'', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga AND version_formato = 3)
        THROW 52510, ''Esta operación requiere una carga del formato BANCI v3.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(ntra_ci)), N'''') IS NULL)
        THROW 52511, ''NTRA_CI es obligatorio.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(fub)), N'''') IS NULL)
        THROW 52512, ''FUB es obligatorio para cada víctima.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta s LEFT JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = LTRIM(RTRIM(s.id_ci))
        WHERE s.id_banci_carga = @IdBanciCarga AND s.activo = 1 AND NULLIF(LTRIM(RTRIM(s.no_banci)), N'''') IS NOT NULL AND (c.no_banci IS NULL OR c.no_banci <> LTRIM(RTRIM(s.no_banci))))
        THROW 52513, ''NO_BANCI lo asigna el sistema; el informado no corresponde a la carpeta.'', 1;

    SET @Origen =
        CASE
            WHEN @Modalidad = N''FORMULARIO'' THEN N''FORMULARIO''
            WHEN @Modalidad = N''COMPLEMENTO_CONSOLIDADO'' THEN N''COMPLEMENTO_CONSOLIDADO''
            ELSE N''CARGA_MASIVA''
        END;

    /* ============================================================
       CARPETAS
       ============================================================ */

    SELECT
        id_entidad_federativa = @IdEntidad,
        entidad = NULLIF(LTRIM(RTRIM(entidad)), N''''),
        id_ci = NULLIF(LTRIM(RTRIM(id_ci)), N''''),
        ntra_ci = NULLIF(LTRIM(RTRIM(ntra_ci)), N''''),
        fha_de_ini = COALESCE(TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''''), 23), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''''), 103), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''''), 112), TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(fha_de_ini)), N''''))),
        hra_de_ini = TRY_CONVERT(TIME(0), NULLIF(LTRIM(RTRIM(hra_de_ini)), N'''')),
        rmen_de_hchos = NULLIF(LTRIM(RTRIM(rmen_de_hchos)), N''''),
        ord_apreh = CAST(NULL AS INT),
        fgran = CAST(NULL AS INT),
        ctaon = CAST(NULL AS INT),
        td_v_ap = CAST(NULL AS INT),
        proc_abrev = CAST(NULL AS INT),
        juc_oral = CAST(NULL AS INT),
        td_sen_con = CAST(NULL AS INT),
        no_ejer_acc_pnal = CAST(NULL AS INT),
        otra = CAST(NULL AS INT),
        dic = CAST(NULL AS TINYINT)
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
        N''CARPETA'',
        t.id_banci_carpeta_investigacion,
        t.id_entidad_federativa,
        t.id_ci,
        NULL,
        NULL,
        NULL,
        N''MODIFICACION'',
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
        (N''ntra_ci'', CONVERT(NVARCHAR(MAX), t.ntra_ci), CONVERT(NVARCHAR(MAX), COALESCE(s.ntra_ci, t.ntra_ci))),
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
        (N''dic'', CONVERT(NVARCHAR(MAX), t.dic), CONVERT(NVARCHAR(MAX), COALESCE(s.dic, t.dic)))
    ) v(campo, valor_anterior, valor_nuevo)
    WHERE t.activo = 1
      AND ISNULL(v.valor_anterior, N''§NULL§'') <> ISNULL(v.valor_nuevo, N''§NULL§'');

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
          AND h.tipo_registro = N''CARPETA''
          AND h.tipo_movimiento = N''MODIFICACION''
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
        N''CARPETA'', t.id_banci_carpeta_investigacion, t.id_entidad_federativa,
        t.id_ci, N''ALTA'', @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_carpeta_investigacion t
    INNER JOIN #AltasCarpetas a ON a.id = t.id_banci_carpeta_investigacion;

    /* ============================================================
       DELITOS
       ============================================================ */

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

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci, id_delito,
        tipo_movimiento, campo, valor_anterior, valor_nuevo, origen,
        id_banci_carga, id_usuario
    )
    SELECT
        N''DELITO'', t.id_banci_delito, c.id_entidad_federativa, c.id_ci, t.id_delito,
        N''MODIFICACION'', v.campo, v.valor_anterior, v.valor_nuevo,
        @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_delito t
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = t.id_banci_carpeta_investigacion
    INNER JOIN #Delitos s ON s.id_ci = c.id_ci AND s.id_delito = t.id_delito
    CROSS APPLY
    (
        VALUES
        (N''dto'', CONVERT(NVARCHAR(MAX), t.dto), CONVERT(NVARCHAR(MAX), COALESCE(s.dto, t.dto))),
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
        (N''dom_hchos'', t.dom_hchos, COALESCE(s.dom_hchos, t.dom_hchos))
    ) v(campo, valor_anterior, valor_nuevo)
    WHERE c.id_entidad_federativa = @IdEntidad
      AND t.activo = 1
      AND ISNULL(v.valor_anterior, N''§NULL§'') <> ISNULL(v.valor_nuevo, N''§NULL§'');

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
            AND h.tipo_registro = N''DELITO''
            AND h.tipo_movimiento = N''MODIFICACION''
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
        N''DELITO'', d.id_banci_delito, c.id_entidad_federativa, c.id_ci,
        d.id_delito, N''ALTA'', @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_delito d
    INNER JOIN #AltasDelitos a ON a.id = d.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion;

    /* ============================================================
       VÍCTIMAS
       No_BANCI se ignora intencionalmente.
       ============================================================ */

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
        folio_fotovolante = CAST(NULL AS NVARCHAR(MAX)),
        fub = NULLIF(LTRIM(RTRIM(v.fub)), N''''),
        pro_apellido = NULLIF(LTRIM(RTRIM(v.pro_apellido)), N''''),
        sdo_apellido = NULLIF(LTRIM(RTRIM(v.sdo_apellido)), N''''),
        nomb = NULLIF(LTRIM(RTRIM(v.nomb)), N''''),
        entidad_nacimiento = NULLIF(LTRIM(RTRIM(v.entidad_nacimiento)), N''''),
        estado_migratorio = NULLIF(LTRIM(RTRIM(v.estado_migratorio)), N''''),
        curp = NULLIF(LTRIM(RTRIM(v.curp)), N''''),
        rfc = NULLIF(LTRIM(RTRIM(v.rfc)), N''''),
        fecha_ultimo_contacto = CAST(NULL AS DATE),
        hora_ultimo_contacto = CAST(NULL AS TIME(0)),
        entidad_visto = CAST(NULL AS NVARCHAR(MAX)),
        municipio_visto = CAST(NULL AS NVARCHAR(MAX)),
        lugar_ultimo_contacto = CAST(NULL AS NVARCHAR(MAX)),
        senas_tatuaje_datos_identificacion = CAST(NULL AS NVARCHAR(MAX)),
        localizado_o_no_localizado = CAST(1 AS TINYINT),
        con_o_sin_vida = CAST(NULL AS TINYINT),
        fecha_localizacion = CAST(NULL AS DATE),
        voluntaria = CAST(NULL AS TINYINT),
        fue_delito = CAST(NULL AS TINYINT),
        delito = CAST(NULL AS NVARCHAR(MAX)),
        obs = CAST(NULL AS NVARCHAR(MAX))
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

    INSERT INTO dbo.banci_historial_cambio
    (
        tipo_registro, id_registro, id_entidad_federativa, id_ci, id_delito,
        id_vicf, no_banci, tipo_movimiento, campo, valor_anterior, valor_nuevo,
        origen, id_banci_carga, id_usuario
    )
    SELECT
        N''VICTIMA'', t.id_banci_victima, c.id_entidad_federativa, c.id_ci,
        d.id_delito, t.id_vicf, t.no_banci, N''MODIFICACION'',
        x.campo, x.valor_anterior, x.valor_nuevo, @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_victima t
    INNER JOIN dbo.banci_delito d ON d.id_banci_delito = t.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion
    INNER JOIN #Victimas s ON s.id_ci = c.id_ci AND s.id_delito = d.id_delito AND s.id_vicf = t.id_vicf
    CROSS APPLY
    (
        VALUES
        (N''id_tv'', CONVERT(NVARCHAR(MAX), t.id_tv), CONVERT(NVARCHAR(MAX), COALESCE(s.id_tv, t.id_tv))),
        (N''id_tpm'', CONVERT(NVARCHAR(MAX), t.id_tpm), CONVERT(NVARCHAR(MAX), COALESCE(s.id_tpm, t.id_tpm))),
        (N''sexo'', CONVERT(NVARCHAR(MAX), t.sexo), CONVERT(NVARCHAR(MAX), COALESCE(s.sexo, t.sexo))),
        (N''genero'', CONVERT(NVARCHAR(MAX), t.genero), CONVERT(NVARCHAR(MAX), COALESCE(s.genero, t.genero))),
        (N''pob'', CONVERT(NVARCHAR(MAX), t.pob), CONVERT(NVARCHAR(MAX), COALESCE(s.pob, t.pob))),
        (N''disc'', CONVERT(NVARCHAR(MAX), t.disc), CONVERT(NVARCHAR(MAX), COALESCE(s.disc, t.disc))),
        (N''fha_nac'', CONVERT(NVARCHAR(MAX), t.fha_nac, 23), CONVERT(NVARCHAR(MAX), COALESCE(s.fha_nac, t.fha_nac), 23)),
        (N''edad'', CONVERT(NVARCHAR(MAX), t.edad), CONVERT(NVARCHAR(MAX), COALESCE(s.edad, t.edad))),
        (N''nacional'', t.nacional, COALESCE(s.nacional, t.nacional)),
        (N''folio_fotovolante'', t.folio_fotovolante, COALESCE(s.folio_fotovolante, t.folio_fotovolante)),
        (N''fub'', t.fub, COALESCE(s.fub, t.fub)),
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
        (N''obs'', t.obs, COALESCE(s.obs, t.obs))
    ) x(campo, valor_anterior, valor_nuevo)
    WHERE c.id_entidad_federativa = @IdEntidad
      AND t.activo = 1
      AND ISNULL(x.valor_anterior, N''§NULL§'') <> ISNULL(x.valor_nuevo, N''§NULL§'');

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
        fub = COALESCE(s.fub, t.fub),
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
            AND h.tipo_registro = N''VICTIMA''
            AND h.tipo_movimiento = N''MODIFICACION''
            AND h.id_registro = t.id_banci_victima
      );

    CREATE TABLE #AltasVictimas(id BIGINT PRIMARY KEY);

    INSERT INTO dbo.banci_victima
    (
        id_banci_delito, id_vicf, id_tv, id_tpm, sexo, genero, pob, disc, fha_nac, edad,
        nacional, no_banci, folio_fotovolante, fub, pro_apellido,
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

        s.folio_fotovolante, s.fub, s.pro_apellido, s.sdo_apellido,
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
        N''VICTIMA'', v.id_banci_victima, c.id_entidad_federativa, c.id_ci,
        d.id_delito, v.id_vicf, NULL, N''ALTA'', @Origen, @IdBanciCarga, @IdUsuario
    FROM dbo.banci_victima v
    INNER JOIN #AltasVictimas a ON a.id = v.id_banci_victima
    INNER JOIN dbo.banci_delito d ON d.id_banci_delito = v.id_banci_delito
    INNER JOIN dbo.banci_carpeta_investigacion c ON c.id_banci_carpeta_investigacion = d.id_banci_carpeta_investigacion;

    /* ============================================================
       TOTALES Y FINALIZACIÓN
       ============================================================ */

    EXEC dbo.sp_banci_asignar_folios_v2 @IdEntidad;

    DECLARE @AltasCarpetas INT = (SELECT COUNT(*) FROM #AltasCarpetas);
    DECLARE @AltasDelitos INT = (SELECT COUNT(*) FROM #AltasDelitos);
    DECLARE @AltasVictimas INT = (SELECT COUNT(*) FROM #AltasVictimas);

    DECLARE @ActualizacionesCarpetas INT =
    (
        SELECT COUNT(DISTINCT id_registro)
        FROM dbo.banci_historial_cambio
        WHERE id_banci_carga = @IdBanciCarga
          AND tipo_registro = N''CARPETA''
          AND tipo_movimiento = N''MODIFICACION''
    );

    DECLARE @ActualizacionesDelitos INT =
    (
        SELECT COUNT(DISTINCT id_registro)
        FROM dbo.banci_historial_cambio
        WHERE id_banci_carga = @IdBanciCarga
          AND tipo_registro = N''DELITO''
          AND tipo_movimiento = N''MODIFICACION''
    );

    DECLARE @ActualizacionesVictimas INT =
    (
        SELECT COUNT(DISTINCT id_registro)
        FROM dbo.banci_historial_cambio
        WHERE id_banci_carga = @IdBanciCarga
          AND tipo_registro = N''VICTIMA''
          AND tipo_movimiento = N''MODIFICACION''
    );

    SET @Altas = @AltasCarpetas + @AltasDelitos + @AltasVictimas;
    SET @Actualizaciones = @ActualizacionesCarpetas + @ActualizacionesDelitos + @ActualizacionesVictimas;

    SET @SinCambio =
          ((SELECT COUNT(*) FROM #Carpetas) - @AltasCarpetas - @ActualizacionesCarpetas)
        + ((SELECT COUNT(*) FROM #Delitos) - @AltasDelitos - @ActualizacionesDelitos)
        + ((SELECT COUNT(*) FROM #Victimas) - @AltasVictimas - @ActualizacionesVictimas);

    UPDATE dbo.banci_carga_tmp_carpeta SET estado = N''VALIDO'', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;
    UPDATE dbo.banci_carga_tmp_delito SET estado = N''VALIDO'', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;
    UPDATE dbo.banci_carga_tmp_victima SET estado = N''VALIDO'', fecha_procesamiento = SYSDATETIME() WHERE id_banci_carga = @IdBanciCarga;

    UPDATE dbo.banci_carga
    SET
        total_altas = @Altas,
        total_actualizaciones = @Actualizaciones,
        total_sin_cambio = @SinCambio,
        estado = CASE WHEN total_advertencias > 0 THEN N''PROCESADO_CON_ADVERTENCIAS'' ELSE N''PROCESADO'' END,
        fecha_fin_procesamiento = SYSDATETIME(),
        mensaje_error = NULL
    WHERE id_banci_carga = @IdBanciCarga;

    IF @EmitirResultado = 1
    SELECT
        @IdBanciCarga AS id_banci_carga,
        @Altas AS total_altas,
        @Actualizaciones AS total_actualizaciones,
        @SinCambio AS total_sin_cambio;
END;';

-- Definición completa: sp_banci_vista_previa_v2
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_vista_previa_v2
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
    IF
    (
        (@Modalidad = N''FORMULARIO'' AND (SELECT COUNT(*) FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1) <> 1)
        OR EXISTS
        (
            SELECT 1 FROM dbo.banci_carga_tmp_carpeta s
            INNER JOIN dbo.banci_carpeta_investigacion c WITH (HOLDLOCK)
                ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = LTRIM(RTRIM(s.id_ci))
            WHERE s.id_banci_carga = @IdBanciCarga AND s.activo = 1
        )
    ) THROW 52424, ''La carga inicial sólo admite carpetas nuevas. Hay una carpeta ya registrada o el formulario no contiene exactamente una carpeta.'', 1;


    -- Se comprueba en vista previa y de nuevo al integrar bajo bloqueo de entidad.
    DECLARE @HoyBanci DATE = CONVERT(DATE, SYSUTCDATETIME() AT TIME ZONE ''UTC'' AT TIME ZONE ''Central Standard Time (Mexico)'');
    DECLARE @MesBanci DATE = DATEFROMPARTS(YEAR(@HoyBanci), MONTH(@HoyBanci), 1);
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga=@IdBanciCarga AND activo=1
        AND (TRY_CONVERT(DATE,fha_de_ini,23) IS NULL OR TRY_CONVERT(DATE,fha_de_ini,23)<DATEADD(MONTH,-1,@MesBanci) OR TRY_CONVERT(DATE,fha_de_ini,23)>=DATEADD(MONTH,1,@MesBanci)))
        THROW 52610, ''La fecha de inicio debe pertenecer al mes en curso o al anterior. Vuelva a validar si cambió el periodo.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga=@IdBanciCarga AND activo=1 GROUP BY LTRIM(RTRIM(ntra_ci)) HAVING COUNT_BIG(*)>1)
        THROW 52611, ''No repita NTRA_CI en Carpetas.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta c WHERE c.id_banci_carga=@IdBanciCarga AND c.activo=1
        AND (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_delito d WHERE d.id_banci_carga=@IdBanciCarga AND d.activo=1 AND d.id_ci=c.id_ci)<>1)
        THROW 52612, ''Cada carpeta requiere exactamente un delito.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta s JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa=@IdEntidad AND LTRIM(RTRIM(c.ntra_ci))=LTRIM(RTRIM(s.ntra_ci)) WHERE s.id_banci_carga=@IdBanciCarga AND s.activo=1)
        THROW 52424, ''La carpeta NTRA_CI ya está registrada en la entidad. Use Actualización de víctimas.'', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga AND version_formato = 3)
        THROW 52510, ''Esta operación requiere una carga del formato BANCI v3.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(ntra_ci)), N'''') IS NULL)
        THROW 52511, ''NTRA_CI es obligatorio.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(fub)), N'''') IS NULL)
        THROW 52512, ''FUB es obligatorio para cada víctima.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta s LEFT JOIN dbo.banci_carpeta_investigacion c ON c.id_entidad_federativa = @IdEntidad AND c.id_ci = LTRIM(RTRIM(s.id_ci))
        WHERE s.id_banci_carga = @IdBanciCarga AND s.activo = 1 AND NULLIF(LTRIM(RTRIM(s.no_banci)), N'''') IS NOT NULL AND (c.no_banci IS NULL OR c.no_banci <> LTRIM(RTRIM(s.no_banci))))
        THROW 52513, ''NO_BANCI lo asigna el sistema; el informado no corresponde a la carpeta.'', 1;

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
        ord_apreh = CAST(NULL AS INT),
        fgran = CAST(NULL AS INT),
        ctaon = CAST(NULL AS INT),
        td_v_ap = CAST(NULL AS INT),
        proc_abrev = CAST(NULL AS INT),
        juc_oral = CAST(NULL AS INT),
        td_sen_con = CAST(NULL AS INT),
        no_ejer_acc_pnal = CAST(NULL AS INT),
        otra = CAST(NULL AS INT),
        dic = CAST(NULL AS TINYINT)
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
        folio_fotovolante = CAST(NULL AS NVARCHAR(MAX)),
        fub = NULLIF(LTRIM(RTRIM(v.fub)), N''''),
        pro_apellido = NULLIF(LTRIM(RTRIM(v.pro_apellido)), N''''),
        sdo_apellido = NULLIF(LTRIM(RTRIM(v.sdo_apellido)), N''''),
        nomb = NULLIF(LTRIM(RTRIM(v.nomb)), N''''),
        entidad_nacimiento = NULLIF(LTRIM(RTRIM(v.entidad_nacimiento)), N''''),
        estado_migratorio = NULLIF(LTRIM(RTRIM(v.estado_migratorio)), N''''),
        curp = NULLIF(LTRIM(RTRIM(v.curp)), N''''),
        rfc = NULLIF(LTRIM(RTRIM(v.rfc)), N''''),
        fecha_ultimo_contacto = CAST(NULL AS DATE),
        hora_ultimo_contacto = CAST(NULL AS TIME(0)),
        entidad_visto = CAST(NULL AS NVARCHAR(MAX)),
        municipio_visto = CAST(NULL AS NVARCHAR(MAX)),
        lugar_ultimo_contacto = CAST(NULL AS NVARCHAR(MAX)),
        senas_tatuaje_datos_identificacion = CAST(NULL AS NVARCHAR(MAX)),
        localizado_o_no_localizado = CAST(1 AS TINYINT),
        con_o_sin_vida = CAST(NULL AS TINYINT),
        fecha_localizacion = CAST(NULL AS DATE),
        voluntaria = CAST(NULL AS TINYINT),
        fue_delito = CAST(NULL AS TINYINT),
        delito = CAST(NULL AS NVARCHAR(MAX)),
        obs = CAST(NULL AS NVARCHAR(MAX))
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
        (N''fub'', t.fub, COALESCE(s.fub, t.fub)),
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

-- Definición completa: sp_banci_calcular_actualizacion_v2
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_calcular_actualizacion_v2
    @CodigoReferencia UNIQUEIDENTIFIER, @IdUsuario INT,
    @Huella VARCHAR(64) OUTPUT, @DatosAplicar NVARCHAR(MAX) OUTPUT, @Cambios NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 OR XACT_STATE() <> 1 THROW 52520, ''La vista previa requiere una transacción activa.'', 1;
    DECLARE @IdEntidad TINYINT, @Datos NVARCHAR(MAX), @Advertencias NVARCHAR(MAX), @Estado NVARCHAR(20);
    SELECT @IdEntidad = id_entidad_federativa, @Datos = datos_json, @Advertencias = advertencias_json, @Estado = estado
    FROM dbo.banci_actualizacion_v2 WITH (HOLDLOCK) WHERE codigo_referencia = @CodigoReferencia AND id_usuario = @IdUsuario;
    IF @IdEntidad IS NULL OR @Estado <> N''PENDIENTE'' THROW 52521, ''La actualización no está pendiente o no pertenece al usuario.'', 1;
    DECLARE @Recurso NVARCHAR(255) = CONCAT(N''BANCI:ENTIDAD:'', @IdEntidad);
    IF ISNULL(APPLOCK_MODE(N''public'', @Recurso, N''Transaction''), N''NoLock'') NOT IN (N''Shared'', N''Exclusive'') THROW 52522, ''Falta el bloqueo de la entidad.'', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.usuario u WITH (HOLDLOCK)
    JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
    JOIN dbo.catalogo_modulo m WITH (HOLDLOCK) ON m.clave = N''BANCI'' AND m.activo = 1
    LEFT JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = m.id_modulo AND um.activo = 1 AND um.habilitado = 1
    WHERE u.id_usuario = @IdUsuario AND u.activo = 1
      AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad AND um.id_usuario IS NOT NULL AND um.habilita_modificacion = 1))) THROW 52523, ''No tiene permiso de modificación BANCI para esta entidad.'', 1;
    IF ISJSON(@Datos) <> 1 OR LEFT(LTRIM(@Datos), 1) <> N''['' THROW 52524, ''Los datos deben ser un arreglo JSON.'', 1;
    IF EXISTS (SELECT 1 FROM OPENJSON(@Datos) WHERE type <> 5) THROW 52524, ''Cada fila debe ser un objeto JSON.'', 1;
    SELECT CONVERT(INT, [key]) AS indice, value AS datos INTO #Filas FROM OPENJSON(@Datos);
    IF (SELECT COUNT(*) FROM #Filas) NOT BETWEEN 1 AND 20000 THROW 52524, ''Se permiten de 1 a 20000 víctimas por actualización.'', 1;
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j GROUP BY f.indice, j.[key] COLLATE Latin1_General_100_BIN2 HAVING COUNT(*) > 1)
        THROW 52524, ''Hay propiedades JSON repetidas en una fila.'', 1;
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j WHERE j.[key] COLLATE Latin1_General_100_BIN2 NOT IN (N''fila'',N''no_banci'',N''id_delito'',N''id_vicf'',N''fub'',N''pro_apellido'',N''sdo_apellido'',N''nomb'',N''entidad_nacimiento'',N''estado_migratorio'',N''curp'',N''rfc'',N''localizado_o_no_localizado'',N''con_o_sin_vida'',N''fecha_localizacion'',N''voluntaria_o_fue_delito'',N''delito'',N''acciones_busqueda'',N''obs''))
        THROW 52524, ''La actualización contiene columnas no permitidas.'', 1;
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j WHERE j.type NOT IN (0,1,2)) THROW 52524, ''Los campos deben ser texto, número o null.'', 1;
    SELECT f.indice, j.[key] COLLATE DATABASE_DEFAULT AS campo, NULLIF(LTRIM(RTRIM(j.value)), N'''') AS valor INTO #Valores FROM #Filas f CROSS APPLY OPENJSON(f.datos) j;
    IF EXISTS (SELECT 1 FROM #Valores WHERE (campo = N''no_banci'' AND DATALENGTH(valor) > 80) OR (campo = N''id_delito'' AND DATALENGTH(valor) > 500) OR (campo = N''id_vicf'' AND DATALENGTH(valor) > 500) OR (campo = N''fub'' AND DATALENGTH(valor) > 500) OR (campo = N''pro_apellido'' AND DATALENGTH(valor) > 500) OR (campo = N''sdo_apellido'' AND DATALENGTH(valor) > 500) OR (campo = N''nomb'' AND DATALENGTH(valor) > 1000) OR (campo = N''entidad_nacimiento'' AND DATALENGTH(valor) > 500) OR (campo = N''estado_migratorio'' AND DATALENGTH(valor) > 1000) OR (campo = N''curp'' AND DATALENGTH(valor) > 100) OR (campo = N''rfc'' AND DATALENGTH(valor) > 26) OR (campo = N''localizado_o_no_localizado'' AND DATALENGTH(valor) > 6) OR (campo = N''con_o_sin_vida'' AND DATALENGTH(valor) > 6) OR (campo = N''fecha_localizacion'' AND DATALENGTH(valor) > 20) OR (campo = N''voluntaria_o_fue_delito'' AND DATALENGTH(valor) > 6) OR (campo = N''delito'' AND DATALENGTH(valor) > 2000)) THROW 52525, ''Un campo supera su longitud permitida.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE campo = N''fila'' AND valor IS NOT NULL AND (TRY_CONVERT(INT, valor) IS NULL OR TRY_CONVERT(INT, valor) < 1)) THROW 52525, ''Número de fila inválido.'', 1;
    SELECT f.indice, COALESCE(TRY_CONVERT(INT, JSON_VALUE(f.datos, ''$.fila'')), f.indice + 1) AS fila,
        NULLIF(LTRIM(RTRIM(JSON_VALUE(f.datos, ''$.no_banci''))), N'''') AS no_banci,
        NULLIF(LTRIM(RTRIM(JSON_VALUE(f.datos, ''$.id_delito''))), N'''') AS id_delito,
        NULLIF(LTRIM(RTRIM(JSON_VALUE(f.datos, ''$.id_vicf''))), N'''') AS id_vicf
    INTO #Llaves FROM #Filas f;
    IF EXISTS (SELECT 1 FROM #Llaves WHERE no_banci IS NULL OR id_delito IS NULL OR id_vicf IS NULL) THROW 52526, ''Cada víctima requiere NO_BANCI, ID_DELITO e ID_VICF.'', 1;
    SELECT k.indice, k.fila, v.* INTO #Actual FROM #Llaves k JOIN dbo.banci_vw_victimas_v2 v WITH (HOLDLOCK)
        ON v.no_banci = k.no_banci AND v.id_delito = k.id_delito AND v.id_vicf = k.id_vicf AND v.id_entidad_federativa = @IdEntidad;
    IF (SELECT COUNT(*) FROM #Actual) <> (SELECT COUNT(*) FROM #Llaves) THROW 52527, ''Alguna víctima no existe, está inactiva o pertenece a otra entidad.'', 1;
    IF EXISTS (SELECT 1 FROM #Actual GROUP BY id_banci_victima HAVING COUNT(*) > 1) THROW 52528, ''Una víctima aparece varias veces en el archivo.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE valor IS NOT NULL AND campo IN (N''localizado_o_no_localizado'',N''con_o_sin_vida'') AND (TRY_CONVERT(TINYINT,valor) IS NULL OR TRY_CONVERT(TINYINT,valor) NOT IN (1,2))) THROW 52529, ''Localización o condición de vida fuera del catálogo.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE valor IS NOT NULL AND campo = N''voluntaria_o_fue_delito'' AND (TRY_CONVERT(TINYINT,valor) IS NULL OR TRY_CONVERT(TINYINT,valor) NOT IN (1,2,3))) THROW 52529, ''Motivo de localización fuera del catálogo 1/2/3.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE valor IS NOT NULL AND campo = N''fecha_localizacion'' AND (TRY_CONVERT(DATE,valor,23) IS NULL OR CONVERT(NVARCHAR(10),TRY_CONVERT(DATE,valor,23),23) <> valor)) THROW 52529, ''La fecha de localización debe ser válida y estar en formato yyyy-MM-dd.'', 1;
    IF EXISTS (SELECT 1 FROM #Valores WHERE valor IS NOT NULL AND campo = N''curp'' AND (LEN(valor) <> 18 OR valor COLLATE Latin1_General_100_BIN2 LIKE N''%[^A-Z0-9]%'')) THROW 52529, ''La CURP debe tener 18 caracteres alfanuméricos en mayúsculas.'', 1;
    -- La API valida el formato completo y consulta RENAPO antes de guardar la operación.
    -- Delito de localización: opcional e independiente; se acepta clave2 o descripción del catálogo mensual.
    IF EXISTS (SELECT 1 FROM #Valores x WHERE x.campo = N''delito'' AND x.valor IS NOT NULL AND
        (SELECT COUNT(*) FROM dbo.banci_vw_delito_localizacion_catalogo d WHERE d.clave = x.valor OR d.descripcion = x.valor) <> 1)
        THROW 52530, ''El delito de localización no corresponde unívocamente a un delito activo del catálogo Consolidado.'', 1;
    UPDATE x SET valor = d.descripcion FROM #Valores x JOIN dbo.banci_vw_delito_localizacion_catalogo d ON d.clave = x.valor OR d.descripcion = x.valor WHERE x.campo = N''delito'';
    SELECT a.indice, a.fila, a.id_banci_victima, a.no_banci, a.id_ci, a.id_delito, a.id_vicf,
        fub = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''fub'')),a.fub),
        pro_apellido = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''pro_apellido'')),a.pro_apellido),
        sdo_apellido = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''sdo_apellido'')),a.sdo_apellido),
        nomb = COALESCE(TRY_CONVERT(NVARCHAR(500),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''nomb'')),a.nomb),
        entidad_nacimiento = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''entidad_nacimiento'')),a.entidad_nacimiento),
        estado_migratorio = COALESCE(TRY_CONVERT(NVARCHAR(500),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''estado_migratorio'')),a.estado_migratorio),
        curp = COALESCE(TRY_CONVERT(NVARCHAR(50),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''curp'')),a.curp),
        rfc = COALESCE(TRY_CONVERT(NVARCHAR(13),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''rfc'')),a.rfc),
        localizado_o_no_localizado = COALESCE(TRY_CONVERT(TINYINT,(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''localizado_o_no_localizado'')),a.localizado_o_no_localizado),
        con_o_sin_vida = COALESCE(TRY_CONVERT(TINYINT,(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''con_o_sin_vida'')),a.con_o_sin_vida),
        fecha_localizacion = COALESCE(TRY_CONVERT(DATE,(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''fecha_localizacion''),23),a.fecha_localizacion),
        voluntaria_o_fue_delito = COALESCE(TRY_CONVERT(TINYINT,(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''voluntaria_o_fue_delito'')),a.voluntaria_o_fue_delito),
        delito = COALESCE(TRY_CONVERT(NVARCHAR(1000),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''delito'')),a.delito),
        acciones_busqueda = COALESCE(TRY_CONVERT(NVARCHAR(MAX),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''acciones_busqueda'')),a.acciones_busqueda),
        obs = COALESCE(TRY_CONVERT(NVARCHAR(MAX),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''obs'')),a.obs)
    INTO #Propuesto FROM #Actual a;
    IF EXISTS (SELECT 1 FROM #Propuesto WHERE NULLIF(LTRIM(RTRIM(fub)), N'''') IS NULL) THROW 52531, ''FUB es obligatorio; informe el folio faltante antes de actualizar.'', 1;
    -- Revalidar la fecha final al preparar, recuperar y confirmar; los vacíos conservan el valor registrado.
    DECLARE @HoyLocal DATE = CONVERT(DATE, SWITCHOFFSET(SYSDATETIMEOFFSET(), ''-06:00''));
    IF EXISTS (SELECT 1 FROM #Propuesto p JOIN #Actual a ON a.id_banci_victima = p.id_banci_victima
        WHERE EXISTS (SELECT 1 FROM #Valores x WHERE x.indice = a.indice AND x.valor IS NOT NULL
            AND x.campo IN (N''fecha_localizacion'', N''localizado_o_no_localizado'', N''con_o_sin_vida'', N''voluntaria_o_fue_delito''))
          AND (p.fecha_localizacion > @HoyLocal OR p.fecha_localizacion < CONVERT(DATE, a.fha_de_ini) OR p.fecha_localizacion < CONVERT(DATE, a.fha_de_hchos)))
        THROW 52536, ''La fecha de localización debe estar entre el inicio de la carpeta/los hechos y hoy. Rechace esta revisión y corrija la fecha.'', 1;
    SELECT a.id_banci_victima, a.fila, a.no_banci, a.id_ci, a.id_delito, a.id_vicf, x.campo, x.anterior, x.nuevo INTO #Cambios
    FROM #Actual a JOIN #Propuesto p ON p.id_banci_victima = a.id_banci_victima
    CROSS APPLY (VALUES (N''fub'',CONVERT(NVARCHAR(MAX),a.fub),CONVERT(NVARCHAR(MAX),p.fub)),
        (N''pro_apellido'',CONVERT(NVARCHAR(MAX),a.pro_apellido),CONVERT(NVARCHAR(MAX),p.pro_apellido)),
        (N''sdo_apellido'',CONVERT(NVARCHAR(MAX),a.sdo_apellido),CONVERT(NVARCHAR(MAX),p.sdo_apellido)),
        (N''nomb'',CONVERT(NVARCHAR(MAX),a.nomb),CONVERT(NVARCHAR(MAX),p.nomb)),
        (N''entidad_nacimiento'',CONVERT(NVARCHAR(MAX),a.entidad_nacimiento),CONVERT(NVARCHAR(MAX),p.entidad_nacimiento)),
        (N''estado_migratorio'',CONVERT(NVARCHAR(MAX),a.estado_migratorio),CONVERT(NVARCHAR(MAX),p.estado_migratorio)),
        (N''curp'',CONVERT(NVARCHAR(MAX),a.curp),CONVERT(NVARCHAR(MAX),p.curp)),
        (N''rfc'',CONVERT(NVARCHAR(MAX),a.rfc),CONVERT(NVARCHAR(MAX),p.rfc)),
        (N''localizado_o_no_localizado'',CONVERT(NVARCHAR(MAX),a.localizado_o_no_localizado),CONVERT(NVARCHAR(MAX),p.localizado_o_no_localizado)),
        (N''con_o_sin_vida'',CONVERT(NVARCHAR(MAX),a.con_o_sin_vida),CONVERT(NVARCHAR(MAX),p.con_o_sin_vida)),
        (N''fecha_localizacion'',CONVERT(NVARCHAR(MAX),a.fecha_localizacion,23),CONVERT(NVARCHAR(MAX),p.fecha_localizacion,23)),
        (N''voluntaria_o_fue_delito'',CONVERT(NVARCHAR(MAX),a.voluntaria_o_fue_delito),CONVERT(NVARCHAR(MAX),p.voluntaria_o_fue_delito)),
        (N''delito'',CONVERT(NVARCHAR(MAX),a.delito),CONVERT(NVARCHAR(MAX),p.delito)),
        (N''acciones_busqueda'',CONVERT(NVARCHAR(MAX),a.acciones_busqueda),CONVERT(NVARCHAR(MAX),p.acciones_busqueda)),
        (N''obs'',CONVERT(NVARCHAR(MAX),a.obs),CONVERT(NVARCHAR(MAX),p.obs))) x(campo, anterior, nuevo)
    WHERE (x.anterior IS NULL AND x.nuevo IS NOT NULL) OR (x.anterior IS NOT NULL AND x.nuevo IS NULL) OR x.anterior COLLATE Latin1_General_100_BIN2 <> x.nuevo COLLATE Latin1_General_100_BIN2;
    SET @DatosAplicar = (SELECT * FROM #Propuesto ORDER BY id_banci_victima FOR JSON PATH, INCLUDE_NULL_VALUES);
    SET @Cambios = (SELECT * FROM #Cambios ORDER BY id_banci_victima, campo FOR JSON PATH, INCLUDE_NULL_VALUES);
    DECLARE @Snapshot NVARCHAR(MAX) = (SELECT id_banci_victima, CONVERT(VARCHAR(18), version_banci, 1) AS version_banci FROM #Actual ORDER BY id_banci_victima FOR JSON PATH);
    SET @Huella = CONVERT(VARCHAR(64), HASHBYTES(''SHA2_256'', CONCAT(CONVERT(NVARCHAR(MAX),@CodigoReferencia),N''|'',@IdUsuario,N''|'',@Datos,N''|'',@Advertencias,N''|'',@Snapshot,N''|'',@DatosAplicar,N''|'',@Cambios)),2);
END;';

-- Definición completa: sp_banci_confirmar_actualizacion_v2
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_confirmar_actualizacion_v2
    @CodigoReferencia UNIQUEIDENTIFIER, @IdUsuario INT, @Aceptar BIT, @HuellaVistaPrevia VARCHAR(64) = NULL, @AceptarAdvertencias BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 52520, ''Ejecute sin transacción externa.'', 1;
    IF @Aceptar IS NULL THROW 52524, ''Debe indicar aceptar o rechazar.'', 1;
    DECLARE @IdEntidad TINYINT, @Id BIGINT, @Estado NVARCHAR(20), @Origen NVARCHAR(20), @Advertencias NVARCHAR(MAX), @Total INT,
        @Lock INT, @Huella VARCHAR(64), @Aplicar NVARCHAR(MAX), @Cambios NVARCHAR(MAX), @YaResuelta BIT = 0;
    SELECT @IdEntidad = id_entidad_federativa FROM dbo.banci_actualizacion_v2 WHERE codigo_referencia = @CodigoReferencia AND id_usuario = @IdUsuario;
    IF @IdEntidad IS NULL THROW 52521, ''No existe una actualización disponible para el usuario.'', 1;
    DECLARE @Recurso NVARCHAR(255) = CONCAT(N''BANCI:ENTIDAD:'',@IdEntidad);
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @Lock = sys.sp_getapplock @Resource = @Recurso, @LockMode = N''Exclusive'', @LockOwner = N''Transaction'', @LockTimeout = 10000;
        IF @Lock < 0 THROW 52522, ''Hay una integración en curso.'', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.usuario u WITH (HOLDLOCK)
    JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
    JOIN dbo.catalogo_modulo m WITH (HOLDLOCK) ON m.clave = N''BANCI'' AND m.activo = 1
    LEFT JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = m.id_modulo AND um.activo = 1 AND um.habilitado = 1
    WHERE u.id_usuario = @IdUsuario AND u.activo = 1
      AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad AND um.id_usuario IS NOT NULL ))) THROW 52523, ''El usuario ya no tiene acceso BANCI a esta entidad.'', 1;
        SELECT @Id = id_actualizacion, @Estado = estado, @Origen = origen, @Advertencias = advertencias_json, @Total = total_cambios
        FROM dbo.banci_actualizacion_v2 WITH (UPDLOCK,HOLDLOCK) WHERE codigo_referencia = @CodigoReferencia AND id_usuario = @IdUsuario;
        IF @Estado = N''INTEGRADA'' AND @Aceptar = 0 THROW 52532, ''Una actualización integrada no puede rechazarse.'', 1;
        IF @Estado = N''RECHAZADA'' AND @Aceptar = 1 THROW 52532, ''Una actualización rechazada requiere una nueva operación.'', 1;
        IF @Estado IN (N''INTEGRADA'',N''RECHAZADA'') SET @YaResuelta = 1;
        ELSE IF @Aceptar = 0
        BEGIN
            SET @Estado = N''RECHAZADA''; SET @Total = 0;
            UPDATE dbo.banci_actualizacion_v2 SET estado = @Estado, fecha_decision = SYSDATETIME(), total_cambios = 0 WHERE id_actualizacion = @Id;
        END
        ELSE
        BEGIN
            EXEC dbo.sp_banci_calcular_actualizacion_v2 @CodigoReferencia,@IdUsuario,@Huella OUTPUT,@Aplicar OUTPUT,@Cambios OUTPUT;
            IF @HuellaVistaPrevia IS NULL OR @HuellaVistaPrevia COLLATE Latin1_General_100_BIN2 <> @Huella COLLATE Latin1_General_100_BIN2 THROW 52533, ''La vista previa cambió. Revise nuevamente antes de aceptar.'', 1;
            IF EXISTS (SELECT 1 FROM OPENJSON(@Advertencias)) AND ISNULL(@AceptarAdvertencias,0) <> 1 THROW 52534, ''Debe aceptar explícitamente las advertencias de la operación.'', 1;
            SELECT * INTO #Cambios FROM OPENJSON(@Cambios) WITH (id_banci_victima BIGINT, no_banci NVARCHAR(40), id_ci NVARCHAR(250), id_delito NVARCHAR(250), id_vicf NVARCHAR(250), campo NVARCHAR(150), anterior NVARCHAR(MAX), nuevo NVARCHAR(MAX));
            INSERT INTO dbo.banci_historial_cambio(tipo_registro,id_registro,id_entidad_federativa,id_ci,id_delito,id_vicf,no_banci_carpeta,tipo_movimiento,campo,valor_anterior,valor_nuevo,origen,id_usuario,id_actualizacion_v2)
            SELECT N''VICTIMA'',id_banci_victima,@IdEntidad,id_ci,id_delito,id_vicf,no_banci,N''MODIFICACION'',campo,anterior,nuevo,
                CASE WHEN @Origen = N''FORMULARIO'' THEN N''EDICION_MANUAL'' ELSE N''CARGA_MASIVA'' END,@IdUsuario,@Id FROM #Cambios;
            SELECT * INTO #Propuesto FROM OPENJSON(@Aplicar) WITH (id_banci_victima BIGINT, fub NVARCHAR(250), pro_apellido NVARCHAR(250), sdo_apellido NVARCHAR(250), nomb NVARCHAR(500), entidad_nacimiento NVARCHAR(250), estado_migratorio NVARCHAR(500), curp NVARCHAR(50), rfc NVARCHAR(13), localizado_o_no_localizado TINYINT, con_o_sin_vida TINYINT, fecha_localizacion DATE, voluntaria_o_fue_delito TINYINT, delito NVARCHAR(1000), acciones_busqueda NVARCHAR(MAX), obs NVARCHAR(MAX));
            UPDATE v SET fub = p.fub,
                pro_apellido = p.pro_apellido,
                sdo_apellido = p.sdo_apellido,
                nomb = p.nomb,
                entidad_nacimiento = p.entidad_nacimiento,
                estado_migratorio = p.estado_migratorio,
                curp = p.curp,
                rfc = p.rfc,
                localizado_o_no_localizado = p.localizado_o_no_localizado,
                con_o_sin_vida = p.con_o_sin_vida,
                fecha_localizacion = p.fecha_localizacion,
                voluntaria_o_fue_delito = p.voluntaria_o_fue_delito,
                delito = p.delito,
                acciones_busqueda = p.acciones_busqueda,
                obs = p.obs, id_usuario_modificacion = @IdUsuario, fecha_modificacion = SYSDATETIME()
            FROM dbo.banci_victima v JOIN #Propuesto p ON p.id_banci_victima = v.id_banci_victima
            WHERE EXISTS (SELECT 1 FROM #Cambios x WHERE x.id_banci_victima = v.id_banci_victima);
            SET @Total = (SELECT COUNT(*) FROM #Cambios);
            SET @Estado = N''INTEGRADA'';
            UPDATE dbo.banci_actualizacion_v2 SET estado = @Estado,fecha_decision = SYSDATETIME(),total_cambios = @Total WHERE id_actualizacion = @Id;
        END;
        COMMIT TRANSACTION;
        SELECT @CodigoReferencia AS CodigoReferencia,@Estado AS Estado,@YaResuelta AS YaResuelta,@Total AS TotalCambios;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

-- Definición completa: sp_banci_buscar_victimas_v2
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_buscar_victimas_v2
    @IdUsuario INT, @Texto NVARCHAR(250), @IdEntidad TINYINT = NULL, @Pagina INT = 1, @Tamano INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Rol NVARCHAR(100), @EntidadUsuario TINYINT;
    SELECT @Rol = r.rol,@EntidadUsuario = u.id_entidad_federativa
    FROM dbo.usuario u JOIN dbo.roles r ON r.id_rol = u.id_rol AND r.activo = 1
    JOIN dbo.catalogo_modulo m ON m.clave = N''BANCI'' AND m.activo = 1
    LEFT JOIN dbo.usuario_modulo um ON um.id_usuario = u.id_usuario AND um.id_modulo = m.id_modulo AND um.activo = 1 AND um.habilitado = 1
    WHERE u.id_usuario = @IdUsuario AND u.activo = 1 AND (r.rol = N''SUPER_USUARIO'' OR um.id_usuario IS NOT NULL);
    IF @Rol IS NULL OR @Rol NOT IN (N''SUPER_USUARIO'',N''ENLACE_ESTATAL'',N''CONSULTA'') THROW 52523, ''Sin acceso BANCI.'', 1;
    IF @Rol = N''ENLACE_ESTATAL'' AND (@EntidadUsuario IS NULL OR @EntidadUsuario NOT BETWEEN 1 AND 32) THROW 52523, ''El enlace debe tener una entidad asignada.'', 1;
    IF @Rol <> N''SUPER_USUARIO'' AND @EntidadUsuario IS NOT NULL
    BEGIN
        IF @IdEntidad IS NOT NULL AND @IdEntidad <> @EntidadUsuario THROW 52523, ''No puede consultar otra entidad.'', 1;
        SET @IdEntidad = @EntidadUsuario;
    END;
    SET @Texto = NULLIF(LTRIM(RTRIM(@Texto)),N'''');
    IF @Texto IS NULL OR LEN(@Texto) < 3 THROW 52535, ''Escriba al menos tres caracteres para buscar.'', 1;
    IF @Pagina IS NULL OR @Pagina NOT BETWEEN 1 AND 1000000 OR @Tamano IS NULL OR @Tamano NOT BETWEEN 1 AND 100 THROW 52535, ''Paginación inválida.'', 1;
    -- CHARINDEX trata %, _ y [ como texto literal; no amplía la búsqueda por comodines.
    SELECT COUNT_BIG(*) OVER () AS Total, * FROM dbo.banci_vw_victimas_v2
    WHERE (@IdEntidad IS NULL OR id_entidad_federativa = @IdEntidad)
      AND (no_banci = @Texto OR curp = @Texto OR fub = @Texto OR CHARINDEX(@Texto,CONCAT(nomb,N'' '',pro_apellido,N'' '',sdo_apellido)) > 0)
    ORDER BY id_entidad_federativa,no_banci,id_delito,id_vicf OFFSET (@Pagina-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
END;';

COMMIT TRANSACTION;
PRINT N'BANCI v3 instalado. Reinicie API y Front con el mismo paquete.';
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
