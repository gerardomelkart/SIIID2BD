-- REFERENCIA TECNICA: base y ajustes en secuencia; no ejecutar sobre una BD publicada.
-- No sustituye una exportación del esquema real. Revisar dependencias indicadas en README.

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/01_20260914_01_modulo_banci_estructura.sql
USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    SIIID2 - Módulo BANCI / DFPyCPP
    Paso 01: estructura base.

    Características:
    - módulo independiente;
    - ligado funcionalmente a Consolidado/RNID;
    - sin cortes mensuales propios;
    - información viva y actualizable;
    - acepta carga masiva desde:
        * un Excel con 3 hojas;
        * tres archivos separados;
    - permite captura por formulario;
    - conserva auditoría campo por campo;
    - NO modifica tablas operativas de Consolidado;
    - NO modifica Federal;
    - NO modifica Semanal.

    Ejecutar primero únicamente en DEV.
*/

IF DB_NAME() <> N'siiid2'
BEGIN
    THROW 52000, 'El script debe ejecutarse en la base siiid2.', 1;
END;
GO

DECLARE @Requeridas TABLE
(
    nombre SYSNAME PRIMARY KEY
);

INSERT INTO @Requeridas (nombre)
VALUES
    (N'catalogo_modulo'),
    (N'usuario'),
    (N'catalogo_entidad_federativa'),
    (N'catalogo_municipio'),
    (N'catalogo_forma_accion'),
    (N'catalogo_instrumento_comision'),
    (N'catalogo_grado_consumacion'),
    (N'catalogo_sexo'),
    (N'catalogo_genero'),
    (N'catalogo_nacionalidad'),
    (N'catalogo_pertenece_poblacion_indigena'),
    (N'catalogo_presenta_discapacidad');

IF EXISTS
(
    SELECT 1
    FROM @Requeridas r
    WHERE OBJECT_ID(N'dbo.' + r.nombre, N'U') IS NULL
)
BEGIN
    SELECT
        r.nombre AS tabla_faltante
    FROM @Requeridas r
    WHERE OBJECT_ID(N'dbo.' + r.nombre, N'U') IS NULL
    ORDER BY r.nombre;

    THROW 52001, 'Faltan tablas compartidas requeridas por BANCI.', 1;
END;
GO

DECLARE @ObjetosBanci TABLE
(
    nombre SYSNAME PRIMARY KEY
);

INSERT INTO @ObjetosBanci (nombre)
VALUES
    (N'banci_catalogo_clasificacion_delito'),
    (N'banci_catalogo_localizacion'),
    (N'banci_catalogo_condicion_vida'),
    (N'banci_catalogo_voluntaria'),
    (N'banci_catalogo_fue_delito'),
    (N'banci_carga'),
    (N'banci_carga_bitacora_estado'),
    (N'banci_carga_archivo'),
    (N'banci_carga_observacion'),
    (N'banci_carga_tmp_carpeta'),
    (N'banci_carga_tmp_delito'),
    (N'banci_carga_tmp_victima'),
    (N'banci_carpeta_investigacion'),
    (N'banci_delito'),
    (N'banci_victima'),
    (N'banci_historial_cambio');

IF EXISTS
(
    SELECT 1
    FROM @ObjetosBanci o
    WHERE OBJECT_ID(N'dbo.' + o.nombre, N'U') IS NOT NULL
)
BEGIN
    SELECT
        o.nombre AS objeto_banci_existente
    FROM @ObjetosBanci o
    WHERE OBJECT_ID(N'dbo.' + o.nombre, N'U') IS NOT NULL
    ORDER BY o.nombre;

    THROW 52002, 'Ya existe al menos una tabla BANCI. No se aplicó ninguna modificación.', 1;
END;

IF OBJECT_ID(N'dbo.seq_banci_no_banci', N'SO') IS NOT NULL
BEGIN
    THROW 52003, 'Ya existe la secuencia seq_banci_no_banci.', 1;
