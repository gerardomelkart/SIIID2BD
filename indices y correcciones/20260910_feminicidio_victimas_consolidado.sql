USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME() <> N'siiid2'
BEGIN
    THROW 55001, 'El script debe ejecutarse en la base siiid2.', 1;
END;
GO

/* ============================================================
   FEMINICIDIO - NUEVAS VARIABLES DE VICTIMAS
   SOLO MODULO CONSOLIDADO / MENSUAL DE FUERO COMUN
   ============================================================ */

/* ---------- STAGING ---------- */

IF COL_LENGTH(N'dbo.carga_tmp_victima', N'nombre_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.carga_tmp_victima
    ADD nombre_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.carga_tmp_victima', N'primer_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.carga_tmp_victima
    ADD primer_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.carga_tmp_victima', N'segundo_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.carga_tmp_victima
    ADD segundo_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.carga_tmp_victima', N'curp_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.carga_tmp_victima
    ADD curp_vicfem NVARCHAR(250) NULL;
END;
GO

/* ---------- INFORMACION CONFIRMADA ---------- */

IF COL_LENGTH(N'dbo.victima', N'nombre_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima
    ADD nombre_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima', N'primer_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima
    ADD primer_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima', N'segundo_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima
    ADD segundo_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima', N'curp_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima
    ADD curp_vicfem NVARCHAR(250) NULL;
END;
GO

/* ---------- HISTORICO ---------- */

IF COL_LENGTH(N'dbo.victima_historico', N'nombre_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima_historico
    ADD nombre_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima_historico', N'primer_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima_historico
    ADD primer_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima_historico', N'segundo_apellido_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima_historico
    ADD segundo_apellido_vicfem NVARCHAR(250) NULL;
END;
GO

IF COL_LENGTH(N'dbo.victima_historico', N'curp_vicfem') IS NULL
BEGIN
    ALTER TABLE dbo.victima_historico
    ADD curp_vicfem NVARCHAR(250) NULL;
END;
GO

/* ---------- VERIFICACION ---------- */

SELECT
    t.name AS tabla,
    c.name AS columna,
    TYPE_NAME(c.user_type_id) AS tipo,
    c.max_length,
    c.is_nullable
FROM sys.tables t
INNER JOIN sys.columns c
    ON c.object_id = t.object_id
WHERE t.name IN
(
    N'carga_tmp_victima',
    N'victima',
    N'victima_historico'
)
AND c.name IN
(
    N'nombre_vicfem',
    N'primer_apellido_vicfem',
    N'segundo_apellido_vicfem',
    N'curp_vicfem'
)
ORDER BY
    t.name,
    c.column_id;
GO