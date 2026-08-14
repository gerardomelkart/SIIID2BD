USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME() <> N'siiid2'
BEGIN
    THROW 51000, 'El script debe ejecutarse en la base siiid2.', 1;
END;

DECLARE @IdModuloFederal INT =
(
    SELECT id_modulo
    FROM dbo.catalogo_modulo
    WHERE clave = N'FEDERAL'
);

IF @IdModuloFederal IS NULL
BEGIN
    THROW 51001, 'No existe el módulo FEDERAL en catalogo_modulo.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.usuario u
    INNER JOIN dbo.roles r ON r.id_rol = u.id_rol
    WHERE r.rol = N'SUPER_USUARIO'
      AND r.activo = 1
      AND u.activo = 1
)
BEGIN
    THROW 51002, 'No existen superusuarios activos para asignar el módulo FEDERAL.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.catalogo_modulo
    SET activo = 1
    WHERE id_modulo = @IdModuloFederal;

    UPDATE um
    SET habilitado = 1,
        habilita_carga = 1,
        habilita_modificacion = 1,
        administra_delitos = 0,
        fecha_modificacion = SYSDATETIME(),
        id_usuario_modificacion = u.id_usuario,
        activo = 1
    FROM dbo.usuario_modulo um
    INNER JOIN dbo.usuario u ON u.id_usuario = um.id_usuario
    INNER JOIN dbo.roles r ON r.id_rol = u.id_rol
    WHERE um.id_modulo = @IdModuloFederal
      AND r.rol = N'SUPER_USUARIO'
      AND r.activo = 1
      AND u.activo = 1;

    INSERT INTO dbo.usuario_modulo
    (
        id_usuario,
        id_modulo,
        habilitado,
        habilita_carga,
        habilita_modificacion,
        administra_delitos,
        id_usuario_modificacion,
        activo
    )
    SELECT
        u.id_usuario,
        @IdModuloFederal,
        1,
        1,
        1,
        0,
        u.id_usuario,
        1
    FROM dbo.usuario u
    INNER JOIN dbo.roles r ON r.id_rol = u.id_rol
    WHERE r.rol = N'SUPER_USUARIO'
      AND r.activo = 1
      AND u.activo = 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.usuario_modulo um
          WHERE um.id_usuario = u.id_usuario
            AND um.id_modulo = @IdModuloFederal
      );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT id_modulo, clave, nombre, activo
FROM dbo.catalogo_modulo
WHERE clave = N'FEDERAL';

SELECT
    u.id_usuario,
    u.usuario,
    r.rol,
    cm.clave AS modulo,
    um.habilitado,
    um.habilita_carga,
    um.habilita_modificacion,
    um.administra_delitos,
    um.activo
FROM dbo.usuario_modulo um
INNER JOIN dbo.usuario u ON u.id_usuario = um.id_usuario
INNER JOIN dbo.roles r ON r.id_rol = u.id_rol
INNER JOIN dbo.catalogo_modulo cm ON cm.id_modulo = um.id_modulo
WHERE cm.clave = N'FEDERAL'
ORDER BY u.id_usuario;
GO