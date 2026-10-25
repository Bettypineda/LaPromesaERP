/* =====================================================================
   LA PROMESA ERP  |  07 - Triggers
   ---------------------------------------------------------------------
   Los triggers son la ÚLTIMA línea de defensa: garantizan las reglas
   aunque alguien modifique las tablas directamente (SSMS, otro sistema).
     A. Auditoría      -> aud.Bitacora con datos antes/después en JSON.
     B. No eliminar    -> prohíben DELETE físico (se inactiva/anula).
     C. Inmutables     -> nota de compra, historial, kardex y bitácora.
     D. Reglas         -> transiciones de estado, edición solo en
                          Pendiente, recálculo de totales, saldos.
   Usuario auditado: SESSION_CONTEXT('usuario') que fijan los
   procedimientos; si no existe, el login de SQL Server.
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* ======================= A. TRIGGERS DE AUDITORÍA ======================= */
CREATE OR ALTER TRIGGER compras.trg_CategoriasProveedor_Auditoria
ON compras.CategoriasProveedor
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO aud.Bitacora (Tabla, IdRegistro, Operacion, Usuario, DatosAnteriores, DatosNuevos)
    SELECT
        N'compras.CategoriasProveedor',
        CONVERT(NVARCHAR(50), COALESCE(i.IdCategoria, d.IdCategoria)),
        CASE WHEN d.IdCategoria IS NULL THEN 'INSERT'
             WHEN i.IdCategoria IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        @usuario,
        (SELECT d2.* FROM deleted  AS d2 WHERE d2.IdCategoria = d.IdCategoria FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT i2.* FROM inserted AS i2 WHERE i2.IdCategoria = i.IdCategoria FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.IdCategoria = i.IdCategoria;
END
GO

CREATE OR ALTER TRIGGER compras.trg_Proveedores_Auditoria
ON compras.Proveedores
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO aud.Bitacora (Tabla, IdRegistro, Operacion, Usuario, DatosAnteriores, DatosNuevos)
    SELECT
        N'compras.Proveedores',
        CONVERT(NVARCHAR(50), COALESCE(i.IdProveedor, d.IdProveedor)),
        CASE WHEN d.IdProveedor IS NULL THEN 'INSERT'
             WHEN i.IdProveedor IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        @usuario,
        (SELECT d2.* FROM deleted  AS d2 WHERE d2.IdProveedor = d.IdProveedor FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT i2.* FROM inserted AS i2 WHERE i2.IdProveedor = i.IdProveedor FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.IdProveedor = i.IdProveedor;
END
GO

CREATE OR ALTER TRIGGER compras.trg_OrdenesCompra_Auditoria
ON compras.OrdenesCompra
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO aud.Bitacora (Tabla, IdRegistro, Operacion, Usuario, DatosAnteriores, DatosNuevos)
    SELECT
        N'compras.OrdenesCompra',
        CONVERT(NVARCHAR(50), COALESCE(i.IdOrdenCompra, d.IdOrdenCompra)),
        CASE WHEN d.IdOrdenCompra IS NULL THEN 'INSERT'
             WHEN i.IdOrdenCompra IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        @usuario,
        (SELECT d2.* FROM deleted  AS d2 WHERE d2.IdOrdenCompra = d.IdOrdenCompra FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT i2.* FROM inserted AS i2 WHERE i2.IdOrdenCompra = i.IdOrdenCompra FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.IdOrdenCompra = i.IdOrdenCompra;
END
GO

CREATE OR ALTER TRIGGER compras.trg_OrdenesCompraDetalle_Auditoria
ON compras.OrdenesCompraDetalle
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO aud.Bitacora (Tabla, IdRegistro, Operacion, Usuario, DatosAnteriores, DatosNuevos)
    SELECT
        N'compras.OrdenesCompraDetalle',
        CONVERT(NVARCHAR(50), COALESCE(i.IdDetalle, d.IdDetalle)),
        CASE WHEN d.IdDetalle IS NULL THEN 'INSERT'
             WHEN i.IdDetalle IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        @usuario,
        (SELECT d2.* FROM deleted  AS d2 WHERE d2.IdDetalle = d.IdDetalle FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT i2.* FROM inserted AS i2 WHERE i2.IdDetalle = i.IdDetalle FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.IdDetalle = i.IdDetalle;
END
GO

CREATE OR ALTER TRIGGER compras.trg_Recepciones_Auditoria
ON compras.Recepciones
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO aud.Bitacora (Tabla, IdRegistro, Operacion, Usuario, DatosAnteriores, DatosNuevos)
    SELECT
        N'compras.Recepciones',
        CONVERT(NVARCHAR(50), COALESCE(i.IdRecepcion, d.IdRecepcion)),
        CASE WHEN d.IdRecepcion IS NULL THEN 'INSERT'
             WHEN i.IdRecepcion IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        @usuario,
        (SELECT d2.* FROM deleted  AS d2 WHERE d2.IdRecepcion = d.IdRecepcion FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT i2.* FROM inserted AS i2 WHERE i2.IdRecepcion = i.IdRecepcion FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.IdRecepcion = i.IdRecepcion;
END
GO

CREATE OR ALTER TRIGGER compras.trg_CuentasPorPagar_Auditoria
ON compras.CuentasPorPagar
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO aud.Bitacora (Tabla, IdRegistro, Operacion, Usuario, DatosAnteriores, DatosNuevos)
    SELECT
        N'compras.CuentasPorPagar',
        CONVERT(NVARCHAR(50), COALESCE(i.IdCuentaPagar, d.IdCuentaPagar)),
        CASE WHEN d.IdCuentaPagar IS NULL THEN 'INSERT'
             WHEN i.IdCuentaPagar IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        @usuario,
        (SELECT d2.* FROM deleted  AS d2 WHERE d2.IdCuentaPagar = d.IdCuentaPagar FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT i2.* FROM inserted AS i2 WHERE i2.IdCuentaPagar = i.IdCuentaPagar FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.IdCuentaPagar = i.IdCuentaPagar;
END
GO

CREATE OR ALTER TRIGGER compras.trg_PagosProveedor_Auditoria
ON compras.PagosProveedor
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO aud.Bitacora (Tabla, IdRegistro, Operacion, Usuario, DatosAnteriores, DatosNuevos)
    SELECT
        N'compras.PagosProveedor',
        CONVERT(NVARCHAR(50), COALESCE(i.IdPago, d.IdPago)),
        CASE WHEN d.IdPago IS NULL THEN 'INSERT'
             WHEN i.IdPago IS NULL THEN 'DELETE'
             ELSE 'UPDATE' END,
        @usuario,
        (SELECT d2.* FROM deleted  AS d2 WHERE d2.IdPago = d.IdPago FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
        (SELECT i2.* FROM inserted AS i2 WHERE i2.IdPago = i.IdPago FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d ON d.IdPago = i.IdPago;
END
GO

/* ============ B. PROHIBIR ELIMINACIÓN FÍSICA (borrado lógico) ============ */
CREATE OR ALTER TRIGGER compras.trg_CategoriasProveedor_NoEliminar
ON compras.CategoriasProveedor
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53001, N'No se permite eliminar categorías; desactívelas (Activo = 0).', 1;
END
GO

CREATE OR ALTER TRIGGER compras.trg_Proveedores_NoEliminar
ON compras.Proveedores
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53001, N'No se permite eliminar proveedores; use la inactivación con motivo.', 1;
END
GO

CREATE OR ALTER TRIGGER compras.trg_OrdenesCompra_NoEliminar
ON compras.OrdenesCompra
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53001, N'No se permite eliminar órdenes de compra; use la anulación con motivo.', 1;
END
GO

CREATE OR ALTER TRIGGER compras.trg_CuentasPorPagar_NoEliminar
ON compras.CuentasPorPagar
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53001, N'No se permite eliminar cuentas por pagar.', 1;
END
GO

CREATE OR ALTER TRIGGER compras.trg_PagosProveedor_NoEliminar
ON compras.PagosProveedor
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53001, N'No se permite eliminar pagos; un pago fallido queda como Rechazado.', 1;
END
GO

/* ============ C. REGISTROS INMUTABLES (ni UPDATE ni DELETE) ============ */
CREATE OR ALTER TRIGGER compras.trg_Recepciones_Inmutable
ON compras.Recepciones
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53016, N'La recepción (nota de compra) es un documento definitivo: no se puede modificar ni eliminar.', 1;
END
GO

CREATE OR ALTER TRIGGER compras.trg_RecepcionesDetalle_Inmutable
ON compras.RecepcionesDetalle
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53016, N'El detalle de la recepción (nota de compra) no se puede modificar ni eliminar.', 1;
END
GO

CREATE OR ALTER TRIGGER compras.trg_OrdenesCompraHistorial_Inmutable
ON compras.OrdenesCompraHistorial
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53001, N'El historial de estados es de solo lectura.', 1;
END
GO

CREATE OR ALTER TRIGGER aud.trg_Bitacora_Inmutable
ON aud.Bitacora
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53001, N'La bitácora de auditoría es de solo lectura.', 1;
END
GO

CREATE OR ALTER TRIGGER inv.trg_MovimientosInventario_Inmutable
ON inv.MovimientosInventario
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 53001, N'El kardex es de solo lectura; corrija con un movimiento inverso.', 1;
END
GO

/* ====================== D. TRIGGERS DE REGLAS DE NEGOCIO ====================== */

/* ---------- PROVEEDORES ----------
   - El NIT no puede cambiar si el proveedor ya tiene documentos.
   - No se puede inactivar un proveedor con órdenes abiertas.        */
CREATE OR ALTER TRIGGER compras.trg_Proveedores_Reglas
ON compras.Proveedores
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdProveedor = i.IdProveedor
               WHERE i.Nit <> d.Nit
                 AND EXISTS (SELECT 1 FROM compras.OrdenesCompra AS o WHERE o.IdProveedor = i.IdProveedor))
        THROW 53020, N'No se puede cambiar el NIT de un proveedor que ya tiene órdenes de compra.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdProveedor = i.IdProveedor
               WHERE i.Estado = 'Inactivo' AND d.Estado = 'Activo'
                 AND EXISTS (SELECT 1 FROM compras.OrdenesCompra AS o
                             WHERE o.IdProveedor = i.IdProveedor
                               AND o.Estado IN ('Pendiente', 'Aprobada', 'Parcial')))
        THROW 53005, N'No se puede inactivar un proveedor con órdenes de compra abiertas (Pendiente, Aprobada o Parcial).', 1;
END
GO

/* ---------- ÓRDENES DE COMPRA: creación ---------- */
CREATE OR ALTER TRIGGER compras.trg_OrdenesCompra_Insertar
ON compras.OrdenesCompra
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF EXISTS (SELECT 1 FROM inserted WHERE Estado <> 'Pendiente')
        THROW 53010, N'Toda orden de compra debe crearse en estado Pendiente.', 1;

    IF EXISTS (SELECT 1 FROM inserted AS i
               INNER JOIN compras.Proveedores AS p ON p.IdProveedor = i.IdProveedor
               WHERE p.Estado <> 'Activo')
        THROW 53006, N'Un proveedor inactivo no puede recibir nuevas órdenes de compra.', 1;

    IF EXISTS (SELECT 1 FROM inserted AS i
               INNER JOIN inv.Bodegas AS b ON b.IdBodega = i.IdBodega
               WHERE b.Activo = 0)
        THROW 51025, N'La bodega seleccionada no está activa.', 1;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO compras.OrdenesCompraHistorial (IdOrdenCompra, EstadoAnterior, EstadoNuevo, Usuario, Comentario)
    SELECT IdOrdenCompra, NULL, Estado, @usuario, N'Orden de compra creada'
    FROM inserted;
END
GO

/* ---------- ÓRDENES DE COMPRA: cambios ----------
   Transiciones permitidas:
     Pendiente -> Aprobada | Anulada
     Aprobada  -> Parcial  | Recibida | Anulada (si no tiene recepciones)
     Parcial   -> Recibida
   Recibida y Anulada son estados finales (no se modifican).
   Después de aprobada, los datos comerciales quedan congelados.        */
CREATE OR ALTER TRIGGER compras.trg_OrdenesCompra_Actualizar
ON compras.OrdenesCompra
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF EXISTS (SELECT 1 FROM deleted WHERE Estado IN ('Recibida', 'Anulada'))
        THROW 53019, N'La orden de compra está en un estado final (Recibida o Anulada) y no puede modificarse.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdOrdenCompra = i.IdOrdenCompra
               WHERE d.Estado <> 'Pendiente'
                 AND (   i.Numero        <> d.Numero
                      OR i.IdProveedor   <> d.IdProveedor
                      OR i.IdBodega      <> d.IdBodega
                      OR i.FechaOrden    <> d.FechaOrden
                      OR i.FechaEsperada <> d.FechaEsperada
                      OR i.TipoPago      <> d.TipoPago
                      OR i.DiasCredito   <> d.DiasCredito
                      OR i.TasaIva       <> d.TasaIva
                      OR i.Subtotal      <> d.Subtotal
                      OR i.Iva           <> d.Iva
                      OR i.Total         <> d.Total
                      OR ISNULL(i.Observaciones, N'') <> ISNULL(d.Observaciones, N'')))
        THROW 53007, N'Una orden aprobada ya no puede editarse; solo puede recibirse o anularse.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdOrdenCompra = i.IdOrdenCompra
               WHERE i.Estado <> d.Estado
                 AND NOT EXISTS (SELECT 1
                                 FROM (VALUES ('Pendiente', 'Aprobada'),
                                              ('Pendiente', 'Anulada'),
                                              ('Aprobada',  'Parcial'),
                                              ('Aprobada',  'Recibida'),
                                              ('Aprobada',  'Anulada'),
                                              ('Parcial',   'Recibida')) AS t (De, A)
                                 WHERE t.De = d.Estado AND t.A = i.Estado))
        THROW 53010, N'Transición de estado no permitida para la orden de compra.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdOrdenCompra = i.IdOrdenCompra
               WHERE i.Estado = 'Anulada' AND d.Estado <> 'Anulada'
                 AND EXISTS (SELECT 1 FROM compras.Recepciones AS r WHERE r.IdOrdenCompra = i.IdOrdenCompra))
        THROW 53012, N'No se puede anular una orden que ya tiene recepciones registradas.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdOrdenCompra = i.IdOrdenCompra
               INNER JOIN compras.Proveedores AS p ON p.IdProveedor = i.IdProveedor
               WHERE p.Estado <> 'Activo'
                 AND (i.Estado = 'Aprobada' AND d.Estado = 'Pendiente' OR i.IdProveedor <> d.IdProveedor))
        THROW 53006, N'Un proveedor inactivo no puede recibir nuevas órdenes de compra.', 1;

    DECLARE @usuario NVARCHAR(128) = COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN());

    INSERT INTO compras.OrdenesCompraHistorial (IdOrdenCompra, EstadoAnterior, EstadoNuevo, Usuario, Comentario)
    SELECT i.IdOrdenCompra, d.Estado, i.Estado, @usuario,
           CASE i.Estado
                WHEN 'Aprobada' THEN N'Orden aprobada'
                WHEN 'Parcial'  THEN N'Recepción parcial de mercadería'
                WHEN 'Recibida' THEN N'Mercadería recibida en su totalidad'
                WHEN 'Anulada'  THEN CONCAT(N'Anulada: ', i.MotivoAnulacion)
           END
    FROM inserted AS i
    INNER JOIN deleted AS d ON d.IdOrdenCompra = i.IdOrdenCompra
    WHERE i.Estado <> d.Estado;
END
GO

/* ---------- DETALLE DE ÓRDENES ----------
   - Altas, bajas y cambios de producto/cantidad/costo solo en Pendiente.
   - CantidadRecibida solo aumenta y solo en órdenes Aprobada/Parcial.
   - Recalcula Subtotal, IVA y Total de la orden automáticamente.      */
CREATE OR ALTER TRIGGER compras.trg_OrdenesCompraDetalle_Reglas
ON compras.OrdenesCompraDetalle
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.IdDetalle = i.IdDetalle
               INNER JOIN compras.OrdenesCompra AS o ON o.IdOrdenCompra = i.IdOrdenCompra
               WHERE o.Estado <> 'Pendiente'
                 AND (   d.IdDetalle IS NULL
                      OR i.IdOrdenCompra  <> d.IdOrdenCompra
                      OR i.IdProducto     <> d.IdProducto
                      OR i.CantidadPedida <> d.CantidadPedida
                      OR i.CostoUnitario  <> d.CostoUnitario))
       OR EXISTS (SELECT 1
                  FROM deleted AS d
                  LEFT JOIN inserted AS i ON i.IdDetalle = d.IdDetalle
                  INNER JOIN compras.OrdenesCompra AS o ON o.IdOrdenCompra = d.IdOrdenCompra
                  WHERE i.IdDetalle IS NULL AND o.Estado <> 'Pendiente')
        THROW 53007, N'Solo se pueden modificar las líneas de una orden en estado Pendiente.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.IdDetalle = i.IdDetalle
               WHERE d.IdDetalle IS NULL AND i.CantidadRecibida <> 0)
        THROW 53009, N'Una línea nueva no puede tener cantidad recibida.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdDetalle = i.IdDetalle
               INNER JOIN compras.OrdenesCompra AS o ON o.IdOrdenCompra = i.IdOrdenCompra
               WHERE i.CantidadRecibida <> d.CantidadRecibida
                 AND (i.CantidadRecibida < d.CantidadRecibida OR o.Estado NOT IN ('Aprobada', 'Parcial')))
        THROW 53009, N'La cantidad recibida solo puede aumentar y solo en órdenes Aprobadas o Parciales.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               LEFT JOIN deleted AS d ON d.IdDetalle = i.IdDetalle
               INNER JOIN inv.Productos AS p ON p.IdProducto = i.IdProducto
               WHERE p.Activo = 0 AND (d.IdDetalle IS NULL OR i.IdProducto <> d.IdProducto))
        THROW 51021, N'No se pueden pedir productos inactivos.', 1;

    ;WITH Afectadas AS (
        SELECT IdOrdenCompra FROM inserted
        UNION
        SELECT IdOrdenCompra FROM deleted
    )
    UPDATE o
       SET Subtotal = x.Subtotal,
           Iva      = ROUND(x.Subtotal * o.TasaIva, 2),
           Total    = x.Subtotal + ROUND(x.Subtotal * o.TasaIva, 2)
    FROM compras.OrdenesCompra AS o
    INNER JOIN Afectadas AS a ON a.IdOrdenCompra = o.IdOrdenCompra
    CROSS APPLY (SELECT ISNULL(SUM(dd.Subtotal), 0) AS Subtotal
                 FROM compras.OrdenesCompraDetalle AS dd
                 WHERE dd.IdOrdenCompra = o.IdOrdenCompra) AS x
    WHERE o.Subtotal <> x.Subtotal;
