/*
    Ejecutar en el servidor 20 (SERVHP-CNI / 10.237.157.20), conectado
    con el login usrCNI. Repara o crea el linked server SIIID2_PROD usando
    MSOLEDBSQL y crea cinco vistas nuevas en incidencia. No modifica otros
    linked servers, los objetos viejos ni SyncMySQLTables.

    IMPORTANTE:
    1. Pegar solamente en @ContrasenaRemota la misma contrasena usada en el script 01.
    2. No guardar ni compartir la copia que contenga la contrasena real.
*/

USE [incidencia];

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LinkedServer SYSNAME = N'SIIID2_PROD';
DECLARE @ServidorRemoto NVARCHAR(128) = N'10.100.75.51,1433';
DECLARE @BaseRemota SYSNAME = N'siiid2';
DECLARE @LoginLocal SYSNAME = N'usrCNI';
DECLARE @LoginRemoto SYSNAME = N'siiid2_inc20_lectura';
DECLARE @ContrasenaRemota NVARCHAR(128) = N'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%*-_=+'; -- Pegar aqui la misma contrasena del script 01.

IF DB_NAME() <> N'incidencia'
BEGIN
    THROW 52001, 'Este script debe ejecutarse en la base incidencia del servidor 20.', 1;
END;

IF CONVERT(NVARCHAR(128), SERVERPROPERTY(N'ServerName')) <> N'SERVHP-CNI'
BEGIN
    THROW 52002, 'El servidor actual no es SERVHP-CNI. No se realizo ningun cambio.', 1;
END;

IF ORIGINAL_LOGIN() <> @LoginLocal
BEGIN
    THROW 52003, 'Ejecuta este script conectado con el login usrCNI.', 1;
END;

IF HAS_PERMS_BY_NAME(NULL, NULL, N'ALTER ANY LINKED SERVER') <> 1 OR HAS_PERMS_BY_NAME(NULL, NULL, N'ALTER ANY LOGIN') <> 1
BEGIN
    THROW 52004, 'El login actual no tiene los permisos de servidor requeridos.', 1;
END;

IF HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'CREATE VIEW') <> 1 OR HAS_PERMS_BY_NAME(N'dbo', N'SCHEMA', N'ALTER') <> 1
BEGIN
    THROW 52005, 'El login actual no puede crear vistas en dbo dentro de incidencia.', 1;
END;

IF HAS_PERMS_BY_NAME(N'dbo', N'SCHEMA', N'SELECT') <> 1
   AND HAS_PERMS_BY_NAME(N'dbo', N'SCHEMA', N'CONTROL') <> 1
   AND HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'CONTROL') <> 1
BEGIN
    THROW 52011, 'El login actual no puede consultar ni otorgarse lectura sobre las vistas nuevas.', 1;
END;

IF LEN(ISNULL(@ContrasenaRemota, N'')) < 16 OR LEN(@ContrasenaRemota) > 128
BEGIN
    THROW 52006, 'Reemplaza @ContrasenaRemota por la misma contrasena segura usada en el script 01.', 1;
END;

DECLARE @Objetivos TABLE (nombre SYSNAME PRIMARY KEY);

INSERT INTO @Objetivos (nombre)
VALUES
    (N'tbl_carpetas2'),
    (N'tbl_delitos2'),
    (N'tbl_victimas2'),
    (N'vw_listado_nominal_delitos2'),
    (N'vw_listado_nominal_victimas2');

IF EXISTS
(
    SELECT 1
    FROM sys.objects o
    INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
    INNER JOIN @Objetivos x ON x.nombre = o.name
    WHERE s.name = N'dbo'
)
BEGIN
    SELECT s.name AS esquema, o.name AS objeto, o.type_desc AS tipo_objeto
    FROM sys.objects o
    INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
    INNER JOIN @Objetivos x ON x.nombre = o.name
    WHERE s.name = N'dbo'
    ORDER BY o.name;

    THROW 52007, 'Uno o mas nombres nuevos ya existen en incidencia. No se modifico ningun objeto local.', 1;