END;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.catalogo_modulo
        WHERE clave = N'BANCI'
    )
    BEGIN
        INSERT INTO dbo.catalogo_modulo
        (
            clave,
            nombre,
            activo
        )
        VALUES
        (
            N'BANCI',
            N'BANCI / DFPyCPP',
            0
        );
    END
    ELSE IF EXISTS
    (
        SELECT 1
        FROM dbo.catalogo_modulo
        WHERE clave = N'BANCI'
          AND activo = 1
    )
    BEGIN
        THROW 52004, 'BANCI ya existe y está activo. Se cancela la creación de estructura.', 1;
    END;

    /* ============================================================
       CATÁLOGOS PROPIOS BANCI
       ============================================================ */

    CREATE TABLE dbo.banci_catalogo_clasificacion_delito
    (
        clave NVARCHAR(10) NOT NULL,
        tipo_delito NVARCHAR(150) NOT NULL,
        descripcion NVARCHAR(500) NOT NULL,
        activo BIT NOT NULL
            CONSTRAINT DF_banci_clasificacion_activo DEFAULT (1),

        CONSTRAINT PK_banci_catalogo_clasificacion_delito
            PRIMARY KEY (clave)
    );

    CREATE TABLE dbo.banci_catalogo_localizacion
    (
        clave TINYINT NOT NULL,
        descripcion NVARCHAR(100) NOT NULL,
        activo BIT NOT NULL
            CONSTRAINT DF_banci_localizacion_activo DEFAULT (1),

        CONSTRAINT PK_banci_catalogo_localizacion
            PRIMARY KEY (clave)
    );

    CREATE TABLE dbo.banci_catalogo_condicion_vida
    (
        clave TINYINT NOT NULL,
        descripcion NVARCHAR(100) NOT NULL,
        activo BIT NOT NULL
            CONSTRAINT DF_banci_condicion_vida_activo DEFAULT (1),

        CONSTRAINT PK_banci_catalogo_condicion_vida
            PRIMARY KEY (clave)
    );

    CREATE TABLE dbo.banci_catalogo_voluntaria
    (
        clave TINYINT NOT NULL,
        descripcion NVARCHAR(150) NOT NULL,
        activo BIT NOT NULL
            CONSTRAINT DF_banci_voluntaria_activo DEFAULT (1),

        CONSTRAINT PK_banci_catalogo_voluntaria
            PRIMARY KEY (clave)
    );

    CREATE TABLE dbo.banci_catalogo_fue_delito
    (
        clave TINYINT NOT NULL,
        descripcion NVARCHAR(150) NOT NULL,
        activo BIT NOT NULL
            CONSTRAINT DF_banci_fue_delito_activo DEFAULT (1),

        CONSTRAINT PK_banci_catalogo_fue_delito
            PRIMARY KEY (clave)
    );

    /* ============================================================
       NÚMERO BANCI
       ============================================================ */

    -- No_BANCI queda reservado para asignación posterior por SESNSP.

    /* ============================================================
       ENCABEZADO DE INGESTA
       No existe mes_corte / anio_corte.
       Cada registro representa una operación de ingreso.
       ============================================================ */

    CREATE TABLE dbo.banci_carga
    (
        id_banci_carga BIGINT IDENTITY(1,1) NOT NULL,
        id_usuario_carga INT NOT NULL,
        id_entidad_federativa TINYINT NOT NULL,

        codigo_referencia NVARCHAR(50) NOT NULL,

        modalidad_ingesta NVARCHAR(40) NOT NULL,

        fecha_carga DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_carga_fecha
            DEFAULT (SYSDATETIME()),

        fecha_inicio_procesamiento DATETIME2(0) NULL,
        fecha_fin_procesamiento DATETIME2(0) NULL,

        -- NULL = todavía no decide; 0 = rechazo; 1 = aceptación.
        aceptada_usuario BIT NULL,
        id_usuario_confirmacion INT NULL,
        fecha_confirmacion DATETIME2(7) NULL,

        total_carpetas INT NOT NULL
            CONSTRAINT DF_banci_carga_total_carpetas DEFAULT (0),

        total_delitos INT NOT NULL
            CONSTRAINT DF_banci_carga_total_delitos DEFAULT (0),

        total_victimas INT NOT NULL
            CONSTRAINT DF_banci_carga_total_victimas DEFAULT (0),

        total_altas INT NOT NULL
            CONSTRAINT DF_banci_carga_total_altas DEFAULT (0),

        total_actualizaciones INT NOT NULL
            CONSTRAINT DF_banci_carga_total_actualizaciones DEFAULT (0),

        total_sin_cambio INT NOT NULL
            CONSTRAINT DF_banci_carga_total_sin_cambio DEFAULT (0),

        total_errores INT NOT NULL
            CONSTRAINT DF_banci_carga_total_errores DEFAULT (0),

        total_advertencias INT NOT NULL
            CONSTRAINT DF_banci_carga_total_advertencias DEFAULT (0),

        estado NVARCHAR(40) NOT NULL
            CONSTRAINT DF_banci_carga_estado DEFAULT (N'RECIBIDO'),

        mensaje_error NVARCHAR(MAX) NULL,

        activo BIT NOT NULL
            CONSTRAINT DF_banci_carga_activo DEFAULT (1),

        CONSTRAINT PK_banci_carga
            PRIMARY KEY (id_banci_carga),

        CONSTRAINT UQ_banci_carga_codigo
            UNIQUE (codigo_referencia),

        CONSTRAINT FK_banci_carga_usuario
            FOREIGN KEY (id_usuario_carga)
            REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT FK_banci_carga_confirmacion_usuario
            FOREIGN KEY (id_usuario_confirmacion) REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT CK_banci_carga_decision
            CHECK
            (
                (aceptada_usuario IS NULL AND id_usuario_confirmacion IS NULL AND fecha_confirmacion IS NULL)
                OR (aceptada_usuario IS NOT NULL AND id_usuario_confirmacion IS NOT NULL AND fecha_confirmacion IS NOT NULL)
            ),

        CONSTRAINT FK_banci_carga_entidad
            FOREIGN KEY (id_entidad_federativa)
            REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),

        CONSTRAINT CK_banci_carga_modalidad
            CHECK
            (
                modalidad_ingesta IN
                (
                    N'UN_EXCEL_TRES_HOJAS',
                    N'TRES_ARCHIVOS',
                    N'FORMULARIO',
                    N'COMPLEMENTO_CONSOLIDADO'
                )
            ),

        CONSTRAINT CK_banci_carga_estado
            CHECK
            (
                estado IN
                (
                    N'RECIBIDO',
                    N'VALIDANDO',
                    N'VALIDADO',
                    N'VALIDADO_PENDIENTE',
                    N'RECHAZADO_VALIDACION',
                    N'PROCESANDO',
                    N'PROCESADO',
                    N'PROCESADO_CON_ADVERTENCIAS',
                    N'ERROR'
                )
            ),

        CONSTRAINT CK_banci_carga_totales
            CHECK
            (
                total_carpetas >= 0
                AND total_delitos >= 0
                AND total_victimas >= 0
                AND total_altas >= 0
                AND total_actualizaciones >= 0
                AND total_sin_cambio >= 0
                AND total_errores >= 0
                AND total_advertencias >= 0
            )
    );

    /* ============================================================
       ARCHIVOS DE UNA INGESTA
       ============================================================ */

    CREATE TABLE dbo.banci_carga_bitacora_estado
    (
        id_banci_carga_bitacora_estado BIGINT IDENTITY(1,1) NOT NULL,
        id_banci_carga BIGINT NOT NULL,
        estado_anterior NVARCHAR(40) NULL,
        estado_nuevo NVARCHAR(40) NOT NULL,
        id_usuario INT NOT NULL,
        fecha DATETIME2(7) NOT NULL CONSTRAINT DF_banci_bitacora_fecha DEFAULT (SYSDATETIME()),
        comentario NVARCHAR(1000) NULL,
        CONSTRAINT PK_banci_carga_bitacora_estado PRIMARY KEY (id_banci_carga_bitacora_estado),
        CONSTRAINT FK_banci_bitacora_carga FOREIGN KEY (id_banci_carga) REFERENCES dbo.banci_carga(id_banci_carga),
        CONSTRAINT FK_banci_bitacora_usuario FOREIGN KEY (id_usuario) REFERENCES dbo.usuario(id_usuario)
    );
    CREATE INDEX IX_banci_bitacora_carga_fecha ON dbo.banci_carga_bitacora_estado(id_banci_carga, fecha, id_banci_carga_bitacora_estado);

    CREATE TABLE dbo.banci_carga_archivo
    (
        id_banci_carga_archivo BIGINT IDENTITY(1,1) NOT NULL,
        id_banci_carga BIGINT NOT NULL,

        tipo_archivo NVARCHAR(20) NOT NULL,

        nombre_archivo_original NVARCHAR(500) NOT NULL,
        ruta_archivo NVARCHAR(1000) NULL,

        sha256 CHAR(64) NULL,
        tamano_bytes BIGINT NULL,

        fecha_registro DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_carga_archivo_fecha
            DEFAULT (SYSDATETIME()),

        activo BIT NOT NULL
            CONSTRAINT DF_banci_carga_archivo_activo DEFAULT (1),

        CONSTRAINT PK_banci_carga_archivo
            PRIMARY KEY (id_banci_carga_archivo),

        CONSTRAINT FK_banci_carga_archivo_carga
            FOREIGN KEY (id_banci_carga)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT CK_banci_carga_archivo_tipo
            CHECK
            (
                tipo_archivo IN
                (
                    N'LIBRO',
                    N'CI',
                    N'DELITOS',
                    N'VICTIMAS'
                )
            ),

        CONSTRAINT CK_banci_carga_archivo_tamano
            CHECK
            (
                tamano_bytes IS NULL
                OR tamano_bytes >= 0
            )
    );

    /* ============================================================
       ERRORES / ADVERTENCIAS DE VALIDACIÓN
       ============================================================ */

    CREATE TABLE dbo.banci_carga_observacion
    (
        id_banci_carga_observacion BIGINT IDENTITY(1,1) NOT NULL,
        id_banci_carga BIGINT NOT NULL,

        severidad NVARCHAR(20) NOT NULL,
        tipo_registro NVARCHAR(20) NOT NULL,

        numero_fila INT NULL,
        campo NVARCHAR(150) NULL,
        valor NVARCHAR(2000) NULL,

        codigo NVARCHAR(150) NOT NULL,
        mensaje NVARCHAR(2000) NOT NULL,

        fecha_registro DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_observacion_fecha
            DEFAULT (SYSDATETIME()),

        activo BIT NOT NULL
            CONSTRAINT DF_banci_observacion_activo DEFAULT (1),

        CONSTRAINT PK_banci_carga_observacion
            PRIMARY KEY (id_banci_carga_observacion),

        CONSTRAINT FK_banci_observacion_carga
            FOREIGN KEY (id_banci_carga)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT CK_banci_observacion_severidad
            CHECK
            (
                severidad IN
                (
                    N'ERROR',
                    N'ADVERTENCIA'
                )
            ),

        CONSTRAINT CK_banci_observacion_tipo
            CHECK
            (
                tipo_registro IN
                (
                    N'GENERAL',
                    N'CARPETA',
                    N'DELITO',
                    N'VICTIMA'
                )
            )
    );

    /* ============================================================
       STAGING - CARPETAS
       Todo se conserva como texto durante la validación.
       ============================================================ */

    CREATE TABLE dbo.banci_carga_tmp_carpeta
    (
        id_banci_carga_tmp_carpeta BIGINT IDENTITY(1,1) NOT NULL,
        id_banci_carga BIGINT NOT NULL,
        id_banci_carga_archivo BIGINT NULL,

        nombre_hoja NVARCHAR(100) NULL,
        numero_fila INT NOT NULL,

        entidad NVARCHAR(250) NULL,
        id_ci NVARCHAR(250) NULL,
        ntra_ci NVARCHAR(250) NULL,
        fha_de_ini NVARCHAR(100) NULL,
        hra_de_ini NVARCHAR(100) NULL,
        rmen_de_hchos NVARCHAR(MAX) NULL,
        ord_apreh NVARCHAR(100) NULL,
        fgran NVARCHAR(100) NULL,
        ctaon NVARCHAR(100) NULL,
        td_v_ap NVARCHAR(100) NULL,
        proc_abrev NVARCHAR(100) NULL,
        juc_oral NVARCHAR(100) NULL,
        td_sen_con NVARCHAR(100) NULL,
        no_ejer_acc_pnal NVARCHAR(100) NULL,
        otra NVARCHAR(100) NULL,
        dic NVARCHAR(100) NULL,

        estado NVARCHAR(20) NOT NULL
            CONSTRAINT DF_banci_tmp_carpeta_estado DEFAULT (N'PENDIENTE'),

        fecha_procesamiento DATETIME2(0) NULL,

        activo BIT NOT NULL
            CONSTRAINT DF_banci_tmp_carpeta_activo DEFAULT (1),

        CONSTRAINT PK_banci_carga_tmp_carpeta
            PRIMARY KEY (id_banci_carga_tmp_carpeta),

        CONSTRAINT FK_banci_tmp_carpeta_carga
            FOREIGN KEY (id_banci_carga)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT FK_banci_tmp_carpeta_archivo
            FOREIGN KEY (id_banci_carga_archivo)
            REFERENCES dbo.banci_carga_archivo(id_banci_carga_archivo),

        CONSTRAINT CK_banci_tmp_carpeta_estado
            CHECK
            (
                estado IN
                (
                    N'PENDIENTE',
                    N'VALIDO',
                    N'ERROR'
                )
            )
    );

    /* ============================================================
       STAGING - DELITOS
       ============================================================ */

    CREATE TABLE dbo.banci_carga_tmp_delito
    (
        id_banci_carga_tmp_delito BIGINT IDENTITY(1,1) NOT NULL,
        id_banci_carga BIGINT NOT NULL,
        id_banci_carga_archivo BIGINT NULL,

        nombre_hoja NVARCHAR(100) NULL,
        numero_fila INT NOT NULL,

        entidad NVARCHAR(250) NULL,
        id_ci NVARCHAR(250) NULL,
        id_delito NVARCHAR(250) NULL,
        dto NVARCHAR(1000) NULL,
        moda_dto NVARCHAR(2000) NULL,
        forma_acc NVARCHAR(100) NULL,
        fha_de_hchos NVARCHAR(100) NULL,
        hra_de_hchos NVARCHAR(100) NULL,
        emto_com_dto NVARCHAR(100) NULL,
        grdo_cons NVARCHAR(100) NULL,
        clasf_de_dto NVARCHAR(100) NULL,
        nom_ent_hchos NVARCHAR(250) NULL,
        id_ent_hchos NVARCHAR(100) NULL,
        nom_mun_hchos NVARCHAR(250) NULL,
        id_mun_hchos NVARCHAR(100) NULL,
        nom_loc_hchos NVARCHAR(500) NULL,
        id_loc_hchos NVARCHAR(250) NULL,
        nom_col_hchos NVARCHAR(500) NULL,
        id_col_hchos NVARCHAR(250) NULL,
        cp NVARCHAR(100) NULL,
        coord_x NVARCHAR(100) NULL,
        coord_y NVARCHAR(100) NULL,
        dom_hchos NVARCHAR(MAX) NULL,

        estado NVARCHAR(20) NOT NULL
            CONSTRAINT DF_banci_tmp_delito_estado DEFAULT (N'PENDIENTE'),

        fecha_procesamiento DATETIME2(0) NULL,

        activo BIT NOT NULL
            CONSTRAINT DF_banci_tmp_delito_activo DEFAULT (1),

        CONSTRAINT PK_banci_carga_tmp_delito
            PRIMARY KEY (id_banci_carga_tmp_delito),

        CONSTRAINT FK_banci_tmp_delito_carga
            FOREIGN KEY (id_banci_carga)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT FK_banci_tmp_delito_archivo
            FOREIGN KEY (id_banci_carga_archivo)
            REFERENCES dbo.banci_carga_archivo(id_banci_carga_archivo),

        CONSTRAINT CK_banci_tmp_delito_estado
            CHECK
            (
                estado IN
                (
                    N'PENDIENTE',
                    N'VALIDO',
                    N'ERROR'
                )
            )
    );

    /* ============================================================
       STAGING - VÍCTIMAS
       ============================================================ */

    CREATE TABLE dbo.banci_carga_tmp_victima
    (
        id_banci_carga_tmp_victima BIGINT IDENTITY(1,1) NOT NULL,
        id_banci_carga BIGINT NOT NULL,
        id_banci_carga_archivo BIGINT NULL,

        nombre_hoja NVARCHAR(100) NULL,
        numero_fila INT NOT NULL,

        entidad NVARCHAR(250) NULL,
        id_ci NVARCHAR(250) NULL,
        id_delito NVARCHAR(250) NULL,
        id_vicf NVARCHAR(250) NULL,
        id_tv NVARCHAR(100) NULL,
        id_tpm NVARCHAR(100) NULL,
        sexo NVARCHAR(100) NULL,
        genero NVARCHAR(100) NULL,
        pob NVARCHAR(100) NULL,
        disc NVARCHAR(100) NULL,
        fha_nac NVARCHAR(100) NULL,
        edad NVARCHAR(100) NULL,
        nacional NVARCHAR(100) NULL,
        no_banci NVARCHAR(100) NULL,
        folio_fotovolante NVARCHAR(250) NULL,
        folio_rnpdno NVARCHAR(250) NULL,
        pro_apellido NVARCHAR(250) NULL,
        sdo_apellido NVARCHAR(250) NULL,
        nomb NVARCHAR(500) NULL,
        entidad_nacimiento NVARCHAR(250) NULL,
        estado_migratorio NVARCHAR(500) NULL,
        curp NVARCHAR(100) NULL,
        rfc NVARCHAR(100) NULL,
        fecha_ultimo_contacto NVARCHAR(100) NULL,
        hora_ultimo_contacto NVARCHAR(100) NULL,
        entidad_visto NVARCHAR(250) NULL,
        municipio_visto NVARCHAR(250) NULL,
        lugar_ultimo_contacto NVARCHAR(MAX) NULL,
        senas_tatuaje_datos_identificacion NVARCHAR(MAX) NULL,
        localizado_o_no_localizado NVARCHAR(100) NULL,
        con_o_sin_vida NVARCHAR(100) NULL,
        fecha_localizacion NVARCHAR(100) NULL,
        voluntaria NVARCHAR(100) NULL,
        fue_delito NVARCHAR(100) NULL,
        delito NVARCHAR(1000) NULL,
        obs NVARCHAR(MAX) NULL,

        estado NVARCHAR(20) NOT NULL
            CONSTRAINT DF_banci_tmp_victima_estado DEFAULT (N'PENDIENTE'),

        fecha_procesamiento DATETIME2(0) NULL,

        activo BIT NOT NULL
            CONSTRAINT DF_banci_tmp_victima_activo DEFAULT (1),

        CONSTRAINT PK_banci_carga_tmp_victima
            PRIMARY KEY (id_banci_carga_tmp_victima),

        CONSTRAINT FK_banci_tmp_victima_carga
            FOREIGN KEY (id_banci_carga)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT FK_banci_tmp_victima_archivo
            FOREIGN KEY (id_banci_carga_archivo)
            REFERENCES dbo.banci_carga_archivo(id_banci_carga_archivo),

        CONSTRAINT CK_banci_tmp_victima_estado
            CHECK
            (
                estado IN
                (
                    N'PENDIENTE',
                    N'VALIDO',
                    N'ERROR'
                )
            )
    );

    /* ============================================================
       TABLA VIVA - CARPETAS
       ============================================================ */

    CREATE TABLE dbo.banci_carpeta_investigacion
    (
        id_banci_carpeta_investigacion BIGINT IDENTITY(1,1) NOT NULL,

        id_entidad_federativa TINYINT NOT NULL,
        entidad NVARCHAR(100) NOT NULL,

        id_ci NVARCHAR(250) NOT NULL,
        ntra_ci NVARCHAR(250) NOT NULL,

        fha_de_ini DATE NOT NULL,
        hra_de_ini TIME(0) NULL,

        rmen_de_hchos NVARCHAR(MAX) NULL,

        ord_apreh INT NULL,
        fgran INT NULL,
        ctaon INT NULL,
        td_v_ap INT NULL,

        proc_abrev INT NULL,
        juc_oral INT NULL,
        td_sen_con INT NULL,

        no_ejer_acc_pnal INT NULL,
        otra INT NULL,

        dic TINYINT NULL,

        id_banci_carga_ultima BIGINT NULL,

        id_usuario_registro INT NOT NULL,
        id_usuario_modificacion INT NOT NULL,

        fecha_registro DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_carpeta_fecha_registro
            DEFAULT (SYSDATETIME()),

        fecha_modificacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_carpeta_fecha_modificacion
            DEFAULT (SYSDATETIME()),

        activo BIT NOT NULL
            CONSTRAINT DF_banci_carpeta_activo DEFAULT (1),

        CONSTRAINT PK_banci_carpeta_investigacion
            PRIMARY KEY (id_banci_carpeta_investigacion),

        CONSTRAINT UQ_banci_carpeta_entidad_ci
            UNIQUE
            (
                id_entidad_federativa,
                id_ci
            ),

        CONSTRAINT FK_banci_carpeta_entidad
            FOREIGN KEY (id_entidad_federativa)
            REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),

        CONSTRAINT FK_banci_carpeta_carga
            FOREIGN KEY (id_banci_carga_ultima)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT FK_banci_carpeta_usuario_registro
            FOREIGN KEY (id_usuario_registro)
            REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT FK_banci_carpeta_usuario_modificacion
            FOREIGN KEY (id_usuario_modificacion)
            REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT CK_banci_carpeta_conteos
            CHECK
            (
                (ord_apreh IS NULL OR ord_apreh >= 0)
                AND (fgran IS NULL OR fgran >= 0)
                AND (ctaon IS NULL OR ctaon >= 0)
                AND (td_v_ap IS NULL OR td_v_ap >= 0)
                AND (proc_abrev IS NULL OR proc_abrev >= 0)
                AND (juc_oral IS NULL OR juc_oral >= 0)
                AND (td_sen_con IS NULL OR td_sen_con >= 0)
                AND (no_ejer_acc_pnal IS NULL OR no_ejer_acc_pnal >= 0)
                AND (otra IS NULL OR otra >= 0)
            )
    );

    /* ============================================================
       TABLA VIVA - DELITOS
       ============================================================ */

    CREATE TABLE dbo.banci_delito
    (
        id_banci_delito BIGINT IDENTITY(1,1) NOT NULL,
        id_banci_carpeta_investigacion BIGINT NOT NULL,

        id_delito NVARCHAR(250) NOT NULL,

        dto NVARCHAR(500) NOT NULL,
        moda_dto NVARCHAR(2000) NULL,

        forma_acc TINYINT NULL,

        fha_de_hchos DATE NULL,
        hra_de_hchos TIME(0) NULL,

        emto_com_dto TINYINT NULL,
        grdo_cons TINYINT NULL,

        clasf_de_dto NVARCHAR(10) NOT NULL,

        nom_ent_hchos NVARCHAR(100) NULL,
        id_ent_hchos TINYINT NULL,

        nom_mun_hchos NVARCHAR(250) NULL,
        id_mun_hchos NVARCHAR(5) NULL,

        nom_loc_hchos NVARCHAR(500) NULL,
        id_loc_hchos NVARCHAR(250) NULL,

        nom_col_hchos NVARCHAR(500) NULL,
        id_col_hchos NVARCHAR(250) NULL,

        cp NVARCHAR(10) NULL,

        coord_x DECIMAL(10,6) NULL,
        coord_y DECIMAL(10,6) NULL,

        dom_hchos NVARCHAR(MAX) NULL,

        id_banci_carga_ultima BIGINT NULL,

        id_usuario_registro INT NOT NULL,
        id_usuario_modificacion INT NOT NULL,

        fecha_registro DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_delito_fecha_registro
            DEFAULT (SYSDATETIME()),

        fecha_modificacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_delito_fecha_modificacion
            DEFAULT (SYSDATETIME()),

        activo BIT NOT NULL
            CONSTRAINT DF_banci_delito_activo DEFAULT (1),

        CONSTRAINT PK_banci_delito
            PRIMARY KEY (id_banci_delito),

        CONSTRAINT UQ_banci_delito_carpeta_delito
            UNIQUE
            (
                id_banci_carpeta_investigacion,
                id_delito
            ),

        CONSTRAINT FK_banci_delito_carpeta
            FOREIGN KEY (id_banci_carpeta_investigacion)
            REFERENCES dbo.banci_carpeta_investigacion(id_banci_carpeta_investigacion),

        CONSTRAINT FK_banci_delito_clasificacion
            FOREIGN KEY (clasf_de_dto)
            REFERENCES dbo.banci_catalogo_clasificacion_delito(clave),

        CONSTRAINT FK_banci_delito_forma_accion
            FOREIGN KEY (forma_acc)
            REFERENCES dbo.catalogo_forma_accion(clave),

        CONSTRAINT FK_banci_delito_instrumento
            FOREIGN KEY (emto_com_dto)
            REFERENCES dbo.catalogo_instrumento_comision(clave),

        CONSTRAINT FK_banci_delito_grado
            FOREIGN KEY (grdo_cons)
            REFERENCES dbo.catalogo_grado_consumacion(clave),

        CONSTRAINT FK_banci_delito_entidad_hechos
            FOREIGN KEY (id_ent_hchos)
            REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),

        CONSTRAINT FK_banci_delito_municipio_hechos
            FOREIGN KEY
            (
                id_ent_hchos,
                id_mun_hchos
            )
            REFERENCES dbo.catalogo_municipio
            (
                id_entidad_federativa,
                clave
            ),

        CONSTRAINT FK_banci_delito_carga
            FOREIGN KEY (id_banci_carga_ultima)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT FK_banci_delito_usuario_registro
            FOREIGN KEY (id_usuario_registro)
            REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT FK_banci_delito_usuario_modificacion
            FOREIGN KEY (id_usuario_modificacion)
            REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT CK_banci_delito_forma_accion
            CHECK
            (
                forma_acc IS NULL
                OR forma_acc IN (1, 2, 3)
            ),

        CONSTRAINT CK_banci_delito_instrumento
            CHECK
            (
                emto_com_dto IS NULL
                OR emto_com_dto BETWEEN 1 AND 8
            ),

        CONSTRAINT CK_banci_delito_grado
            CHECK
            (
                grdo_cons IS NULL
                OR grdo_cons IN (1, 2)
            )
    );

    /* ============================================================
       TABLA VIVA - VÍCTIMAS
       ============================================================ */

    CREATE TABLE dbo.banci_victima
    (
        id_banci_victima BIGINT IDENTITY(1,1) NOT NULL,
        id_banci_delito BIGINT NOT NULL,

        id_vicf NVARCHAR(250) NOT NULL,
        id_tv TINYINT NULL,
        id_tpm TINYINT NULL,

        sexo TINYINT NULL,
        genero TINYINT NULL,
        pob TINYINT NULL,
        disc TINYINT NULL,

        fha_nac DATE NULL,
        edad SMALLINT NULL,

        nacional NVARCHAR(5) NULL,

        no_banci BIGINT NULL,

        folio_fotovolante NVARCHAR(250) NULL,
        folio_rnpdno NVARCHAR(250) NULL,

        pro_apellido NVARCHAR(250) NULL,
        sdo_apellido NVARCHAR(250) NULL,
        nomb NVARCHAR(500) NULL,

        entidad_nacimiento NVARCHAR(250) NULL,
        estado_migratorio NVARCHAR(500) NULL,

        curp NVARCHAR(50) NULL,
        rfc NVARCHAR(13) NULL,

        fecha_ultimo_contacto DATE NULL,
        hora_ultimo_contacto TIME(0) NULL,

        entidad_visto NVARCHAR(250) NULL,
        municipio_visto NVARCHAR(250) NULL,

        lugar_ultimo_contacto NVARCHAR(MAX) NULL,

        senas_tatuaje_datos_identificacion NVARCHAR(MAX) NULL,

        localizado_o_no_localizado TINYINT NULL,
        con_o_sin_vida TINYINT NULL,
        fecha_localizacion DATE NULL,

        voluntaria TINYINT NULL,
        fue_delito TINYINT NULL,

        delito NVARCHAR(1000) NULL,
        obs NVARCHAR(MAX) NULL,

        id_banci_carga_ultima BIGINT NULL,

        id_usuario_registro INT NOT NULL,
        id_usuario_modificacion INT NOT NULL,

        fecha_registro DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_victima_fecha_registro
            DEFAULT (SYSDATETIME()),

        fecha_modificacion DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_victima_fecha_modificacion
            DEFAULT (SYSDATETIME()),

        activo BIT NOT NULL
            CONSTRAINT DF_banci_victima_activo DEFAULT (1),

        CONSTRAINT PK_banci_victima
            PRIMARY KEY (id_banci_victima),

        CONSTRAINT UQ_banci_victima_delito_vicf
            UNIQUE
            (
                id_banci_delito,
                id_vicf
            ),

        CONSTRAINT FK_banci_victima_delito
            FOREIGN KEY (id_banci_delito)
            REFERENCES dbo.banci_delito(id_banci_delito),

        CONSTRAINT FK_banci_victima_sexo
            FOREIGN KEY (sexo)
            REFERENCES dbo.catalogo_sexo(clave),

        CONSTRAINT FK_banci_victima_genero
            FOREIGN KEY (genero)
            REFERENCES dbo.catalogo_genero(clave),

        CONSTRAINT FK_banci_victima_nacionalidad
            FOREIGN KEY (nacional)
            REFERENCES dbo.catalogo_nacionalidad(clave),

        CONSTRAINT FK_banci_victima_localizacion
            FOREIGN KEY (localizado_o_no_localizado)
            REFERENCES dbo.banci_catalogo_localizacion(clave),

        CONSTRAINT FK_banci_victima_condicion_vida
            FOREIGN KEY (con_o_sin_vida)
            REFERENCES dbo.banci_catalogo_condicion_vida(clave),

        CONSTRAINT FK_banci_victima_voluntaria
            FOREIGN KEY (voluntaria)
            REFERENCES dbo.banci_catalogo_voluntaria(clave),

        CONSTRAINT FK_banci_victima_fue_delito
            FOREIGN KEY (fue_delito)
            REFERENCES dbo.banci_catalogo_fue_delito(clave),

        CONSTRAINT FK_banci_victima_carga
            FOREIGN KEY (id_banci_carga_ultima)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT FK_banci_victima_usuario_registro
            FOREIGN KEY (id_usuario_registro)
            REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT FK_banci_victima_usuario_modificacion
            FOREIGN KEY (id_usuario_modificacion)
            REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT CK_banci_victima_sexo
            CHECK
            (
                sexo IS NULL
                OR sexo IN (1, 2)
            ),

        CONSTRAINT CK_banci_victima_genero
            CHECK
            (
                genero IS NULL
                OR genero IN (1, 2, 3)
            ),

        CONSTRAINT CK_banci_victima_pob
            CHECK
            (
                pob IS NULL
                OR pob IN (0, 1)
            ),

        CONSTRAINT CK_banci_victima_disc
            CHECK
            (
                disc IS NULL
                OR disc IN (0, 1)
            ),

        CONSTRAINT CK_banci_victima_localizacion
            CHECK
            (
                localizado_o_no_localizado IS NULL
                OR localizado_o_no_localizado IN (1, 2)
            ),

        CONSTRAINT CK_banci_victima_condicion_vida
            CHECK
            (
                con_o_sin_vida IS NULL
                OR con_o_sin_vida IN (1, 2)
            ),

        CONSTRAINT CK_banci_victima_voluntaria
            CHECK
            (
                voluntaria IS NULL
                OR voluntaria IN (1, 2)
            ),

        CONSTRAINT CK_banci_victima_fue_delito
            CHECK
            (
                fue_delito IS NULL
                OR fue_delito IN (1, 2)
            )
    );

    /* ============================================================
       AUDITORÍA CAMPO POR CAMPO
       ============================================================ */

    CREATE TABLE dbo.banci_historial_cambio
    (
        id_banci_historial_cambio BIGINT IDENTITY(1,1) NOT NULL,

        tipo_registro NVARCHAR(20) NOT NULL,
        id_registro BIGINT NOT NULL,

        id_entidad_federativa TINYINT NOT NULL,

        id_ci NVARCHAR(250) NOT NULL,
        id_delito NVARCHAR(250) NULL,
        id_vicf NVARCHAR(250) NULL,
        no_banci BIGINT NULL,

        tipo_movimiento NVARCHAR(30) NOT NULL,

        campo NVARCHAR(150) NULL,
        valor_anterior NVARCHAR(MAX) NULL,
        valor_nuevo NVARCHAR(MAX) NULL,

        origen NVARCHAR(40) NOT NULL,

        id_banci_carga BIGINT NULL,
        id_usuario INT NOT NULL,

        fecha_cambio DATETIME2(0) NOT NULL
            CONSTRAINT DF_banci_historial_fecha
            DEFAULT (SYSDATETIME()),

        CONSTRAINT PK_banci_historial_cambio
            PRIMARY KEY (id_banci_historial_cambio),

        CONSTRAINT FK_banci_historial_entidad
            FOREIGN KEY (id_entidad_federativa)
            REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),

        CONSTRAINT FK_banci_historial_carga
            FOREIGN KEY (id_banci_carga)
            REFERENCES dbo.banci_carga(id_banci_carga),

        CONSTRAINT FK_banci_historial_usuario
            FOREIGN KEY (id_usuario)
            REFERENCES dbo.usuario(id_usuario),

        CONSTRAINT CK_banci_historial_tipo_registro
            CHECK
            (
                tipo_registro IN
                (
                    N'CARPETA',
                    N'DELITO',
                    N'VICTIMA'
                )
            ),

        CONSTRAINT CK_banci_historial_movimiento
            CHECK
            (
                tipo_movimiento IN
                (
                    N'ALTA',
                    N'MODIFICACION',
                    N'CORRECCION_LLAVE'
                )
            ),

        CONSTRAINT CK_banci_historial_origen
            CHECK
            (
                origen IN
                (
                    N'CARGA_MASIVA',
                    N'FORMULARIO',
                    N'EDICION_MANUAL',
                    N'COMPLEMENTO_CONSOLIDADO'
                )
            )
    );

    /* ============================================================
       ÍNDICES
       ============================================================ */

    CREATE INDEX IX_banci_carga_entidad_fecha_estado
        ON dbo.banci_carga
        (
            id_entidad_federativa,
            fecha_carga,
            estado,
            activo
        );

    CREATE INDEX IX_banci_carga_archivo_carga
        ON dbo.banci_carga_archivo
        (
            id_banci_carga,
            tipo_archivo,
            activo
        );

    CREATE INDEX IX_banci_observacion_carga
        ON dbo.banci_carga_observacion
        (
            id_banci_carga,
            severidad,
            tipo_registro,
            numero_fila
        );

    CREATE INDEX IX_banci_tmp_carpeta_carga_ci
        ON dbo.banci_carga_tmp_carpeta
        (
            id_banci_carga,
            id_ci,
            estado
        );

    CREATE INDEX IX_banci_tmp_delito_carga_ci_delito
        ON dbo.banci_carga_tmp_delito
        (
            id_banci_carga,
            id_ci,
            id_delito,
            estado
        );

    CREATE INDEX IX_banci_tmp_victima_carga_ci_delito_vicf
        ON dbo.banci_carga_tmp_victima
        (
            id_banci_carga,
            id_ci,
            id_delito,
            id_vicf,
            estado
        );

    CREATE INDEX IX_banci_carpeta_periodo
        ON dbo.banci_carpeta_investigacion
        (
            id_entidad_federativa,
            fha_de_ini,
            activo
        )
        INCLUDE
        (
            id_ci,
            ntra_ci
        );

    CREATE INDEX IX_banci_delito_clasificacion
        ON dbo.banci_delito
        (
            clasf_de_dto,
            activo,
            id_banci_carpeta_investigacion
        )
        INCLUDE
        (
            id_delito
        );

    CREATE INDEX IX_banci_delito_hechos
        ON dbo.banci_delito
        (
            id_ent_hchos,
            id_mun_hchos,
            activo
        );

    CREATE UNIQUE INDEX UX_banci_victima_no_banci
        ON dbo.banci_victima(no_banci) WHERE no_banci IS NOT NULL;

    CREATE INDEX IX_banci_victima_localizacion
        ON dbo.banci_victima
        (
            localizado_o_no_localizado,
            activo,
            id_banci_delito
        );

    CREATE INDEX IX_banci_historial_registro_fecha
        ON dbo.banci_historial_cambio
        (
            tipo_registro,
            id_registro,
            fecha_cambio DESC
        );

    CREATE INDEX IX_banci_historial_llaves
        ON dbo.banci_historial_cambio
        (
            id_entidad_federativa,
            id_ci,
            id_delito,
            id_vicf
        );

    COMMIT TRANSACTION;

    PRINT 'Estructura base del módulo BANCI creada correctamente.';
    PRINT 'El módulo BANCI permanece DESACTIVADO.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
