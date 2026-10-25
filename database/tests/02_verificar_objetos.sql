/* =====================================================================
   LA PROMESA ERP  |  Verificación de instalación
   Compara los objetos que definen los scripts 01-14 (excepto el 13,
   opcional) contra los que existen en la base. Estado FALTA = no creado.
   ===================================================================== */
USE LaPromesaERP;
SET NOCOUNT ON;
DECLARE @e TABLE (Script CHAR(2), Objeto SYSNAME, Tipo VARCHAR(2), Clase NVARCHAR(20));
INSERT @e VALUES
('02','cfg.Parametros','U',N'Tabla'),
('02','aud.Bitacora','U',N'Tabla'),
('02','aud.ErroresBD','U',N'Tabla'),
('02','aud.sp_RegistrarError','P',N'Procedimiento'),
('03','inv.Bodegas','U',N'Tabla'),
('03','inv.Productos','U',N'Tabla'),
('03','inv.Existencias','U',N'Tabla'),
('03','inv.MovimientosInventario','U',N'Tabla'),
('04','cfg.fn_Parametro','FN',N'Funcion'),
('04','compras.fn_NitValido','FN',N'Funcion'),
('04','compras.fn_NitNormalizado','FN',N'Funcion'),
('04','compras.fn_TelefonoNormalizado','FN',N'Funcion'),
('04','compras.fn_FormatearNumero','FN',N'Funcion'),
('04','compras.fn_Cumplimiento','FN',N'Funcion'),
('04','compras.fn_RangoAntiguedad','FN',N'Funcion'),
('04','compras.seq_Proveedor','SO',N'Secuencia'),
('04','compras.seq_OrdenCompra','SO',N'Secuencia'),
('04','compras.seq_Recepcion','SO',N'Secuencia'),
('04','compras.seq_CuentaPagar','SO',N'Secuencia'),
('04','compras.seq_Pago','SO',N'Secuencia'),
('05','compras.CategoriasProveedor','U',N'Tabla'),
('05','compras.Proveedores','U',N'Tabla'),
('05','compras.OrdenesCompra','U',N'Tabla'),
('05','compras.OrdenesCompraDetalle','U',N'Tabla'),
('05','compras.OrdenesCompraHistorial','U',N'Tabla'),
('05','compras.Recepciones','U',N'Tabla'),
('05','compras.RecepcionesDetalle','U',N'Tabla'),
('05','compras.CuentasPorPagar','U',N'Tabla'),
('05','compras.PagosProveedor','U',N'Tabla'),
('06','compras.vw_Proveedores','V',N'Vista'),
('06','compras.vw_OrdenesCompra','V',N'Vista'),
('06','compras.vw_OrdenesCompraDetalle','V',N'Vista'),
('06','compras.vw_Recepciones','V',N'Vista'),
('06','compras.vw_CuentasPorPagar','V',N'Vista'),
('06','compras.vw_PagosProveedor','V',N'Vista'),
('06','compras.vw_CumplimientoProveedores','V',N'Vista'),
('07','compras.trg_CategoriasProveedor_Auditoria','TR',N'Trigger'),
('07','compras.trg_Proveedores_Auditoria','TR',N'Trigger'),
('07','compras.trg_OrdenesCompra_Auditoria','TR',N'Trigger'),
('07','compras.trg_OrdenesCompraDetalle_Auditoria','TR',N'Trigger'),
('07','compras.trg_Recepciones_Auditoria','TR',N'Trigger'),
('07','compras.trg_CuentasPorPagar_Auditoria','TR',N'Trigger'),
('07','compras.trg_PagosProveedor_Auditoria','TR',N'Trigger'),
('07','compras.trg_CategoriasProveedor_NoEliminar','TR',N'Trigger'),
('07','compras.trg_Proveedores_NoEliminar','TR',N'Trigger'),
('07','compras.trg_OrdenesCompra_NoEliminar','TR',N'Trigger'),
('07','compras.trg_CuentasPorPagar_NoEliminar','TR',N'Trigger'),
('07','compras.trg_PagosProveedor_NoEliminar','TR',N'Trigger'),
('07','compras.trg_Recepciones_Inmutable','TR',N'Trigger'),
('07','compras.trg_RecepcionesDetalle_Inmutable','TR',N'Trigger'),
('07','compras.trg_OrdenesCompraHistorial_Inmutable','TR',N'Trigger'),
('07','aud.trg_Bitacora_Inmutable','TR',N'Trigger'),
('07','inv.trg_MovimientosInventario_Inmutable','TR',N'Trigger'),
('07','compras.trg_Proveedores_Reglas','TR',N'Trigger'),
('07','compras.trg_OrdenesCompra_Insertar','TR',N'Trigger'),
('07','compras.trg_OrdenesCompra_Actualizar','TR',N'Trigger'),
('07','compras.trg_OrdenesCompraDetalle_Reglas','TR',N'Trigger'),
('07','compras.trg_CuentasPorPagar_Reglas','TR',N'Trigger'),
('07','compras.trg_PagosProveedor_Reglas','TR',N'Trigger'),
('08','compras.sp_Categoria_Listar','P',N'Procedimiento'),
('08','compras.sp_Categoria_Crear','P',N'Procedimiento'),
('08','compras.sp_Proveedor_ValidarDatos','P',N'Procedimiento'),
('08','compras.sp_Proveedor_Listar','P',N'Procedimiento'),
('08','compras.sp_Proveedor_Obtener','P',N'Procedimiento'),
('08','compras.sp_Proveedor_Crear','P',N'Procedimiento'),
('08','compras.sp_Proveedor_Actualizar','P',N'Procedimiento'),
('08','compras.sp_Proveedor_Inactivar','P',N'Procedimiento'),
('08','compras.sp_Proveedor_Reactivar','P',N'Procedimiento'),
('09','compras.sp_OrdenCompra_CargarDetalle','P',N'Procedimiento'),
('09','compras.sp_OrdenCompra_Listar','P',N'Procedimiento'),
('09','compras.sp_OrdenCompra_Obtener','P',N'Procedimiento'),
('09','compras.sp_OrdenCompra_Crear','P',N'Procedimiento'),
('09','compras.sp_OrdenCompra_Actualizar','P',N'Procedimiento'),
('09','compras.sp_OrdenCompra_Aprobar','P',N'Procedimiento'),
('09','compras.sp_OrdenCompra_Anular','P',N'Procedimiento'),
('09','compras.sp_Recepcion_Registrar','P',N'Procedimiento'),
('09','compras.sp_Recepcion_Listar','P',N'Procedimiento'),
('09','compras.sp_Recepcion_Obtener','P',N'Procedimiento'),
('10','compras.sp_CuentaPagar_Listar','P',N'Procedimiento'),
('10','compras.sp_CuentaPagar_Obtener','P',N'Procedimiento'),
('10','compras.sp_Pago_Iniciar','P',N'Procedimiento'),
('10','compras.sp_Pago_Confirmar','P',N'Procedimiento'),
('10','compras.sp_Pago_RegistrarIntento','P',N'Procedimiento'),
('10','compras.sp_Pago_ListarPendientes','P',N'Procedimiento'),
('11','rpt.sp_ComprasPorProveedor','P',N'Procedimiento'),
('11','rpt.sp_CumplimientoProveedores','P',N'Procedimiento'),
('11','rpt.sp_CuentasPorPagarVencimiento','P',N'Procedimiento'),
('14','seg.Roles','U',N'Tabla'),
('14','seg.Usuarios','U',N'Tabla'),
('14','seg.RefreshTokens','U',N'Tabla'),
('14','compras.sp_Catalogo_Bodegas','P',N'Procedimiento'),
('14','compras.sp_Catalogo_Productos','P',N'Procedimiento');
SELECT e.Script, e.Clase, e.Objeto, CASE WHEN o.object_id IS NULL THEN N'FALTA' ELSE N'OK' END AS Estado
FROM @e e LEFT JOIN sys.objects o ON o.object_id = OBJECT_ID(e.Objeto) AND RTRIM(o.type) COLLATE DATABASE_DEFAULT = e.Tipo
ORDER BY CASE WHEN o.object_id IS NULL THEN 0 ELSE 1 END, e.Script, e.Clase, e.Objeto;
SELECT e.Clase, COUNT(*) AS Esperados, SUM(CASE WHEN o.object_id IS NULL THEN 0 ELSE 1 END) AS Encontrados
FROM @e e LEFT JOIN sys.objects o ON o.object_id = OBJECT_ID(e.Objeto) AND RTRIM(o.type) COLLATE DATABASE_DEFAULT = e.Tipo
GROUP BY e.Clase ORDER BY e.Clase;
SELECT N'Esquemas' AS Elemento, COUNT(*) AS Cantidad FROM sys.schemas WHERE name IN ('cfg','inv','compras','rpt','aud','seg')
UNION ALL SELECT N'Roles BD', COUNT(*) FROM sys.database_principals WHERE name LIKE 'rol_lapromesa%'
UNION ALL SELECT N'Parámetros', COUNT(*) FROM cfg.Parametros
UNION ALL SELECT N'Roles app (seg.Roles)', COUNT(*) FROM seg.Roles
UNION ALL SELECT N'Proveedores', COUNT(*) FROM compras.Proveedores
UNION ALL SELECT N'Órdenes de compra', COUNT(*) FROM compras.OrdenesCompra
UNION ALL SELECT N'Recepciones', COUNT(*) FROM compras.Recepciones
UNION ALL SELECT N'Cuentas por pagar', COUNT(*) FROM compras.CuentasPorPagar
UNION ALL SELECT N'Pagos', COUNT(*) FROM compras.PagosProveedor
UNION ALL SELECT N'Kardex', COUNT(*) FROM inv.MovimientosInventario
UNION ALL SELECT N'Bitácora', COUNT(*) FROM aud.Bitacora
UNION ALL SELECT N'Usuarios app (seg.Usuarios)', COUNT(*) FROM seg.Usuarios
UNION ALL SELECT N'Login lapromesa_app (script 13 opcional)', COUNT(*) FROM sys.database_principals WHERE name = 'lapromesa_app';