END;

IF SUSER_ID(@LoginLocal) IS NULL
BEGIN
    THROW 52008, 'No existe el login local usrCNI.', 1;
END;

IF EXISTS (SELECT 1 FROM sys.servers WHERE name = @LinkedServer)
   AND EXISTS
(
    SELECT 1
    FROM sys.servers
    WHERE name = @LinkedServer
      AND
      (
          data_source <> @ServidorRemoto
          OR ISNULL(catalog, N'') <> @BaseRemota
          OR provider NOT IN (N'SQLNCLI', N'SQLNCLI11', N'MSOLEDBSQL')
      )
)
BEGIN
    THROW 52009, 'SIIID2_PROD ya existe pero no corresponde al intento anterior. No fue modificado.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.servers
    WHERE name = @LinkedServer
      AND provider IN (N'SQLNCLI', N'SQLNCLI11')
)
BEGIN
    EXEC master.dbo.sp_dropserver
        @server = @LinkedServer,
        @droplogins = N'droplogins';
END;

IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = @LinkedServer)
BEGIN
    EXEC master.dbo.sp_addlinkedserver
        @server = @LinkedServer,
        @srvproduct = N'',
        @provider = N'MSOLEDBSQL',
        @datasrc = @ServidorRemoto,
        @catalog = @BaseRemota;
END
ELSE IF EXISTS
(
    SELECT 1
    FROM sys.servers
    WHERE name = @LinkedServer
      AND provider <> N'MSOLEDBSQL'
)
BEGIN
    THROW 52012, 'SIIID2_PROD no pudo quedar configurado con MSOLEDBSQL.', 1;
END;

EXEC master.dbo.sp_serveroption @server = @LinkedServer, @optname = N'data access', @optvalue = N'true';
EXEC master.dbo.sp_serveroption @server = @LinkedServer, @optname = N'rpc', @optvalue = N'false';
EXEC master.dbo.sp_serveroption @server = @LinkedServer, @optname = N'rpc out', @optvalue = N'false';

DECLARE @IdLinkedServer INT = (SELECT server_id FROM sys.servers WHERE name = @LinkedServer);

IF EXISTS
(
    SELECT 1
    FROM sys.linked_logins
    WHERE server_id = @IdLinkedServer
      AND local_principal_id = 0
)
BEGIN
    EXEC master.dbo.sp_droplinkedsrvlogin @rmtsrvname = @LinkedServer, @locallogin = NULL;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.linked_logins
    WHERE server_id = @IdLinkedServer
      AND local_principal_id = SUSER_ID(@LoginLocal)
)
BEGIN
    EXEC master.dbo.sp_droplinkedsrvlogin @rmtsrvname = @LinkedServer, @locallogin = @LoginLocal;
END;

EXEC master.dbo.sp_addlinkedsrvlogin
    @rmtsrvname = @LinkedServer,
    @useself = N'False',
    @locallogin = @LoginLocal,
    @rmtuser = @LoginRemoto,
    @rmtpassword = @ContrasenaRemota;

SET @ContrasenaRemota = NULL;

EXEC sys.sp_executesql N'
    SELECT TOP (1)
        pk_ci,
        id_ci
    FROM [SIIID2_PROD].[siiid2].[dbo].[tbl_carpetas];';

