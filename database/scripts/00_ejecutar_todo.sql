/* =====================================================================
   LA PROMESA ERP  |  00 - EJECUTAR TODO (instalación completa)
   ---------------------------------------------------------------------
   CÓMO USARLO EN SSMS:
     1. Abra este archivo en SSMS (conectado a localhost,1435).
     2. Menú Consulta -> Modo SQLCMD  (debe quedar activado).
     3. Revise que RutaBD apunte a la carpeta database del proyecto.
     4. Presione F5. Debe ver mensajes [OK] 01 ... [OK] Datos de prueba.
   Todos los scripts son repetibles (se pueden volver a ejecutar).
   Después ejecute tests/01_pruebas_reglas_negocio.sql.
   ===================================================================== */
:setvar RutaBD "C:\Desarrollo_Web\LaPromesaERP\database"
:on error exit

:r $(RutaBD)\scripts\01_crear_base_datos.sql
:r $(RutaBD)\scripts\02_esquemas_configuracion_auditoria.sql
:r $(RutaBD)\scripts\03_inventario_temporal.sql
:r $(RutaBD)\scripts\04_funciones_secuencias.sql
:r $(RutaBD)\scripts\05_tablas_proveedores_compras.sql
:r $(RutaBD)\scripts\06_vistas.sql
:r $(RutaBD)\scripts\07_triggers.sql
:r $(RutaBD)\scripts\08_sp_proveedores.sql
:r $(RutaBD)\scripts\09_sp_compras_recepciones.sql
:r $(RutaBD)\scripts\10_sp_cuentas_pagos.sql
:r $(RutaBD)\scripts\11_sp_reportes.sql
:r $(RutaBD)\scripts\12_seguridad_roles.sql
:r $(RutaBD)\scripts\14_autenticacion_temporal.sql
:r $(RutaBD)\seed\01_datos_prueba.sql

PRINT N'=====================================================';
PRINT N' La Promesa ERP: base de datos instalada correctamente';
PRINT N'=====================================================';
GO