GO
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/03_20260914_04_procesar_carga_banci.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
-- Definiciones completas para instalaciones nuevas con el script 01 actualizado.
-- En una base existente ejecutar únicamente el incremental 10, que ya incluye ambos SP.
CREATE OR ALTER PROCEDURE dbo.sp_banci_procesar_carga
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

    IF @IdEntidad IS NULL THROW 52200, 'No existe la carga BANCI indicada.', 1;

    -- Sólo se integra dentro de la decisión atómica de sp_banci_confirmar_carga.
    IF @@TRANCOUNT = 0 OR XACT_STATE() <> 1
        THROW 52420, 'La integración BANCI requiere una transacción de confirmación activa.', 1;

    DECLARE @Recurso NVARCHAR(255) = CONCAT(N'BANCI:ENTIDAD:', @IdEntidad);
    IF ISNULL(APPLOCK_MODE(N'public', @Recurso, N'Transaction'), N'NoLock') <> N'Exclusive'
        THROW 52421, 'La integración BANCI requiere el bloqueo de confirmación por entidad.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_carga WITH (UPDLOCK, HOLDLOCK)
        WHERE id_banci_carga = @IdBanciCarga
          AND activo = 1
          AND estado = N'PROCESANDO'
          AND aceptada_usuario = 1
          AND id_usuario_confirmacion = @IdUsuario
          AND id_usuario_carga = @IdUsuario
          AND fecha_confirmacion IS NOT NULL
    )
        THROW 52422, 'La carga BANCI no tiene una aceptación válida para integrar.', 1;

    -- Verificar que el staging completo sigue disponible antes de tocar datos vivos.
    IF EXISTS
    (
        SELECT 1 FROM dbo.banci_carga c
        WHERE c.id_banci_carga = @IdBanciCarga
          AND
          (
              c.total_errores <> 0 OR c.total_carpetas <= 0 OR c.total_delitos <= 0 OR c.total_victimas <= 0
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N'PENDIENTE')
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_delito t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N'PENDIENTE')
              OR EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado <> N'PENDIENTE')
              OR c.total_carpetas <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_carpeta t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N'PENDIENTE')
              OR c.total_delitos <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_delito t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N'PENDIENTE')
              OR c.total_victimas <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_tmp_victima t WHERE t.id_banci_carga = c.id_banci_carga AND t.activo = 1 AND t.estado = N'PENDIENTE')
              OR c.total_advertencias <> (SELECT COUNT_BIG(*) FROM dbo.banci_carga_observacion o WHERE o.id_banci_carga = c.id_banci_carga AND o.activo = 1 AND o.severidad = N'ADVERTENCIA')
          )
    )
        THROW 52423, 'Los temporales u observaciones BANCI no coinciden con la carga validada.', 1;

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

    IF @EmitirResultado = 1
    SELECT
        @IdBanciCarga AS id_banci_carga,
        @Altas AS total_altas,
        @Actualizaciones AS total_actualizaciones,
        @SinCambio AS total_sin_cambio;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_banci_confirmar_carga
    @CodigoReferencia NVARCHAR(50),
    @Aceptar BIT,
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- El procedimiento es dueño de la transacción. La API lo llama sin otra transacción.
    IF @@TRANCOUNT <> 0
        THROW 52400, 'Ejecute la decisión BANCI sin una transacción externa abierta.', 1;
    IF @Aceptar IS NULL OR @IdUsuario IS NULL OR @IdUsuario <= 0 OR NULLIF(LTRIM(RTRIM(@CodigoReferencia)), N'') IS NULL
        THROW 52401, 'Debe indicar referencia, usuario y decisión BANCI.', 1;

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
            THROW 52402, 'No existe una carga BANCI disponible para esa referencia.', 1;

        -- Misma entidad: serializa también dos referencias distintas con llaves coincidentes.
        SET @Recurso = CONCAT(N'BANCI:ENTIDAD:', @IdEntidad);
        EXEC @Bloqueo = sys.sp_getapplock
            @Resource = @Recurso,
            @LockMode = N'Exclusive',
            @LockOwner = N'Transaction',
            @LockTimeout = 10000,
            @DbPrincipal = N'public';

        IF @Bloqueo < 0
            THROW 52403, 'Hay otra integración BANCI en curso para la entidad. Reintente la misma referencia.', 1;

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
            THROW 52404, 'Sólo el usuario que preparó la carga puede aceptar o rechazar esta referencia.', 1;

        -- Se comprueba nuevamente el acceso; no basta con haber validado anteriormente.
        -- BANCI hereda membresía MENSUAL, no sus switches de carga/modificación.
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.usuario u WITH (HOLDLOCK)
            INNER JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
            INNER JOIN dbo.catalogo_modulo mensual WITH (HOLDLOCK) ON mensual.clave = N'MENSUAL' AND mensual.activo = 1
            INNER JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = mensual.id_modulo AND um.habilitado = 1 AND um.activo = 1
            INNER JOIN dbo.catalogo_modulo banci WITH (HOLDLOCK) ON banci.clave = N'BANCI' AND banci.activo = 1
            WHERE u.id_usuario = @IdUsuario AND u.activo = 1
              AND (r.rol = N'SUPER_USUARIO' OR u.id_entidad_federativa = @IdEntidad)
        )
            THROW 52405, 'El usuario ya no tiene acceso BANCI vigente para la entidad de esta carga.', 1;

        IF @Estado IN (N'PROCESADO', N'PROCESADO_CON_ADVERTENCIAS')
        BEGIN
            IF @Aceptar = 0
                THROW 52406, 'Una carga integrada no puede rechazarse.', 1;
            IF @AceptadaAnterior IS NULL OR @AceptadaAnterior <> 1
                THROW 52407, 'La carga pertenece al flujo anterior y ya está procesada. No se modifica su decisión histórica.', 1;
            SET @YaResuelta = 1;
            SET @Mensaje = N'La carga BANCI ya estaba integrada. Se devuelve el resultado existente sin procesar nuevamente.';
        END
        ELSE IF @Estado = N'RECHAZADO_VALIDACION'
        BEGIN
            IF @Aceptar = 1
                THROW 52408, 'Una carga rechazada no puede integrarse. Debe validar una nueva operación.', 1;
            SET @YaResuelta = 1;
            SET @Mensaje = N'La carga BANCI ya estaba rechazada. No se modificó la operación.';
        END
        ELSE
        BEGIN
            IF @Estado <> N'VALIDADO_PENDIENTE' OR @AceptadaAnterior IS NOT NULL
                THROW 52409, 'La carga BANCI no está pendiente de decisión.', 1;

            IF @Aceptar = 0
            BEGIN
                UPDATE dbo.banci_carga
                SET estado = N'RECHAZADO_VALIDACION',
                    aceptada_usuario = 0,
                    id_usuario_confirmacion = @IdUsuario,
                    fecha_confirmacion = SYSDATETIME(),
                    mensaje_error = NULL
                WHERE id_banci_carga = @IdBanciCarga;

                INSERT INTO dbo.banci_carga_bitacora_estado
                    (id_banci_carga, estado_anterior, estado_nuevo, id_usuario, comentario)
                VALUES
                    (@IdBanciCarga, @Estado, N'RECHAZADO_VALIDACION', @IdUsuario, N'El usuario rechazó la carga antes de integrar. Se conservan temporales y observaciones.');

                SET @Mensaje = N'La carga BANCI fue rechazada. No se integraron datos definitivos.';
            END
            ELSE
            BEGIN
                UPDATE dbo.banci_carga
                SET estado = N'PROCESANDO',
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
                    (@IdBanciCarga, @Estado, N'PROCESANDO', @IdUsuario, N'El usuario aceptó la carga y sus advertencias. Inicia integración atómica.');

                EXEC dbo.sp_banci_procesar_carga
                    @IdBanciCarga = @IdBanciCarga,
                    @IdUsuario = @IdUsuario,
                    @EmitirResultado = 0;

                SELECT @Estado = estado FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga;
                IF @Estado NOT IN (N'PROCESADO', N'PROCESADO_CON_ADVERTENCIAS')
                    THROW 52410, 'La integración BANCI no terminó correctamente. Se revierte la operación.', 1;

                INSERT INTO dbo.banci_carga_bitacora_estado
                    (id_banci_carga, estado_anterior, estado_nuevo, id_usuario, comentario)
                VALUES
                    (@IdBanciCarga, N'PROCESANDO', @Estado, @IdUsuario, N'Integración BANCI terminada. Los totales corresponden a los cambios aplicados.');

                SET @Mensaje = N'La carga BANCI fue aceptada e integrada correctamente.';
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
END;
GO
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/04_20260917_13_formulario_banci.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Ejecutar completo en SSMS en desarrollo primero; no requiere modo SQLCMD.
-- Requiere los scripts BANCI anteriores, incluido el 10. No modifica datos existentes.
IF @@TRANCOUNT <> 0 THROW 52431, 'Use una ventana sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sp_banci_confirmar_carga', N'P') IS NULL OR COL_LENGTH(N'dbo.banci_carga', N'aceptada_usuario') IS NULL
    THROW 52432, 'Aplique primero la confirmación BANCI (script 10).', 1;
