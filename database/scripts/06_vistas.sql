/* =====================================================================
   LA PROMESA ERP  |  06 - Vistas
   ---------------------------------------------------------------------
   Las vistas entregan la información "lista para pantalla": nombres en
   lugar de IDs, totales calculados, días de atraso, antigüedad, etc.
   La API las consulta a través de los procedimientos de listado.
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* --------------------------- PROVEEDORES --------------------------- */
CREATE OR ALTER VIEW compras.vw_Proveedores
AS
SELECT
    p.IdProveedor, p.Codigo, p.Nombre, p.Nit,
    p.IdCategoria, c.Nombre AS Categoria,
    p.Contacto, p.Telefono, p.Email, p.Direccion, p.Departamento,
    p.TipoPago, p.DiasCredito, p.LimiteCredito, p.Banco, p.NumeroCuenta,
    p.Estado,
    p.FechaCreacion, p.CreadoPor, p.FechaModificacion, p.ModificadoPor,
    p.FechaInactivacion, p.InactivadoPor, p.MotivoInactivacion,
    p.RowVersion,
    ISNULL(oc.OrdenesAbiertas, 0)  AS OrdenesAbiertas,
    ISNULL(cp.SaldoPendiente, 0)   AS SaldoPendiente,
    CASE WHEN p.LimiteCredito > 0
         THEN p.LimiteCredito - ISNULL(cp.SaldoPendiente, 0) END AS CreditoDisponible,
    uc.UltimaCompra
FROM compras.Proveedores AS p
INNER JOIN compras.CategoriasProveedor AS c ON c.IdCategoria = p.IdCategoria
OUTER APPLY (SELECT COUNT(*) AS OrdenesAbiertas
             FROM compras.OrdenesCompra AS o
             WHERE o.IdProveedor = p.IdProveedor
               AND o.Estado IN ('Pendiente', 'Aprobada', 'Parcial')) AS oc
OUTER APPLY (SELECT SUM(x.Saldo) AS SaldoPendiente
             FROM compras.CuentasPorPagar AS x
             WHERE x.IdProveedor = p.IdProveedor
               AND x.Estado <> 'Pagada') AS cp
OUTER APPLY (SELECT MAX(o.FechaOrden) AS UltimaCompra
             FROM compras.OrdenesCompra AS o
             WHERE o.IdProveedor = p.IdProveedor
               AND o.Estado <> 'Anulada') AS uc;
GO

/* ------------------------ ÓRDENES DE COMPRA ------------------------ */
CREATE OR ALTER VIEW compras.vw_OrdenesCompra
AS
SELECT
    o.IdOrdenCompra, o.Numero,
    o.IdProveedor, p.Codigo AS CodigoProveedor, p.Nombre AS Proveedor, p.Nit AS NitProveedor,
    o.IdBodega, b.Nombre AS Bodega,
    o.FechaOrden, o.FechaEsperada, o.TipoPago, o.DiasCredito, o.Observaciones,
    o.Subtotal, o.TasaIva, o.Iva, o.Total, o.Estado,
    o.FechaCreacion, o.CreadoPor, o.FechaModificacion, o.ModificadoPor,
    o.FechaAprobacion, o.AprobadoPor,
    o.FechaAnulacion, o.AnuladoPor, o.MotivoAnulacion,
    o.RowVersion,
    ISNULL(d.Lineas, 0)            AS Lineas,
    ISNULL(d.CantidadPedida, 0)    AS CantidadPedida,
    ISNULL(d.CantidadRecibida, 0)  AS CantidadRecibida,
    CAST(CASE WHEN ISNULL(d.CantidadPedida, 0) = 0 THEN 0
              ELSE d.CantidadRecibida * 100.0 / d.CantidadPedida END AS DECIMAL(6,2)) AS PorcentajeRecibido,
    ISNULL(r.Recepciones, 0)       AS Recepciones,
    ISNULL(r.TotalRecibido, 0)     AS TotalRecibido,
    DATEDIFF(DAY, CAST(GETDATE() AS DATE), o.FechaEsperada) AS DiasParaEntrega,
    CAST(CASE WHEN o.Estado IN ('Aprobada', 'Parcial')
               AND o.FechaEsperada < CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END AS BIT) AS EstaAtrasada