END
GO

/* ---------- CUENTAS POR PAGAR ----------
   Monto, fechas, proveedor y recepción son inmutables; el saldo solo
   disminuye (mediante pagos) y una cuenta Pagada queda cerrada.       */
CREATE OR ALTER TRIGGER compras.trg_CuentasPorPagar_Reglas
ON compras.CuentasPorPagar
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF EXISTS (SELECT 1 FROM deleted WHERE Estado = 'Pagada')
        THROW 53018, N'La cuenta por pagar ya está pagada y no puede modificarse.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdCuentaPagar = i.IdCuentaPagar
               WHERE i.Numero <> d.Numero OR i.IdRecepcion <> d.IdRecepcion OR i.IdProveedor <> d.IdProveedor
                  OR i.FechaEmision <> d.FechaEmision OR i.FechaVencimiento <> d.FechaVencimiento
                  OR i.Monto <> d.Monto OR i.Saldo > d.Saldo)
        THROW 53019, N'Los datos de la cuenta por pagar no se modifican; el saldo solo disminuye mediante pagos.', 1;
END
GO

/* ---------- PAGOS ----------
   - Aprobado y Rechazado son estados finales.
   - Monto, cuenta, método y operación no cambian.
   - Al quedar Aprobado, rebaja el saldo de la cuenta por pagar.      */
