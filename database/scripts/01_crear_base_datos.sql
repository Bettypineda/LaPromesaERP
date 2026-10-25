/* =====================================================================
   LA PROMESA ERP  |  01 - Creación de la base de datos
   ---------------------------------------------------------------------
   Motor   : SQL Server 2022 (contenedor Docker, puerto 1435)
   Autora  : Sara (módulos Proveedores y Compras)
   Propósito:
     - Crear la base LaPromesaERP con intercalación en español.
     - Activar READ_COMMITTED_SNAPSHOT para que las lecturas (reportes,
       listados) no bloqueen a las escrituras (compras, recepciones).
   Script repetible: puede ejecutarse varias veces sin error.
   ===================================================================== */
SET NOCOUNT ON;
GO

IF DB_ID(N'LaPromesaERP') IS NULL
BEGIN
    CREATE DATABASE LaPromesaERP COLLATE Modern_Spanish_CI_AS;
    PRINT N'Base de datos LaPromesaERP creada.';
END
ELSE
    PRINT N'La base de datos LaPromesaERP ya existía.';
GO

ALTER DATABASE LaPromesaERP SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO
ALTER DATABASE LaPromesaERP SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

USE LaPromesaERP;
GO
PRINT N'[OK] 01 - Base de datos lista.';
GO