BEGIN TRY
    BEGIN TRANSACTION;
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
            AND h.tipo_registro = N''VICTIMA''
            AND h.tipo_movimiento = N''MODIFICACION''
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
    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_confirmar_carga
    @CodigoReferencia NVARCHAR(50),
    @Aceptar BIT,
    @IdUsuario INT
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
        -- BANCI hereda membresía MENSUAL, no sus switches de carga/modificación.
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.usuario u WITH (HOLDLOCK)
            INNER JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
            INNER JOIN dbo.catalogo_modulo mensual WITH (HOLDLOCK) ON mensual.clave = N''MENSUAL'' AND mensual.activo = 1
            INNER JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = mensual.id_modulo AND um.habilitado = 1 AND um.activo = 1
            INNER JOIN dbo.catalogo_modulo banci WITH (HOLDLOCK) ON banci.clave = N''BANCI'' AND banci.activo = 1
            WHERE u.id_usuario = @IdUsuario AND u.activo = 1
              AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad))
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
    COMMIT TRANSACTION;
    PRINT N'Formulario BANCI: alta protegida contra duplicados y confirmación restringida a usuarios de captura.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/05_20260918_14_vista_previa_banci.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- Aplicar después del script 13, primero en desarrollo. No activa BANCI ni modifica datos.
