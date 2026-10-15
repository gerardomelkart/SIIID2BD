-- Catálogos vigentes BANCI: ejecutar antes de estructura/04_banci.sql y estructura/08_significados_catalogos.sql.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.banci_catalogo_clasificacion_delito',N'U') IS NULL EXEC(N'CREATE TABLE dbo.banci_catalogo_clasificacion_delito(clave NVARCHAR(20) PRIMARY KEY,tipo_delito NVARCHAR(100) NOT NULL,descripcion NVARCHAR(500) NOT NULL,activo BIT NOT NULL DEFAULT(1));');
IF OBJECT_ID(N'dbo.banci_catalogo_localizacion',N'U') IS NULL EXEC(N'CREATE TABLE dbo.banci_catalogo_localizacion(clave TINYINT PRIMARY KEY,descripcion NVARCHAR(100) NOT NULL,activo BIT NOT NULL DEFAULT(1));');
IF OBJECT_ID(N'dbo.banci_catalogo_condicion_vida',N'U') IS NULL EXEC(N'CREATE TABLE dbo.banci_catalogo_condicion_vida(clave TINYINT PRIMARY KEY,descripcion NVARCHAR(100) NOT NULL,activo BIT NOT NULL DEFAULT(1));');
IF OBJECT_ID(N'dbo.banci_catalogo_constitutiva_delito',N'U') IS NULL EXEC(N'CREATE TABLE dbo.banci_catalogo_constitutiva_delito(clave TINYINT PRIMARY KEY,descripcion NVARCHAR(50) NOT NULL,activo BIT NOT NULL DEFAULT(1));');
IF OBJECT_ID(N'dbo.banci_catalogo_motivo_no_delito',N'U') IS NULL EXEC(N'CREATE TABLE dbo.banci_catalogo_motivo_no_delito(clave NVARCHAR(100) PRIMARY KEY,descripcion NVARCHAR(1000) NOT NULL,activo BIT NOT NULL DEFAULT(1));');
    INSERT INTO dbo.banci_catalogo_clasificacion_delito
    (
        clave,
        tipo_delito,
        descripcion,
        activo
    )
    SELECT
        v.clave,
        v.tipo_delito,
        v.descripcion,
        1
    FROM
    (
        VALUES
        (
            N'2.07.01',
            N'DESAPARICION_COMETIDA_POR_PARTICULARES',
            N'Desaparición de personas cometida por particulares con resultado de muerte'
        ),
        (
            N'2.07.02',
            N'DESAPARICION_COMETIDA_POR_PARTICULARES',
            N'Desaparición de personas cometida por particulares por actividad profesional o función pública'
        ),
        (
            N'2.07.03',
            N'DESAPARICION_COMETIDA_POR_PARTICULARES',
            N'Desaparición de personas cometida por particulares por relación de proximidad'
        ),
        (
            N'2.07.04',
            N'DESAPARICION_COMETIDA_POR_PARTICULARES',
            N'Desaparición de personas cometida por particulares para otros fines'
        ),
        (
            N'2.08.01',
            N'DESAPARICION_FORZADA',
            N'Desaparición forzada de personas con resultado de muerte'
        ),
        (
            N'2.08.02',
            N'DESAPARICION_FORZADA',
            N'Desaparición forzada de personas por actividad profesional o función pública'
        ),
        (
            N'2.08.03',
            N'DESAPARICION_FORZADA',
            N'Desaparición forzada de personas por relación de proximidad'
        ),
        (
            N'2.08.04',
            N'DESAPARICION_FORZADA',
            N'Desaparición forzada de personas para otros fines'
        )
    ) v
    (
        clave,
        tipo_delito,
        descripcion
    )
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_catalogo_clasificacion_delito c
        WHERE c.clave = v.clave
    );
    INSERT INTO dbo.banci_catalogo_localizacion
    (
        clave,
        descripcion,
        activo
    )
    SELECT
        v.clave,
        v.descripcion,
        1
    FROM
    (
        VALUES
            (CONVERT(TINYINT, 1), N'Persona no localizada'),
            (CONVERT(TINYINT, 2), N'Persona localizada')
    ) v
    (
        clave,
        descripcion
    )
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_catalogo_localizacion c
        WHERE c.clave = v.clave
    );
    INSERT INTO dbo.banci_catalogo_condicion_vida
    (
        clave,
        descripcion,
        activo
    )
    SELECT
        v.clave,
        v.descripcion,
        1
    FROM
    (
        VALUES
            (CONVERT(TINYINT, 1), N'Persona localizada sin vida'),
            (CONVERT(TINYINT, 2), N'Persona localizada con vida')
    ) v
    (
        clave,
        descripcion
    )
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_catalogo_condicion_vida c
        WHERE c.clave = v.clave
    );
INSERT dbo.banci_catalogo_constitutiva_delito(clave,descripcion) SELECT v.clave,v.descripcion FROM(VALUES (1,N'Delito'),(2,N'No delito'))v(clave,descripcion) WHERE NOT EXISTS(SELECT 1 FROM dbo.banci_catalogo_constitutiva_delito c WHERE c.clave=v.clave);
INSERT dbo.banci_catalogo_motivo_no_delito(clave,descripcion) SELECT v.clave,v.descripcion FROM(VALUES (N'1',N'Desarrollo'))v(clave,descripcion) WHERE NOT EXISTS(SELECT 1 FROM dbo.banci_catalogo_motivo_no_delito c WHERE c.clave=v.clave);
EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.banci_vw_delito_localizacion_catalogo AS
SELECT clave2 AS clave, delito AS descripcion FROM dbo.catalogo_delito WHERE activo = 1;';
COMMIT;
