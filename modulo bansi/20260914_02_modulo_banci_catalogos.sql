USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/*
    SIIID2 - BANCI / DFPyCPP
    Paso 02: catálogos propios.
*/

IF OBJECT_ID(N'dbo.banci_catalogo_clasificacion_delito', N'U') IS NULL
    THROW 52100, 'No existe banci_catalogo_clasificacion_delito. Ejecute primero el script 01.', 1;

IF OBJECT_ID(N'dbo.banci_catalogo_localizacion', N'U') IS NULL
    THROW 52101, 'No existe banci_catalogo_localizacion. Ejecute primero el script 01.', 1;

IF OBJECT_ID(N'dbo.banci_catalogo_condicion_vida', N'U') IS NULL
    THROW 52102, 'No existe banci_catalogo_condicion_vida. Ejecute primero el script 01.', 1;

IF OBJECT_ID(N'dbo.banci_catalogo_voluntaria', N'U') IS NULL
    THROW 52103, 'No existe banci_catalogo_voluntaria. Ejecute primero el script 01.', 1;

IF OBJECT_ID(N'dbo.banci_catalogo_fue_delito', N'U') IS NULL
    THROW 52104, 'No existe banci_catalogo_fue_delito. Ejecute primero el script 01.', 1;
GO

BEGIN TRY
    BEGIN TRANSACTION;

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

    INSERT INTO dbo.banci_catalogo_voluntaria
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
            (CONVERT(TINYINT, 1), N'La ausencia de la persona es voluntaria'),
            (CONVERT(TINYINT, 2), N'La ausencia de la persona no es voluntaria')
    ) v
    (
        clave,
        descripcion
    )
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_catalogo_voluntaria c
        WHERE c.clave = v.clave
    );

    INSERT INTO dbo.banci_catalogo_fue_delito
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
            (CONVERT(TINYINT, 1), N'La persona fue víctima de un delito'),
            (CONVERT(TINYINT, 2), N'La persona no fue víctima de un delito')
    ) v
    (
        clave,
        descripcion
    )
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.banci_catalogo_fue_delito c
        WHERE c.clave = v.clave
    );

    COMMIT TRANSACTION;

    PRINT 'Catálogos BANCI cargados correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
GO