FROM compras.OrdenesCompra AS o
INNER JOIN compras.Proveedores AS p ON p.IdProveedor = o.IdProveedor
INNER JOIN inv.Bodegas        AS b ON b.IdBodega    = o.IdBodega
OUTER APPLY (SELECT COUNT(*) AS Lineas,
                    SUM(x.CantidadPedida)   AS CantidadPedida,
                    SUM(x.CantidadRecibida) AS CantidadRecibida
             FROM compras.OrdenesCompraDetalle AS x
             WHERE x.IdOrdenCompra = o.IdOrdenCompra) AS d
OUTER APPLY (SELECT COUNT(*) AS Recepciones, SUM(y.Total) AS TotalRecibido
             FROM compras.Recepciones AS y
             WHERE y.IdOrdenCompra = o.IdOrdenCompra) AS r;
GO

CREATE OR ALTER VIEW compras.vw_OrdenesCompraDetalle
AS
SELECT
    d.IdDetalle, d.IdOrdenCompra, o.Numero AS NumeroOrden,
    d.IdProducto, pr.Codigo AS CodigoProducto, pr.Nombre AS Producto, pr.UnidadMedida,
    d.CantidadPedida, d.CantidadRecibida,
    d.CantidadPedida - d.CantidadRecibida AS CantidadPendiente,
    d.CostoUnitario, d.Subtotal
FROM compras.OrdenesCompraDetalle AS d
INNER JOIN compras.OrdenesCompra AS o  ON o.IdOrdenCompra = d.IdOrdenCompra
INNER JOIN inv.Productos         AS pr ON pr.IdProducto   = d.IdProducto;
GO

/* --------------------------- RECEPCIONES --------------------------- */
CREATE OR ALTER VIEW compras.vw_Recepciones
AS
SELECT
    r.IdRecepcion, r.Numero,
    r.IdOrdenCompra, o.Numero AS NumeroOrden,
    r.IdProveedor, p.Nombre AS Proveedor, p.Nit AS NitProveedor,
    r.IdBodega, b.Nombre AS Bodega,
    r.FechaRecepcion, r.FechaEsperada, r.Cumplimiento, r.DiasDiferencia,
    r.SerieFactura, r.NumeroFactura,
    CONCAT(r.SerieFactura, CASE WHEN r.SerieFactura IS NOT NULL THEN '-' END, r.NumeroFactura) AS Factura,
    r.Subtotal, r.Iva, r.Total, r.Observaciones, r.FechaCreacion, r.RecibidoPor,
    c.IdCuentaPagar, c.Numero AS NumeroCuentaPagar
FROM compras.Recepciones AS r
INNER JOIN compras.OrdenesCompra AS o ON o.IdOrdenCompra = r.IdOrdenCompra
INNER JOIN compras.Proveedores   AS p ON p.IdProveedor   = r.IdProveedor
INNER JOIN inv.Bodegas           AS b ON b.IdBodega      = r.IdBodega
LEFT  JOIN compras.CuentasPorPagar AS c ON c.IdRecepcion = r.IdRecepcion;
GO

