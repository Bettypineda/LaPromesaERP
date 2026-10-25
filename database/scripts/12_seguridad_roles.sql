/* =====================================================================
   LA PROMESA ERP  |  12 - Seguridad: roles de base de datos
   ---------------------------------------------------------------------
   Principio de mínimo privilegio:
     - La aplicación (API) solo EJECUTA procedimientos y LEE vistas.
     - No puede hacer INSERT/UPDATE/DELETE directo en las tablas
       (los procedimientos sí pueden, por encadenamiento de propiedad).
     - Reportes y auditoría tienen roles separados.
   El usuario/login de la aplicación se crea con 13_usuario_aplicacion.sql
   (opcional, la contraseña NUNCA se guarda en el repositorio).
   ===================================================================== */
SET NOCOUNT ON;
GO
USE LaPromesaERP;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_lapromesa_app')      IS NULL CREATE ROLE rol_lapromesa_app      AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_lapromesa_reportes') IS NULL CREATE ROLE rol_lapromesa_reportes AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_lapromesa_auditor')  IS NULL CREATE ROLE rol_lapromesa_auditor  AUTHORIZATION dbo;
GO

/* Aplicación: ejecutar procedimientos y leer vistas */
GRANT EXECUTE ON SCHEMA::compras TO rol_lapromesa_app;
GRANT EXECUTE ON SCHEMA::rpt     TO rol_lapromesa_app;
GRANT SELECT  ON SCHEMA::compras TO rol_lapromesa_app;
GRANT SELECT  ON SCHEMA::inv     TO rol_lapromesa_app;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::compras TO rol_lapromesa_app;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::aud     TO rol_lapromesa_app;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::cfg     TO rol_lapromesa_app;
GO

/* Reportes: solo reportes y vistas */
GRANT EXECUTE ON SCHEMA::rpt TO rol_lapromesa_reportes;
GRANT SELECT ON compras.vw_Proveedores             TO rol_lapromesa_reportes;
GRANT SELECT ON compras.vw_OrdenesCompra           TO rol_lapromesa_reportes;
GRANT SELECT ON compras.vw_Recepciones             TO rol_lapromesa_reportes;
GRANT SELECT ON compras.vw_CuentasPorPagar         TO rol_lapromesa_reportes;
GRANT SELECT ON compras.vw_CumplimientoProveedores TO rol_lapromesa_reportes;
GO

/* Auditor: lectura de bitácora y errores */
GRANT SELECT ON SCHEMA::aud TO rol_lapromesa_auditor;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::aud TO rol_lapromesa_auditor;
GO

PRINT N'[OK] 12 - Roles de seguridad.';
GO
