USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 53100, 'No existe dbo.semanal_carga.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.semanal_carga')
          AND name = N'CK_semanal_carga_fechas_tramo'
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga
        DROP CONSTRAINT CK_semanal_carga_fechas_tramo;
    END;

    ALTER TABLE dbo.semanal_carga WITH CHECK
    ADD CONSTRAINT CK_semanal_carga_fechas_tramo
    CHECK
    (
        fecha_inicio_tramo <= fecha_fin_tramo
        AND MONTH(fecha_inicio_tramo) = mes_corte
        AND MONTH(fecha_fin_tramo) = mes_corte
        AND YEAR(fecha_inicio_tramo) = anio_corte
        AND YEAR(fecha_fin_tramo) = anio_corte
    );

    ALTER TABLE dbo.semanal_carga
    CHECK CONSTRAINT CK_semanal_carga_fechas_tramo;

    COMMIT TRANSACTION;

    PRINT N'Periodo mensual acumulativo habilitado correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO