/* =====================================================================
   LA PROMESA ERP  |  13 - Usuario de la aplicación (OPCIONAL)
   ---------------------------------------------------------------------
   Crea un login con permisos mínimos para la API (en lugar de usar "sa").
   La contraseña NO está en este archivo: se pasa al ejecutar.
   Ejecutar con sqlcmd (no forma parte de 00_ejecutar_todo.sql):
     sqlcmd -S localhost,1435 -U sa -i 13_usuario_aplicacion.sql ^
            -v APP_LOGIN="lapromesa_app" APP_PASSWORD="<contraseña segura>"
   La cadena de conexión se guarda con dotnet user-secrets (nunca en Git).
   ===================================================================== */
:on error exit
USE master;
GO
IF SUSER_ID(N'$(APP_LOGIN)') IS NULL
    CREATE LOGIN [$(APP_LOGIN)] WITH PASSWORD = N'$(APP_PASSWORD)',
           DEFAULT_DATABASE = LaPromesaERP, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
GO
USE LaPromesaERP;
GO
IF USER_ID(N'$(APP_LOGIN)') IS NULL
    CREATE USER [$(APP_LOGIN)] FOR LOGIN [$(APP_LOGIN)] WITH DEFAULT_SCHEMA = compras;
GO
ALTER ROLE rol_lapromesa_app ADD MEMBER [$(APP_LOGIN)];
GO
PRINT N'[OK] 13 - Usuario de aplicación $(APP_LOGIN) listo.';
GO