CREATE OR ALTER TRIGGER compras.trg_PagosProveedor_Reglas
ON compras.PagosProveedor
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF EXISTS (SELECT 1 FROM deleted WHERE Estado IN ('Aprobado', 'Rechazado'))
        THROW 53015, N'Un pago aprobado o rechazado es definitivo y no puede modificarse.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN deleted AS d ON d.IdPago = i.IdPago
               WHERE i.Monto <> d.Monto OR i.IdCuentaPagar <> d.IdCuentaPagar
                  OR i.Metodo <> d.Metodo OR i.OperacionId <> d.OperacionId OR i.IdProveedor <> d.IdProveedor)
        THROW 53015, N'El monto, la cuenta, el método y la operación de un pago no pueden modificarse.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               INNER JOIN compras.CuentasPorPagar AS c ON c.IdCuentaPagar = i.IdCuentaPagar
               WHERE i.IdProveedor <> c.IdProveedor)
        THROW 53015, N'El proveedor del pago no coincide con el de la cuenta por pagar.', 1;

    DECLARE @aplicar TABLE (IdCuentaPagar INT PRIMARY KEY, Monto DECIMAL(18,2) NOT NULL);

    INSERT INTO @aplicar (IdCuentaPagar, Monto)
    SELECT i.IdCuentaPagar, SUM(i.Monto)
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.IdPago = i.IdPago
    WHERE i.Estado = 'Aprobado' AND (d.IdPago IS NULL OR d.Estado <> 'Aprobado')
    GROUP BY i.IdCuentaPagar;

    IF NOT EXISTS (SELECT 1 FROM @aplicar) RETURN;

    IF EXISTS (SELECT 1 FROM @aplicar AS a
               INNER JOIN compras.CuentasPorPagar AS c ON c.IdCuentaPagar = a.IdCuentaPagar
               WHERE a.Monto > c.Saldo)
        THROW 53013, N'El pago excede el saldo pendiente de la cuenta por pagar.', 1;

    UPDATE c
       SET Saldo             = c.Saldo - a.Monto,
           Estado            = CASE WHEN c.Saldo - a.Monto = 0 THEN 'Pagada' ELSE 'Parcial' END,
           FechaModificacion = SYSDATETIME()
    FROM compras.CuentasPorPagar AS c
    INNER JOIN @aplicar AS a ON a.IdCuentaPagar = c.IdCuentaPagar;
END
GO

PRINT N'[OK] 07 - Triggers.';
GO