-- Instala la vista previa y exige su huella al aceptar; rechazo e idempotencia se conservan.
IF @@TRANCOUNT <> 0 THROW 52431, 'Use una ventana sin transacciones abiertas.', 1;
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_banci_procesar_carga')) NOT LIKE N'%52424%'
    OR OBJECT_ID(N'dbo.sp_banci_procesar_carga', N'P') IS NULL
    THROW 52432, 'Aplique primero el script 13 de formulario BANCI.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_vista_previa
    @CodigoReferencia NVARCHAR(50), @IdUsuario INT, @Huella VARCHAR(64) = NULL OUTPUT, @EmitirResultado BIT = 1
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
            INNER JOIN dbo.catalogo_modulo mensual WITH (HOLDLOCK) ON mensual.clave = N''MENSUAL'' AND mensual.activo = 1
            INNER JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = mensual.id_modulo AND um.habilitado = 1 AND um.activo = 1
            INNER JOIN dbo.catalogo_modulo banci WITH (HOLDLOCK) ON banci.clave = N''BANCI'' AND banci.activo = 1
            WHERE u.id_usuario = @IdUsuario AND u.activo = 1
              AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad))
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
            SELECT @Huella AS Huella, (SELECT COUNT(*) FROM #Cambios) AS TotalCambios;
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
        -- BANCI hereda membresía MENSUAL, no sus switches de carga/modificación.
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.usuario u WITH (HOLDLOCK)
            INNER JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
            INNER JOIN dbo.catalogo_modulo mensual WITH (HOLDLOCK) ON mensual.clave = N''MENSUAL'' AND mensual.activo = 1
            INNER JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = mensual.id_modulo AND um.habilitado = 1 AND um.activo = 1
            INNER JOIN dbo.catalogo_modulo banci WITH (HOLDLOCK) ON banci.clave = N''BANCI'' AND banci.activo = 1
            WHERE u.id_usuario = @IdUsuario AND u.activo = 1
              AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad))
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
                DECLARE @HuellaActual VARCHAR(64);
                EXEC dbo.sp_banci_vista_previa @CodigoReferencia = @CodigoReferencia, @IdUsuario = @IdUsuario, @Huella = @HuellaActual OUTPUT, @EmitirResultado = 0;
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
    COMMIT TRANSACTION;
    PRINT N'Vista previa BANCI instalada. Publique API y front compatibles antes de aceptar nuevas cargas.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/06_20260918_15_usuarios_banci.sql
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
    -- Publicación inicial: se omite la asignación masiva de permisos en otros módulos.
    COMMIT TRANSACTION;
    SELECT m.clave, u.usuario, r.rol, um.habilitado, um.habilita_carga, um.habilita_modificacion, um.activo
    FROM dbo.usuario_modulo um INNER JOIN dbo.usuario u ON u.id_usuario = um.id_usuario INNER JOIN dbo.roles r ON r.id_rol = u.id_rol
    INNER JOIN dbo.catalogo_modulo m ON m.id_modulo = um.id_modulo WHERE m.clave = N'BANCI' ORDER BY r.rol, u.usuario;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/07_20260922_16_estructura_banci_v2.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- BANCI V2 / estructura_banci_v2. Ejecutar completo en desarrollo, sin modo SQLCMD.
IF DB_NAME() <> N'siiid2' THROW 52500, 'Base de datos incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52500, 'Use una ventana sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sp_banci_vista_previa', N'P') IS NULL OR OBJECT_ID(N'dbo.banci_historial_cambio', N'U') IS NULL
    THROW 52500, 'Requiere la instalación BANCI hasta el script 15.', 1;
IF (SELECT compatibility_level FROM sys.databases WHERE database_id = DB_ID()) < 130 THROW 52500, 'Se requiere compatibilidad SQL 130 o superior.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @BloqueoMigracion INT;
    EXEC @BloqueoMigracion = sys.sp_getapplock @Resource = N'BANCI:MIGRACION:V2', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @BloqueoMigracion < 0 THROW 52500, 'Hay otra migración BANCI en curso.', 1;
EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.banci_consecutivo_carpeta'', N''U'') IS NULL
CREATE TABLE dbo.banci_consecutivo_carpeta (
    id_entidad_federativa TINYINT NOT NULL, anio SMALLINT NOT NULL, ultimo INT NOT NULL,
    CONSTRAINT PK_banci_consecutivo_carpeta PRIMARY KEY (id_entidad_federativa, anio),
    CONSTRAINT CK_banci_consecutivo_carpeta CHECK (id_entidad_federativa BETWEEN 1 AND 32 AND anio BETWEEN 1900 AND 9999 AND ultimo BETWEEN 0 AND 999999),
    CONSTRAINT FK_banci_consecutivo_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa)
);';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_carpeta_investigacion'', N''no_banci'') IS NULL ALTER TABLE dbo.banci_carpeta_investigacion ADD no_banci NVARCHAR(40) NULL;';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_carga_tmp_carpeta'', N''no_banci'') IS NULL ALTER TABLE dbo.banci_carga_tmp_carpeta ADD no_banci NVARCHAR(100) NULL;';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_carga'', N''version_formato'') IS NULL ALTER TABLE dbo.banci_carga ADD version_formato TINYINT NOT NULL CONSTRAINT DF_banci_carga_version_formato DEFAULT (1);';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_victima'', N''voluntaria_o_fue_delito'') IS NULL ALTER TABLE dbo.banci_victima ADD voluntaria_o_fue_delito TINYINT NULL;';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_victima'', N''acciones_busqueda'') IS NULL ALTER TABLE dbo.banci_victima ADD acciones_busqueda NVARCHAR(MAX) NULL;';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_victima'', N''version_banci'') IS NULL ALTER TABLE dbo.banci_victima ADD version_banci ROWVERSION;';

EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.banci_catalogo_motivo_localizacion'', N''U'') IS NULL
CREATE TABLE dbo.banci_catalogo_motivo_localizacion (clave TINYINT NOT NULL CONSTRAINT PK_banci_motivo_localizacion PRIMARY KEY, descripcion NVARCHAR(100) NOT NULL, activo BIT NOT NULL CONSTRAINT DF_banci_motivo_activo DEFAULT (1), CONSTRAINT CK_banci_motivo_clave CHECK (clave IN (1, 2, 3)));
INSERT INTO dbo.banci_catalogo_motivo_localizacion (clave, descripcion)
SELECT v.clave, v.descripcion FROM (VALUES (1, N''Voluntaria''), (2, N''Delito''), (3, N''No identificado'')) v(clave, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM dbo.banci_catalogo_motivo_localizacion c WHERE c.clave = v.clave);
IF EXISTS (SELECT 1 FROM dbo.banci_catalogo_motivo_localizacion WHERE (clave = 1 AND descripcion <> N''Voluntaria'') OR (clave = 2 AND descripcion <> N''Delito'') OR (clave = 3 AND descripcion <> N''No identificado'') OR activo <> 1)
    THROW 52505, ''El catálogo de motivo de localización difiere de las claves acordadas.'', 1;';

EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.FK_banci_victima_motivo_localizacion'', N''F'') IS NULL ALTER TABLE dbo.banci_victima WITH CHECK ADD CONSTRAINT FK_banci_victima_motivo_localizacion FOREIGN KEY (voluntaria_o_fue_delito) REFERENCES dbo.banci_catalogo_motivo_localizacion(clave);';

EXEC sys.sp_executesql N'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N''dbo.banci_carpeta_investigacion'') AND name = N''UX_banci_carpeta_no_banci'') CREATE UNIQUE INDEX UX_banci_carpeta_no_banci ON dbo.banci_carpeta_investigacion(no_banci) WHERE no_banci IS NOT NULL;';

EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_asignar_folios_v2 @IdEntidad TINYINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Interno: la integración o la migración son dueñas de la transacción.
    IF @@TRANCOUNT = 0 OR XACT_STATE() <> 1 THROW 52501, ''Asignar folios requiere una transacción activa.'', 1;
    DECLARE @Lock INT;
    EXEC @Lock = sys.sp_getapplock @Resource = N''BANCI:FOLIOS:V2'', @LockMode = N''Exclusive'', @LockOwner = N''Transaction'', @LockTimeout = 10000;
    IF @Lock < 0 THROW 52502, ''No se pudo reservar el consecutivo BANCI.'', 1;
    SELECT c.id_banci_carpeta_investigacion AS id, c.id_entidad_federativa AS entidad, YEAR(c.fecha_registro) AS anio,
        ROW_NUMBER() OVER (PARTITION BY c.id_entidad_federativa, YEAR(c.fecha_registro) ORDER BY c.id_banci_carpeta_investigacion) AS numero
    INTO #Asignar
    FROM dbo.banci_carpeta_investigacion c WITH (UPDLOCK, HOLDLOCK)
    WHERE c.no_banci IS NULL AND (@IdEntidad IS NULL OR c.id_entidad_federativa = @IdEntidad);
    IF EXISTS (SELECT 1 FROM #Asignar WHERE entidad NOT BETWEEN 1 AND 32 OR anio NOT BETWEEN 1900 AND 9999)
        THROW 52503, ''Entidad o año de registro inválido para asignar el folio.'', 1;
    INSERT INTO dbo.banci_consecutivo_carpeta (id_entidad_federativa, anio, ultimo)
    SELECT entidad, anio, 0 FROM #Asignar a
    WHERE NOT EXISTS (SELECT 1 FROM dbo.banci_consecutivo_carpeta n WITH (UPDLOCK, HOLDLOCK) WHERE n.id_entidad_federativa = a.entidad AND n.anio = a.anio)
    GROUP BY entidad, anio;
    IF EXISTS (SELECT 1 FROM #Asignar a JOIN dbo.banci_consecutivo_carpeta n ON n.id_entidad_federativa = a.entidad AND n.anio = a.anio WHERE a.numero + n.ultimo > 999999)
        THROW 52504, ''Se agotaron los seis dígitos del consecutivo BANCI para entidad/año.'', 1;
    UPDATE c SET no_banci = CONCAT(N''BANCI/'', RIGHT(N''00'' + CONVERT(NVARCHAR(2), a.entidad), 2), N''/'', a.anio, N''/'', RIGHT(N''000000'' + CONVERT(NVARCHAR(6), a.numero + n.ultimo), 6))
    FROM dbo.banci_carpeta_investigacion c JOIN #Asignar a ON a.id = c.id_banci_carpeta_investigacion
    JOIN dbo.banci_consecutivo_carpeta n ON n.id_entidad_federativa = a.entidad AND n.anio = a.anio;
    UPDATE n SET ultimo = n.ultimo + x.total FROM dbo.banci_consecutivo_carpeta n
    JOIN (SELECT entidad, anio, COUNT(*) AS total FROM #Asignar GROUP BY entidad, anio) x ON x.entidad = n.id_entidad_federativa AND x.anio = n.anio;
END;';

EXEC sys.sp_executesql N'EXEC dbo.sp_banci_asignar_folios_v2;';

EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_delito_localizacion_catalogo AS
SELECT clave2 AS clave, delito AS descripcion FROM dbo.catalogo_delito WHERE activo = 1;';

EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_victimas_v2 AS
SELECT c.id_entidad_federativa, c.no_banci, c.id_ci, c.ntra_ci, c.fha_de_ini,
    c.id_banci_carpeta_investigacion, d.id_banci_delito, d.id_delito, v.id_banci_victima, v.id_vicf,
    v.id_tv, v.id_tpm, v.sexo, v.genero, v.pob, v.disc, v.fha_nac, v.edad, v.nacional,
    v.folio_rnpdno, v.pro_apellido, v.sdo_apellido, v.nomb, v.entidad_nacimiento, v.estado_migratorio, v.curp, v.rfc,
    v.localizado_o_no_localizado, v.con_o_sin_vida, v.fecha_localizacion, v.voluntaria_o_fue_delito, v.delito, v.acciones_busqueda, v.obs,
    v.version_banci, v.fecha_modificacion
FROM dbo.banci_carpeta_investigacion c JOIN dbo.banci_delito d ON d.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion
JOIN dbo.banci_victima v ON v.id_banci_delito = d.id_banci_delito WHERE c.activo = 1 AND d.activo = 1 AND v.activo = 1;';

EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.banci_actualizacion_v2'', N''U'') IS NULL
CREATE TABLE dbo.banci_actualizacion_v2 (
    id_actualizacion BIGINT IDENTITY NOT NULL CONSTRAINT PK_banci_actualizacion_v2 PRIMARY KEY,
    codigo_referencia UNIQUEIDENTIFIER NOT NULL CONSTRAINT UQ_banci_actualizacion_v2_referencia UNIQUE,
    id_entidad_federativa TINYINT NOT NULL, id_usuario INT NOT NULL, origen NVARCHAR(20) NOT NULL,
    datos_json NVARCHAR(MAX) NOT NULL, advertencias_json NVARCHAR(MAX) NOT NULL,
    estado NVARCHAR(20) NOT NULL CONSTRAINT DF_banci_actualizacion_v2_estado DEFAULT N''PENDIENTE'',
    fecha_registro DATETIME2(7) NOT NULL CONSTRAINT DF_banci_actualizacion_v2_fecha DEFAULT SYSDATETIME(),
    fecha_decision DATETIME2(7) NULL, total_cambios INT NULL,
    CONSTRAINT CK_banci_actualizacion_v2_json CHECK (ISJSON(datos_json) = 1 AND ISJSON(advertencias_json) = 1),
    CONSTRAINT CK_banci_actualizacion_v2_estado CHECK (estado IN (N''PENDIENTE'', N''INTEGRADA'', N''RECHAZADA'')),
    CONSTRAINT CK_banci_actualizacion_v2_origen CHECK (origen IN (N''FORMULARIO'', N''EXCEL'')),
    CONSTRAINT FK_banci_actualizacion_v2_entidad FOREIGN KEY (id_entidad_federativa) REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),
    CONSTRAINT FK_banci_actualizacion_v2_usuario FOREIGN KEY (id_usuario) REFERENCES dbo.usuario(id_usuario)
);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N''dbo.banci_actualizacion_v2'') AND name = N''IX_banci_actualizacion_v2_usuario'')
CREATE INDEX IX_banci_actualizacion_v2_usuario ON dbo.banci_actualizacion_v2(id_usuario, estado, fecha_registro);';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_historial_cambio'', N''id_actualizacion_v2'') IS NULL ALTER TABLE dbo.banci_historial_cambio ADD id_actualizacion_v2 BIGINT NULL;';

EXEC sys.sp_executesql N'IF OBJECT_ID(N''dbo.FK_banci_historial_actualizacion_v2'', N''F'') IS NULL ALTER TABLE dbo.banci_historial_cambio WITH CHECK ADD CONSTRAINT FK_banci_historial_actualizacion_v2 FOREIGN KEY (id_actualizacion_v2) REFERENCES dbo.banci_actualizacion_v2(id_actualizacion);';

