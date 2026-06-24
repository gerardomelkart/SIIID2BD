USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @EjecutarAjuste BIT = 0; -- 0 = prueba con ROLLBACK, 1 = aplica con COMMIT

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT 'Estado actual de cruces 7.08, 7.11, 7.12 y 7.13 en catalogo_delito_sabana';

    SELECT
        md.clave4,
        gc.clave AS clave_grado_consumacion,
        s.delito_sabana,
        s.subtipo_delito_sabana,
        s.modalidad_delito_sabana,
        COUNT(*) AS total_renglones
    FROM dbo.catalogo_delito_sabana s
    INNER JOIN dbo.catalogo_modalidad_delito md
        ON md.id_modalidad_delito = s.id_modalidad_delito
       AND md.activo = 1
    INNER JOIN dbo.catalogo_grado_consumacion gc
        ON gc.id_grado_consumacion = s.id_grado_consumacion
       AND gc.activo = 1
    WHERE s.activo = 1
      AND md.clave4 IN ('7.08', '7.11', '7.12', '7.13')
    GROUP BY
        md.clave4,
        gc.clave,
        s.delito_sabana,
        s.subtipo_delito_sabana,
        s.modalidad_delito_sabana
    ORDER BY
        md.clave4,
        gc.clave,
        s.delito_sabana;

    UPDATE s
    SET delito_sabana = CASE md.clave4
            WHEN '7.08' THEN 'Delitos cometidos por servidores públicos'
            WHEN '7.11' THEN 'Delitos contra la administración de justicia'
            WHEN '7.12' THEN 'Suplantación y usurpación de identidad'
            WHEN '7.13' THEN 'Tortura'
            ELSE s.delito_sabana
        END,
        subtipo_delito_sabana = CASE md.clave4
            WHEN '7.08' THEN 'Delitos cometidos por servidores públicos'
            WHEN '7.11' THEN 'Delitos contra la administración de justicia'
            WHEN '7.12' THEN 'Suplantación y usurpación de identidad'
            WHEN '7.13' THEN 'Tortura'
            ELSE s.subtipo_delito_sabana
        END,
        modalidad_delito_sabana = CASE md.clave4
            WHEN '7.08' THEN 'Delitos cometidos por servidores públicos'
            WHEN '7.11' THEN 'Delitos contra la administración de justicia'
            WHEN '7.12' THEN 'Suplantación y usurpación de identidad'
            WHEN '7.13' THEN 'Tortura'
            ELSE s.modalidad_delito_sabana
        END
    FROM dbo.catalogo_delito_sabana s
    INNER JOIN dbo.catalogo_modalidad_delito md
        ON md.id_modalidad_delito = s.id_modalidad_delito
       AND md.activo = 1
    INNER JOIN dbo.catalogo_grado_consumacion gc
        ON gc.id_grado_consumacion = s.id_grado_consumacion
       AND gc.activo = 1
    WHERE s.activo = 1
      AND gc.clave = 2
      AND md.clave4 IN ('7.08', '7.11', '7.12', '7.13')
      AND s.delito_sabana = 'Otros delitos del Fuero Común'
      AND s.subtipo_delito_sabana = 'Otros delitos del Fuero Común'
      AND s.modalidad_delito_sabana = 'Otros delitos del Fuero Común';

    PRINT CONCAT('Renglones ajustados: ', @@ROWCOUNT);

    PRINT 'Estado posterior de cruces 7.08, 7.11, 7.12 y 7.13 en catalogo_delito_sabana';

    SELECT
        md.clave4,
        gc.clave AS clave_grado_consumacion,
        s.delito_sabana,
        s.subtipo_delito_sabana,
        s.modalidad_delito_sabana,
        COUNT(*) AS total_renglones
    FROM dbo.catalogo_delito_sabana s
    INNER JOIN dbo.catalogo_modalidad_delito md
        ON md.id_modalidad_delito = s.id_modalidad_delito
       AND md.activo = 1
    INNER JOIN dbo.catalogo_grado_consumacion gc
        ON gc.id_grado_consumacion = s.id_grado_consumacion
       AND gc.activo = 1
    WHERE s.activo = 1
      AND md.clave4 IN ('7.08', '7.11', '7.12', '7.13')
    GROUP BY
        md.clave4,
        gc.clave,
        s.delito_sabana,
        s.subtipo_delito_sabana,
        s.modalidad_delito_sabana
    ORDER BY
        md.clave4,
        gc.clave,
        s.delito_sabana;

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
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
    RAISERROR(@MensajeError, 16, 1);
END CATCH;
GO
