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

    CREATE SEQUENCE dbo.seq_banci_no_banci
        AS BIGINT
        START WITH 1
        INCREMENT BY 1
        MINVALUE 1
        NO CYCLE;

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
            ),

        CONSTRAINT CK_banci_delito_coord_x
            CHECK
            (
                coord_x IS NULL
                OR coord_x BETWEEN -118.000000 AND -86.000000
            ),

        CONSTRAINT CK_banci_delito_coord_y
            CHECK
            (
                coord_y IS NULL
                OR coord_y BETWEEN 13.000000 AND 34.000000
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

        no_banci BIGINT NOT NULL
            CONSTRAINT DF_banci_victima_no_banci
            DEFAULT (NEXT VALUE FOR dbo.seq_banci_no_banci),

        folio_fotovolante NVARCHAR(250) NULL,
        folio_rnpdno NVARCHAR(250) NULL,

        pro_apellido NVARCHAR(250) NULL,
        sdo_apellido NVARCHAR(250) NULL,
        nomb NVARCHAR(500) NULL,

        entidad_nacimiento NVARCHAR(250) NULL,
        estado_migratorio NVARCHAR(500) NULL,

        curp NVARCHAR(18) NULL,
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

        CONSTRAINT UQ_banci_victima_no_banci
            UNIQUE (no_banci),

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

        CONSTRAINT FK_banci_victima_pob
            FOREIGN KEY (pob)
            REFERENCES dbo.catalogo_pertenece_poblacion_indigena(clave),

        CONSTRAINT FK_banci_victima_disc
            FOREIGN KEY (disc)
            REFERENCES dbo.catalogo_presenta_discapacidad(clave),

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