EXEC sys.sp_executesql N'IF COL_LENGTH(N''dbo.banci_historial_cambio'', N''no_banci_carpeta'') IS NULL ALTER TABLE dbo.banci_historial_cambio ADD no_banci_carpeta NVARCHAR(40) NULL;';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/08_20260922_17_carga_inicial_banci_v2.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- BANCI V2 / carga_inicial_banci_v2. Ejecutar completo en desarrollo, sin modo SQLCMD.
IF DB_NAME() <> N'siiid2' THROW 52500, 'Base de datos incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52500, 'Use una ventana sin transacciones abiertas.', 1;
IF COL_LENGTH(N'dbo.banci_carga', N'version_formato') IS NULL THROW 52500, 'Ejecute primero el script 16.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @BloqueoMigracion INT;
    EXEC @BloqueoMigracion = sys.sp_getapplock @Resource = N'BANCI:MIGRACION:V2', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @BloqueoMigracion < 0 THROW 52500, 'Hay otra migración BANCI en curso.', 1;
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


    IF NOT EXISTS (SELECT 1 FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga AND version_formato = 2)
        THROW 52510, ''Esta operación requiere una carga del formato BANCI v2.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(ntra_ci)), N'''') IS NULL)
        THROW 52511, ''NTRA_CI es obligatorio.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(folio_rnpdno)), N'''') IS NULL)
        THROW 52512, ''Folio RNPDNO es obligatorio para cada víctima.'', 1;
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
        folio_rnpdno = NULLIF(LTRIM(RTRIM(v.folio_rnpdno)), N''''),
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
        localizado_o_no_localizado = CAST(NULL AS TINYINT),
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
            AND h.tipo_registro = N''VICTIMA''
            AND h.tipo_movimiento = N''MODIFICACION''
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

    IF NOT EXISTS (SELECT 1 FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga AND version_formato = 2)
        THROW 52510, ''Esta operación requiere una carga del formato BANCI v2.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(ntra_ci)), N'''') IS NULL)
        THROW 52511, ''NTRA_CI es obligatorio.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(folio_rnpdno)), N'''') IS NULL)
        THROW 52512, ''Folio RNPDNO es obligatorio para cada víctima.'', 1;
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
        folio_rnpdno = NULLIF(LTRIM(RTRIM(v.folio_rnpdno)), N''''),
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
        localizado_o_no_localizado = CAST(NULL AS TINYINT),
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

EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_confirmar_carga_v2
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
                EXEC dbo.sp_banci_vista_previa_v2 @CodigoReferencia = @CodigoReferencia, @IdUsuario = @IdUsuario, @Huella = @HuellaActual OUTPUT, @EmitirResultado = 0, @PuedeAceptar = @PuedeAceptar OUTPUT;
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

                EXEC dbo.sp_banci_procesar_carga_v2
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

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/09_20260922_18_actualizacion_banci_v2.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- BANCI V2 / actualizacion_banci_v2. Ejecutar completo en desarrollo, sin modo SQLCMD.
IF DB_NAME() <> N'siiid2' THROW 52500, 'Base de datos incorrecta.', 1;
IF @@TRANCOUNT <> 0 THROW 52500, 'Use una ventana sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.banci_actualizacion_v2', N'U') IS NULL THROW 52500, 'Ejecute primero el script 16.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @BloqueoMigracion INT;
    EXEC @BloqueoMigracion = sys.sp_getapplock @Resource = N'BANCI:MIGRACION:V2', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @BloqueoMigracion < 0 THROW 52500, 'Hay otra migración BANCI en curso.', 1;
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
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j WHERE j.[key] COLLATE Latin1_General_100_BIN2 NOT IN (N''fila'',N''no_banci'',N''id_delito'',N''id_vicf'',N''folio_rnpdno'',N''pro_apellido'',N''sdo_apellido'',N''nomb'',N''entidad_nacimiento'',N''estado_migratorio'',N''curp'',N''rfc'',N''localizado_o_no_localizado'',N''con_o_sin_vida'',N''fecha_localizacion'',N''voluntaria_o_fue_delito'',N''delito'',N''acciones_busqueda'',N''obs''))
        THROW 52524, ''La actualización contiene columnas no permitidas.'', 1;
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j WHERE j.type NOT IN (0,1,2)) THROW 52524, ''Los campos deben ser texto, número o null.'', 1;
    SELECT f.indice, j.[key] COLLATE DATABASE_DEFAULT AS campo, NULLIF(LTRIM(RTRIM(j.value)), N'''') AS valor INTO #Valores FROM #Filas f CROSS APPLY OPENJSON(f.datos) j;
    IF EXISTS (SELECT 1 FROM #Valores WHERE (campo = N''no_banci'' AND DATALENGTH(valor) > 80) OR (campo = N''id_delito'' AND DATALENGTH(valor) > 500) OR (campo = N''id_vicf'' AND DATALENGTH(valor) > 500) OR (campo = N''folio_rnpdno'' AND DATALENGTH(valor) > 500) OR (campo = N''pro_apellido'' AND DATALENGTH(valor) > 500) OR (campo = N''sdo_apellido'' AND DATALENGTH(valor) > 500) OR (campo = N''nomb'' AND DATALENGTH(valor) > 1000) OR (campo = N''entidad_nacimiento'' AND DATALENGTH(valor) > 500) OR (campo = N''estado_migratorio'' AND DATALENGTH(valor) > 1000) OR (campo = N''curp'' AND DATALENGTH(valor) > 100) OR (campo = N''rfc'' AND DATALENGTH(valor) > 26) OR (campo = N''localizado_o_no_localizado'' AND DATALENGTH(valor) > 6) OR (campo = N''con_o_sin_vida'' AND DATALENGTH(valor) > 6) OR (campo = N''fecha_localizacion'' AND DATALENGTH(valor) > 20) OR (campo = N''voluntaria_o_fue_delito'' AND DATALENGTH(valor) > 6) OR (campo = N''delito'' AND DATALENGTH(valor) > 2000)) THROW 52525, ''Un campo supera su longitud permitida.'', 1;
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
        folio_rnpdno = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''folio_rnpdno'')),a.folio_rnpdno),
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
    IF EXISTS (SELECT 1 FROM #Propuesto WHERE NULLIF(LTRIM(RTRIM(folio_rnpdno)), N'''') IS NULL) THROW 52531, ''Folio RNPDNO es obligatorio; informe el folio faltante antes de actualizar.'', 1;
    SELECT a.id_banci_victima, a.fila, a.no_banci, a.id_ci, a.id_delito, a.id_vicf, x.campo, x.anterior, x.nuevo INTO #Cambios
    FROM #Actual a JOIN #Propuesto p ON p.id_banci_victima = a.id_banci_victima
    CROSS APPLY (VALUES (N''folio_rnpdno'',CONVERT(NVARCHAR(MAX),a.folio_rnpdno),CONVERT(NVARCHAR(MAX),p.folio_rnpdno)),
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

EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_preparar_actualizacion_v2
    @IdUsuario INT, @IdEntidad TINYINT, @Origen NVARCHAR(20), @DatosJson NVARCHAR(MAX), @AdvertenciasJson NVARCHAR(MAX) = N''[]''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 52520, ''Ejecute sin transacción externa.'', 1;
    IF @IdEntidad IS NULL OR @IdEntidad NOT BETWEEN 1 AND 32 OR @Origen IS NULL OR @Origen NOT IN (N''FORMULARIO'',N''EXCEL'') THROW 52524, ''Entidad u origen inválido.'', 1;
    IF @DatosJson IS NULL OR ISJSON(@DatosJson) <> 1 OR LEFT(LTRIM(@DatosJson),1) <> N''['' THROW 52524, ''Datos JSON inválidos.'', 1;
    IF @AdvertenciasJson IS NULL OR ISJSON(@AdvertenciasJson) <> 1 OR LEFT(LTRIM(@AdvertenciasJson),1) <> N''['' THROW 52524, ''Advertencias JSON inválidas.'', 1;
    IF @Origen = N''FORMULARIO'' AND (SELECT COUNT(*) FROM OPENJSON(@DatosJson)) <> 1 THROW 52524, ''El formulario actualiza una sola víctima.'', 1;
    DECLARE @Codigo UNIQUEIDENTIFIER = NEWID(), @Lock INT, @Huella VARCHAR(64), @Aplicar NVARCHAR(MAX), @Cambios NVARCHAR(MAX), @Recurso NVARCHAR(255) = CONCAT(N''BANCI:ENTIDAD:'',@IdEntidad);
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @Lock = sys.sp_getapplock @Resource = @Recurso, @LockMode = N''Shared'', @LockOwner = N''Transaction'', @LockTimeout = 10000;
        IF @Lock < 0 THROW 52522, ''Hay una integración en curso.'', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.usuario u WITH (HOLDLOCK)
    JOIN dbo.roles r WITH (HOLDLOCK) ON r.id_rol = u.id_rol AND r.activo = 1
    JOIN dbo.catalogo_modulo m WITH (HOLDLOCK) ON m.clave = N''BANCI'' AND m.activo = 1
    LEFT JOIN dbo.usuario_modulo um WITH (HOLDLOCK) ON um.id_usuario = u.id_usuario AND um.id_modulo = m.id_modulo AND um.activo = 1 AND um.habilitado = 1
    WHERE u.id_usuario = @IdUsuario AND u.activo = 1
      AND (r.rol = N''SUPER_USUARIO'' OR (r.rol = N''ENLACE_ESTATAL'' AND u.id_entidad_federativa = @IdEntidad AND um.id_usuario IS NOT NULL AND um.habilita_modificacion = 1))) THROW 52523, ''No tiene permiso de modificación BANCI para esta entidad.'', 1;
        INSERT INTO dbo.banci_actualizacion_v2(codigo_referencia,id_entidad_federativa,id_usuario,origen,datos_json,advertencias_json)
        VALUES (@Codigo,@IdEntidad,@IdUsuario,@Origen,@DatosJson,@AdvertenciasJson);
        EXEC dbo.sp_banci_calcular_actualizacion_v2 @Codigo,@IdUsuario,@Huella OUTPUT,@Aplicar OUTPUT,@Cambios OUTPUT;
        COMMIT TRANSACTION;
        SELECT @Codigo AS CodigoReferencia, N''PENDIENTE'' AS Estado, @Huella AS Huella, @Cambios AS CambiosJson, @Aplicar AS DatosPropuestosJson, @AdvertenciasJson AS AdvertenciasJson;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_vista_previa_actualizacion_v2 @CodigoReferencia UNIQUEIDENTIFIER, @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT <> 0 THROW 52520, ''Ejecute sin transacción externa.'', 1;
    DECLARE @IdEntidad TINYINT, @Lock INT, @Huella VARCHAR(64), @Aplicar NVARCHAR(MAX), @Cambios NVARCHAR(MAX), @Advertencias NVARCHAR(MAX);
    SELECT @IdEntidad = id_entidad_federativa FROM dbo.banci_actualizacion_v2 WHERE codigo_referencia = @CodigoReferencia AND id_usuario = @IdUsuario;
    IF @IdEntidad IS NULL THROW 52521, ''No existe una actualización disponible para el usuario.'', 1;
    DECLARE @Recurso NVARCHAR(255) = CONCAT(N''BANCI:ENTIDAD:'',@IdEntidad);
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @Lock = sys.sp_getapplock @Resource = @Recurso, @LockMode = N''Shared'', @LockOwner = N''Transaction'', @LockTimeout = 10000;
        IF @Lock < 0 THROW 52522, ''Hay una integración en curso.'', 1;
        EXEC dbo.sp_banci_calcular_actualizacion_v2 @CodigoReferencia,@IdUsuario,@Huella OUTPUT,@Aplicar OUTPUT,@Cambios OUTPUT;
        SELECT @Advertencias = advertencias_json FROM dbo.banci_actualizacion_v2 WHERE codigo_referencia = @CodigoReferencia;
        COMMIT TRANSACTION;
        SELECT @CodigoReferencia AS CodigoReferencia, N''PENDIENTE'' AS Estado, @Huella AS Huella, @Cambios AS CambiosJson, @Aplicar AS DatosPropuestosJson, @Advertencias AS AdvertenciasJson;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;';

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
            SELECT * INTO #Propuesto FROM OPENJSON(@Aplicar) WITH (id_banci_victima BIGINT, folio_rnpdno NVARCHAR(250), pro_apellido NVARCHAR(250), sdo_apellido NVARCHAR(250), nomb NVARCHAR(500), entidad_nacimiento NVARCHAR(250), estado_migratorio NVARCHAR(500), curp NVARCHAR(50), rfc NVARCHAR(13), localizado_o_no_localizado TINYINT, con_o_sin_vida TINYINT, fecha_localizacion DATE, voluntaria_o_fue_delito TINYINT, delito NVARCHAR(1000), acciones_busqueda NVARCHAR(MAX), obs NVARCHAR(MAX));
            UPDATE v SET folio_rnpdno = p.folio_rnpdno,
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
      AND (no_banci = @Texto OR curp = @Texto OR folio_rnpdno = @Texto OR CHARINDEX(@Texto,CONCAT(nomb,N'' '',pro_apellido,N'' '',sdo_apellido)) > 0)
    ORDER BY id_entidad_federativa,no_banci,id_delito,id_vicf OFFSET (@Pagina-1)*@Tamano ROWS FETCH NEXT @Tamano ROWS ONLY;
END;';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/10_20260923_21_validar_localizacion_banci.sql
-- BANCI V2: fechas de localización. Ejecutar después de los scripts 16, 17 y 18, primero en desarrollo.
-- No borra registros ni crea tablas. Los procedimientos de preparación/confirmación conservan sus permisos y bloqueos.
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 52536, 'Ejecute este script sin transacciones abiertas.', 1;
IF OBJECT_ID(N'dbo.sp_banci_calcular_actualizacion_v2', N'P') IS NULL OR OBJECT_ID(N'dbo.banci_vw_victimas_v2', N'V') IS NULL THROW 52536, 'Falta instalar BANCI V2 (scripts 16 a 18).', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_victimas_v2 AS
SELECT c.id_entidad_federativa, c.no_banci, c.id_ci, c.ntra_ci, c.fha_de_ini,
    c.id_banci_carpeta_investigacion, d.id_banci_delito, d.id_delito, v.id_banci_victima, v.id_vicf,
    v.id_tv, v.id_tpm, v.sexo, v.genero, v.pob, v.disc, v.fha_nac, v.edad, v.nacional,
    v.folio_rnpdno, v.pro_apellido, v.sdo_apellido, v.nomb, v.entidad_nacimiento, v.estado_migratorio, v.curp, v.rfc,
    v.localizado_o_no_localizado, v.con_o_sin_vida, v.fecha_localizacion, v.voluntaria_o_fue_delito, v.delito, v.acciones_busqueda, v.obs,
    v.version_banci, v.fecha_modificacion, d.fha_de_hchos
FROM dbo.banci_carpeta_investigacion c JOIN dbo.banci_delito d ON d.id_banci_carpeta_investigacion = c.id_banci_carpeta_investigacion
JOIN dbo.banci_victima v ON v.id_banci_delito = d.id_banci_delito WHERE c.activo = 1 AND d.activo = 1 AND v.activo = 1;';

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
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j WHERE j.[key] COLLATE Latin1_General_100_BIN2 NOT IN (N''fila'',N''no_banci'',N''id_delito'',N''id_vicf'',N''folio_rnpdno'',N''pro_apellido'',N''sdo_apellido'',N''nomb'',N''entidad_nacimiento'',N''estado_migratorio'',N''curp'',N''rfc'',N''localizado_o_no_localizado'',N''con_o_sin_vida'',N''fecha_localizacion'',N''voluntaria_o_fue_delito'',N''delito'',N''acciones_busqueda'',N''obs''))
        THROW 52524, ''La actualización contiene columnas no permitidas.'', 1;
    IF EXISTS (SELECT 1 FROM #Filas f CROSS APPLY OPENJSON(f.datos) j WHERE j.type NOT IN (0,1,2)) THROW 52524, ''Los campos deben ser texto, número o null.'', 1;
    SELECT f.indice, j.[key] COLLATE DATABASE_DEFAULT AS campo, NULLIF(LTRIM(RTRIM(j.value)), N'''') AS valor INTO #Valores FROM #Filas f CROSS APPLY OPENJSON(f.datos) j;
    IF EXISTS (SELECT 1 FROM #Valores WHERE (campo = N''no_banci'' AND DATALENGTH(valor) > 80) OR (campo = N''id_delito'' AND DATALENGTH(valor) > 500) OR (campo = N''id_vicf'' AND DATALENGTH(valor) > 500) OR (campo = N''folio_rnpdno'' AND DATALENGTH(valor) > 500) OR (campo = N''pro_apellido'' AND DATALENGTH(valor) > 500) OR (campo = N''sdo_apellido'' AND DATALENGTH(valor) > 500) OR (campo = N''nomb'' AND DATALENGTH(valor) > 1000) OR (campo = N''entidad_nacimiento'' AND DATALENGTH(valor) > 500) OR (campo = N''estado_migratorio'' AND DATALENGTH(valor) > 1000) OR (campo = N''curp'' AND DATALENGTH(valor) > 100) OR (campo = N''rfc'' AND DATALENGTH(valor) > 26) OR (campo = N''localizado_o_no_localizado'' AND DATALENGTH(valor) > 6) OR (campo = N''con_o_sin_vida'' AND DATALENGTH(valor) > 6) OR (campo = N''fecha_localizacion'' AND DATALENGTH(valor) > 20) OR (campo = N''voluntaria_o_fue_delito'' AND DATALENGTH(valor) > 6) OR (campo = N''delito'' AND DATALENGTH(valor) > 2000)) THROW 52525, ''Un campo supera su longitud permitida.'', 1;
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
        folio_rnpdno = COALESCE(TRY_CONVERT(NVARCHAR(250),(SELECT valor FROM #Valores WHERE indice = a.indice AND campo = N''folio_rnpdno'')),a.folio_rnpdno),
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
    IF EXISTS (SELECT 1 FROM #Propuesto WHERE NULLIF(LTRIM(RTRIM(folio_rnpdno)), N'''') IS NULL) THROW 52531, ''Folio RNPDNO es obligatorio; informe el folio faltante antes de actualizar.'', 1;
    -- Revalidar la fecha final al preparar, recuperar y confirmar; los vacíos conservan el valor registrado.
    DECLARE @HoyLocal DATE = CONVERT(DATE, SWITCHOFFSET(SYSDATETIMEOFFSET(), ''-06:00''));
    IF EXISTS (SELECT 1 FROM #Propuesto p JOIN #Actual a ON a.id_banci_victima = p.id_banci_victima
        WHERE EXISTS (SELECT 1 FROM #Valores x WHERE x.indice = a.indice AND x.valor IS NOT NULL
            AND x.campo IN (N''fecha_localizacion'', N''localizado_o_no_localizado'', N''con_o_sin_vida'', N''voluntaria_o_fue_delito''))
          AND (p.fecha_localizacion > @HoyLocal OR p.fecha_localizacion < CONVERT(DATE, a.fha_de_ini) OR p.fecha_localizacion < CONVERT(DATE, a.fha_de_hchos)))
        THROW 52536, ''La fecha de localización debe estar entre el inicio de la carpeta/los hechos y hoy. Rechace esta revisión y corrija la fecha.'', 1;
    SELECT a.id_banci_victima, a.fila, a.no_banci, a.id_ci, a.id_delito, a.id_vicf, x.campo, x.anterior, x.nuevo INTO #Cambios
    FROM #Actual a JOIN #Propuesto p ON p.id_banci_victima = a.id_banci_victima
    CROSS APPLY (VALUES (N''folio_rnpdno'',CONVERT(NVARCHAR(MAX),a.folio_rnpdno),CONVERT(NVARCHAR(MAX),p.folio_rnpdno)),
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
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
GO


GO

-- Fuente: configuracion del sistema/20260924_publicacion_banci_configuracion/instalacion_nueva/11_20260923_22_carga_inicial_solo_altas.sql
USE [siiid2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
-- BANCI V2 / corrección 22: rechazar carpetas existentes en todas las modalidades. Ejecutar completo en desarrollo, sin modo SQLCMD.
IF DB_NAME() <> N'siiid2' THROW 52500, 'Base de datos incorrecta', 1;
IF @@TRANCOUNT <> 0 THROW 52500, 'Use una ventana sin transacciones abiertas.', 1;
IF COL_LENGTH(N'dbo.banci_carga', N'version_formato') IS NULL THROW 52500, 'Ejecute primero el script 16.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @BloqueoMigracion INT;
    EXEC @BloqueoMigracion = sys.sp_getapplock @Resource = N'BANCI:MIGRACION:V2', @LockMode = N'Exclusive', @LockOwner = N'Transaction', @LockTimeout = 10000;
    IF @BloqueoMigracion < 0 THROW 52500, 'Hay otra migración BANCI en curso.', 1;
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


    IF NOT EXISTS (SELECT 1 FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga AND version_formato = 2)
        THROW 52510, ''Esta operación requiere una carga del formato BANCI v2.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(ntra_ci)), N'''') IS NULL)
        THROW 52511, ''NTRA_CI es obligatorio.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(folio_rnpdno)), N'''') IS NULL)
        THROW 52512, ''Folio RNPDNO es obligatorio para cada víctima.'', 1;
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
        folio_rnpdno = NULLIF(LTRIM(RTRIM(v.folio_rnpdno)), N''''),
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
        localizado_o_no_localizado = CAST(NULL AS TINYINT),
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
            AND h.tipo_registro = N''VICTIMA''
            AND h.tipo_movimiento = N''MODIFICACION''
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

    IF NOT EXISTS (SELECT 1 FROM dbo.banci_carga WHERE id_banci_carga = @IdBanciCarga AND version_formato = 2)
        THROW 52510, ''Esta operación requiere una carga del formato BANCI v2.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_carpeta WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(ntra_ci)), N'''') IS NULL)
        THROW 52511, ''NTRA_CI es obligatorio.'', 1;
    IF EXISTS (SELECT 1 FROM dbo.banci_carga_tmp_victima WHERE id_banci_carga = @IdBanciCarga AND activo = 1 AND NULLIF(LTRIM(RTRIM(folio_rnpdno)), N'''') IS NULL)
        THROW 52512, ''Folio RNPDNO es obligatorio para cada víctima.'', 1;
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
        folio_rnpdno = NULLIF(LTRIM(RTRIM(v.folio_rnpdno)), N''''),
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
        localizado_o_no_localizado = CAST(NULL AS TINYINT),
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

EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.sp_banci_confirmar_carga_v2
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
                EXEC dbo.sp_banci_vista_previa_v2 @CodigoReferencia = @CodigoReferencia, @IdUsuario = @IdUsuario, @Huella = @HuellaActual OUTPUT, @EmitirResultado = 0, @PuedeAceptar = @PuedeAceptar OUTPUT;
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

                EXEC dbo.sp_banci_procesar_carga_v2
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

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