BEGIN TRY
    EXEC sys.sp_executesql N'
        CREATE VIEW dbo.tbl_carpetas2
        AS
        SELECT
            pk_ci,
            id_ci,
            ntra_ci,
            fha_de_ini,
            hra_de_ini,
            rmen_de_hchos,
            usuario_reg,
            fcha_insert,
            codigo_referencia,
            mes_corte,
            anio_corte
        FROM [SIIID2_PROD].[siiid2].[dbo].[tbl_carpetas];';

    EXEC sys.sp_executesql N'
        CREATE VIEW dbo.tbl_delitos2
        AS
        SELECT
            pk_del,
            pk_ci,
            id_ci,
            id_delito,
            dto,
            moda_dto,
            forma_acc,
            fha_de_hchos,
            hra_de_hchos,
            emto_com_dto,
            grdo_cons,
            clasf_de_dto,
            nom_ent_hchos,
            id_ent_hchos,
            nom_mun_hchos,
            id_mun_hchos,
            nom_loc_hchos,
            id_loc_hchos,
            nom_col_hchos,
            id_col_hchos,
            cp,
            coord_x,
            coord_y,
            dom_hchos,
            usuario_reg,
            fcha_insert,
            codigo_referencia,
            mes_corte,
            anio_corte
        FROM [SIIID2_PROD].[siiid2].[dbo].[tbl_delitos];';

    EXEC sys.sp_executesql N'
        CREATE VIEW dbo.tbl_victimas2
        AS
        SELECT
            pk_vict,
            pk_ci,
            pk_del,
            id_ci,
            id_delito,
            id_vicf,
            id_tv,
            id_tpm,
            sexo,
            genero,
            pob,
            disc,
            fha_nac,
            edad,
            nacional,
            usuario_reg,
            fcha_insert,
            codigo_referencia,
            mes_corte,
            anio_corte
        FROM [SIIID2_PROD].[siiid2].[dbo].[tbl_victimas];';

    EXEC sys.sp_executesql N'
        CREATE VIEW dbo.vw_listado_nominal_delitos2
        AS
        SELECT
            pk_ci,
            id_ci,
            ntra_ci,
            fha_de_ini,
            hra_de_ini,
            rmen_de_hchos,
            fcha_insert,
            codigo_referencia,
            mes_corte,
            anio_corte,
            pk_del,
            id_delito,
            dto,
            moda_dto,
            forma_acc,
            fha_de_hchos,
            hra_de_hchos,
            emto_com_dto,
            grdo_cons,
            clasf_de_dto,
            bien_juridico,
            delito,
            subtipo_delito,
            modalidad_delito,
            nom_ent_hchos,
            id_ent_hchos,
            nom_mun_hchos,
            id_mun_hchos,
            nom_loc_hchos,
            id_loc_hchos,
            cp,
            coord_x,
            coord_y,
            dom_hchos,
            nom_ent_catalogo,
            nom_mun_catalogo,
            bien_juridico_sabana,
            delito_sabana,
            subtipo_delito_sabana,
            modalidad_delito_sabana,
            entidad_reg,
            usuario_reg
        FROM [SIIID2_PROD].[siiid2].[dbo].[vw_listado_nominal_delitos];';

    EXEC sys.sp_executesql N'
        CREATE VIEW dbo.vw_listado_nominal_victimas2
        AS
        SELECT
            entidad_reg,
            usuario_reg,
            fcha_insert,
            anio_corte,
            mes_corte,
            codigo_referencia,
            id_ci,
            pk_ci,
            id_delito,
            pk_del,
            id_vicf,
            pk_vict,
            ntra_ci,
            fha_de_ini,
            hra_de_ini,
            fecha,
            rmen_de_hchos,
            dto,
            moda_dto,
            fha_de_hchos,
            hra_de_hchos,
            grdo_cons,
            d_grdo_cons,
            forma_acc,
            d_forma_acc,
            emto_com_dto,
            d_emto_com_dto,
            clasf_de_dto,
            delito,
            modalidad_delito,
            subtipo_delito,
            bien_juridico,
            delito_sabana,
            subtipo_delito_sabana,
            modalidad_delito_sabana,
            bien_juridico_sabana,
            id_ent_hchos,
            nom_ent_hchos,
            nom_ent_catalogo,
            nom_corto_ent,
            id_mun_hchos,
            nom_mun_hchos,
            nom_mun_catalogo,
            municipio_hechos_ent,
            id_loc_hchos,
            nom_loc_hchos,
            id_col_hchos,
            nom_col_hchos,
            cp,
            dom_hchos,
            coord_x,
            coord_y,
            id_tv,
            d_tv,
            id_tpm,
            d_tpm,
            sexo,
            d_sexo,
            genero,
            d_genero,
            pob,
            d_pob,
            disc,
            d_disc,
            fha_nac,
            edad,
            d_edad,
            nacional,
            d_nacional
        FROM [SIIID2_PROD].[siiid2].[dbo].[vw_listado_nominal_victimas];';