/* ------------------------ CUENTAS POR PAGAR ------------------------ */
CREATE OR ALTER VIEW compras.vw_CuentasPorPagar
AS
SELECT
    c.IdCuentaPagar, c.Numero,
    c.IdRecepcion, r.Numero AS NumeroRecepcion,
    r.IdOrdenCompra, o.Numero AS NumeroOrden,
    CONCAT(r.SerieFactura, CASE WHEN r.SerieFactura IS NOT NULL THEN '-' END, r.NumeroFactura) AS FacturaProveedor,
    c.IdProveedor, p.Codigo AS CodigoProveedor, p.Nombre AS Proveedor, p.Nit AS NitProveedor,
    p.Banco, p.NumeroCuenta,
    c.FechaEmision, c.FechaVencimiento, c.Monto, c.Saldo, c.Estado,
    ISNULL(pp.MontoEnProceso, 0)           AS MontoEnProceso,
    c.Saldo - ISNULL(pp.MontoEnProceso, 0) AS SaldoDisponible,
    DATEDIFF(DAY, c.FechaVencimiento, CAST(GETDATE() AS DATE)) AS DiasVencida,
    CASE WHEN c.Estado = 'Pagada' THEN N'Pagada'
         ELSE compras.fn_RangoAntiguedad(c.FechaVencimiento, CAST(GETDATE() AS DATE)) END AS RangoAntiguedad,
    c.FechaCreacion, c.FechaModificacion, c.RowVersion
FROM compras.CuentasPorPagar AS c
INNER JOIN compras.Recepciones   AS r ON r.IdRecepcion   = c.IdRecepcion
INNER JOIN compras.OrdenesCompra AS o ON o.IdOrdenCompra = r.IdOrdenCompra
INNER JOIN compras.Proveedores   AS p ON p.IdProveedor   = c.IdProveedor
OUTER APPLY (SELECT SUM(x.Monto) AS MontoEnProceso
             FROM compras.PagosProveedor AS x
             WHERE x.IdCuentaPagar = c.IdCuentaPagar
               AND x.Estado = 'Pendiente') AS pp;
GO

/* ------------------------------ PAGOS ------------------------------ */
CREATE OR ALTER VIEW compras.vw_PagosProveedor
AS
SELECT
    g.IdPago, g.Numero, g.OperacionId,
    g.IdCuentaPagar, c.Numero AS NumeroCuentaPagar,
    g.IdProveedor, p.Nombre AS Proveedor,
    g.Monto, g.Metodo, g.Banco, g.CuentaDestino, g.ReferenciaBanco,
    g.Estado, g.MensajeBanco, g.Intentos,
    g.FechaSolicitud, g.FechaConfirmacion, g.RegistradoPor, g.ConfirmadoPor
FROM compras.PagosProveedor AS g
INNER JOIN compras.CuentasPorPagar AS c ON c.IdCuentaPagar = g.IdCuentaPagar
INNER JOIN compras.Proveedores     AS p ON p.IdProveedor   = g.IdProveedor;
GO

/* ---------------- CUMPLIMIENTO HISTÓRICO (RQ27) ---------------- */
CREATE OR ALTER VIEW compras.vw_CumplimientoProveedores
AS
SELECT
    p.IdProveedor, p.Codigo, p.Nombre AS Proveedor,
    COUNT(r.IdRecepcion)                                            AS TotalRecepciones,
    SUM(CASE WHEN r.Cumplimiento = 'ATiempo'    THEN 1 ELSE 0 END)  AS ATiempo,
    SUM(CASE WHEN r.Cumplimiento = 'Retraso'    THEN 1 ELSE 0 END)  AS Retraso,
    SUM(CASE WHEN r.Cumplimiento = 'Anticipada' THEN 1 ELSE 0 END)  AS Anticipada,
    CAST(CASE WHEN COUNT(r.IdRecepcion) = 0 THEN NULL
              ELSE SUM(CASE WHEN r.Cumplimiento <> 'Retraso' THEN 1 ELSE 0 END) * 100.0
                   / COUNT(r.IdRecepcion) END AS DECIMAL(5,2))      AS PorcentajeCumplimiento
FROM compras.Proveedores AS p
LEFT JOIN compras.Recepciones AS r ON r.IdProveedor = p.IdProveedor
GROUP BY p.IdProveedor, p.Codigo, p.Nombre;
GO

PRINT N'[OK] 06 - Vistas.';
GO
