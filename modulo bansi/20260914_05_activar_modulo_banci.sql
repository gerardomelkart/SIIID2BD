USE [siiid2];
GO

IF OBJECT_ID(N'dbo.sp_banci_procesar_carga', N'P') IS NULL
    THROW 52300, 'No existe dbo.sp_banci_procesar_carga. No se activó BANCI.', 1;

UPDATE dbo.catalogo_modulo
SET activo = 1
WHERE clave = N'BANCI';

SELECT id_modulo, clave, nombre, activo
FROM dbo.catalogo_modulo
WHERE clave IN (N'MENSUAL', N'BANCI')
ORDER BY id_modulo;
GO