END TRY
BEGIN CATCH
    IF OBJECT_ID(N'dbo.vw_listado_nominal_victimas2', N'V') IS NOT NULL DROP VIEW dbo.vw_listado_nominal_victimas2;
    IF OBJECT_ID(N'dbo.vw_listado_nominal_delitos2', N'V') IS NOT NULL DROP VIEW dbo.vw_listado_nominal_delitos2;
    IF OBJECT_ID(N'dbo.tbl_victimas2', N'V') IS NOT NULL DROP VIEW dbo.tbl_victimas2;
    IF OBJECT_ID(N'dbo.tbl_delitos2', N'V') IS NOT NULL DROP VIEW dbo.tbl_delitos2;
    IF OBJECT_ID(N'dbo.tbl_carpetas2', N'V') IS NOT NULL DROP VIEW dbo.tbl_carpetas2;
    THROW;
END CATCH;

IF DATABASE_PRINCIPAL_ID(N'usrCNI') IS NOT NULL
   AND HAS_PERMS_BY_NAME(N'dbo', N'SCHEMA', N'SELECT') <> 1
BEGIN
    GRANT SELECT ON OBJECT::dbo.tbl_carpetas2 TO [usrCNI];
    GRANT SELECT ON OBJECT::dbo.tbl_delitos2 TO [usrCNI];
    GRANT SELECT ON OBJECT::dbo.tbl_victimas2 TO [usrCNI];
    GRANT SELECT ON OBJECT::dbo.vw_listado_nominal_delitos2 TO [usrCNI];
    GRANT SELECT ON OBJECT::dbo.vw_listado_nominal_victimas2 TO [usrCNI];
END;

DECLARE @Esperado TABLE
(
    objeto SYSNAME PRIMARY KEY,
    columnas_esperadas INT NOT NULL
);

INSERT INTO @Esperado (objeto, columnas_esperadas)
VALUES
    (N'tbl_carpetas2', 11),
    (N'tbl_delitos2', 29),
    (N'tbl_victimas2', 20),
    (N'vw_listado_nominal_delitos2', 42),
    (N'vw_listado_nominal_victimas2', 69);

SELECT
    e.objeto,
    e.columnas_esperadas,
    COUNT(c.column_id) AS columnas_creadas,
    CASE WHEN COUNT(c.column_id) = e.columnas_esperadas THEN N'CORRECTO' ELSE N'REVISAR' END AS resultado
FROM @Esperado e
LEFT JOIN sys.views v ON v.name = e.objeto AND v.schema_id = SCHEMA_ID(N'dbo')
LEFT JOIN sys.columns c ON c.object_id = v.object_id
GROUP BY e.objeto, e.columnas_esperadas
ORDER BY e.objeto;

IF EXISTS
(
    SELECT 1
    FROM @Esperado e
    LEFT JOIN sys.views v ON v.name = e.objeto AND v.schema_id = SCHEMA_ID(N'dbo')
    OUTER APPLY (SELECT COUNT(*) AS total FROM sys.columns c WHERE c.object_id = v.object_id) x
    WHERE v.object_id IS NULL OR ISNULL(x.total, 0) <> e.columnas_esperadas
)
BEGIN
    THROW 52010, 'Una o mas vistas nuevas no tienen la cantidad esperada de columnas.', 1;
END;

EXEC sys.sp_executesql N'
    SELECT TOP (1) pk_del, id_delito, entidad_reg, usuario_reg
    FROM dbo.vw_listado_nominal_delitos2;

    SELECT TOP (1) pk_vict, id_vicf, edad, d_edad
    FROM dbo.vw_listado_nominal_victimas2;';

PRINT N'Linked server y cinco vistas nuevas creados correctamente. Los objetos viejos no fueron modificados.';
