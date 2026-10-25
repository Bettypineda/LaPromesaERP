/* =====================================================================
   LA PROMESA ERP  |  11 - Reportes (esquema rpt)
   ---------------------------------------------------------------------
   Tres reportes distintos, con filtros, listos para imprimir/exportar:
     1. rpt.sp_ComprasPorProveedor        (compras por proveedor y período)
     2. rpt.sp_CumplimientoProveedores    (entregas a tiempo/retraso, RQ27)
     3. rpt.sp_CuentasPorPagarVencimiento (antigüedad de saldos a una fecha)
   Cada reporte devuelve:
     Resultado 1 = resumen agrupado | 2 = detalle | 3 = totales generales
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* =============== REPORTE 1: COMPRAS POR PROVEEDOR Y PERÍODO =============== */
CREATE OR ALTER PROCEDURE rpt.sp_ComprasPorProveedor
    @FechaDesde       DATE,
    @FechaHasta       DATE,
    @IdProveedor      INT          = NULL,
    @IdCategoria      INT          = NULL,
    @IdBodega         INT          = NULL,
    @Estado           VARCHAR(10)  = NULL,
    @IncluirAnuladas  BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @FechaDesde IS NULL OR @FechaHasta IS NULL OR @FechaDesde > @FechaHasta
            THROW 51050, N'Indique un rango de fechas válido (desde <= hasta).', 1;
        IF DATEDIFF(DAY, @FechaDesde, @FechaHasta) > 731
            THROW 51050, N'El rango del reporte no puede superar 2 años.', 1;
        IF @Estado IS NOT NULL AND @Estado NOT IN ('Pendiente', 'Aprobada', 'Parcial', 'Recibida', 'Anulada')
            THROW 51050, N'Filtro de estado inválido.', 1;

        SELECT o.IdOrdenCompra, o.Numero, o.FechaOrden, o.FechaEsperada, o.Estado,
               o.IdProveedor, p.Codigo AS CodigoProveedor, p.Nombre AS Proveedor, p.Nit AS NitProveedor,
               c.Nombre AS Categoria, b.Nombre AS Bodega, o.TipoPago,
               o.Subtotal, o.Iva, o.Total,
               ISNULL(r.TotalRecibido, 0) AS TotalRecibido
        INTO #oc
        FROM compras.OrdenesCompra AS o
        INNER JOIN compras.Proveedores         AS p ON p.IdProveedor = o.IdProveedor
        INNER JOIN compras.CategoriasProveedor AS c ON c.IdCategoria = p.IdCategoria
        INNER JOIN inv.Bodegas                 AS b ON b.IdBodega    = o.IdBodega
        OUTER APPLY (SELECT SUM(x.Total) AS TotalRecibido
                     FROM compras.Recepciones AS x
                     WHERE x.IdOrdenCompra = o.IdOrdenCompra) AS r
        WHERE o.FechaOrden BETWEEN @FechaDesde AND @FechaHasta
          AND (@IdProveedor IS NULL OR o.IdProveedor = @IdProveedor)
          AND (@IdCategoria IS NULL OR p.IdCategoria = @IdCategoria)
          AND (@IdBodega    IS NULL OR o.IdBodega    = @IdBodega)
          AND (@Estado      IS NULL OR o.Estado      = @Estado)
          AND (@IncluirAnuladas = 1 OR o.Estado <> 'Anulada');

        /* 1. Resumen por proveedor */
        SELECT
            IdProveedor, CodigoProveedor, Proveedor, NitProveedor, Categoria,
            COUNT(*)                                                       AS CantidadOrdenes,
            SUM(CASE WHEN Estado = 'Anulada' THEN 1 ELSE 0 END)            AS OrdenesAnuladas,
            SUM(CASE WHEN Estado <> 'Anulada' THEN Total ELSE 0 END)        AS TotalOrdenado,
            SUM(TotalRecibido)                                             AS TotalRecibido,
            SUM(CASE WHEN Estado <> 'Anulada' THEN Total ELSE 0 END) - SUM(TotalRecibido) AS PendienteDeRecibir,
            CAST(AVG(CASE WHEN Estado <> 'Anulada' THEN Total END) AS DECIMAL(18,2)) AS PromedioPorOrden,
            CAST(SUM(CASE WHEN Estado <> 'Anulada' THEN Total ELSE 0 END) * 100.0
                 / NULLIF(SUM(SUM(CASE WHEN Estado <> 'Anulada' THEN Total ELSE 0 END)) OVER (), 0) AS DECIMAL(5,2)) AS PorcentajeParticipacion,
            MAX(FechaOrden)                                                AS UltimaOrden
        FROM #oc
        GROUP BY IdProveedor, CodigoProveedor, Proveedor, NitProveedor, Categoria
        ORDER BY TotalOrdenado DESC, Proveedor;

        /* 2. Detalle de órdenes */
        SELECT Numero, FechaOrden, FechaEsperada, Estado, CodigoProveedor, Proveedor, Categoria, Bodega,
               TipoPago, Subtotal, Iva, Total, TotalRecibido
        FROM #oc
        ORDER BY Proveedor, FechaOrden, Numero;

        /* 3. Totales generales (encabezado de impresión) */
        SELECT @FechaDesde AS FechaDesde, @FechaHasta AS FechaHasta,
               COUNT(DISTINCT IdProveedor)                                AS Proveedores,
               COUNT(*)                                                   AS Ordenes,
               ISNULL(SUM(CASE WHEN Estado <> 'Anulada' THEN Subtotal ELSE 0 END), 0) AS Subtotal,
               ISNULL(SUM(CASE WHEN Estado <> 'Anulada' THEN Iva ELSE 0 END), 0)      AS Iva,
               ISNULL(SUM(CASE WHEN Estado <> 'Anulada' THEN Total ELSE 0 END), 0)    AS Total,
               ISNULL(SUM(TotalRecibido), 0)                              AS TotalRecibido,
               SYSDATETIME()                                              AS FechaGeneracion
        FROM #oc;
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'rpt.sp_ComprasPorProveedor';
        THROW;
    END CATCH
END
GO

/* ============ REPORTE 2: CUMPLIMIENTO DE PROVEEDORES (RQ27) ============ */
CREATE OR ALTER PROCEDURE rpt.sp_CumplimientoProveedores
    @FechaDesde   DATE,
    @FechaHasta   DATE,
    @IdProveedor  INT = NULL,
    @IdCategoria  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @FechaDesde IS NULL OR @FechaHasta IS NULL OR @FechaDesde > @FechaHasta
            THROW 51050, N'Indique un rango de fechas válido (desde <= hasta).', 1;
        IF DATEDIFF(DAY, @FechaDesde, @FechaHasta) > 731
            THROW 51050, N'El rango del reporte no puede superar 2 años.', 1;

        DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

        SELECT r.IdRecepcion, r.Numero, r.FechaRecepcion, r.FechaEsperada, r.Cumplimiento, r.DiasDiferencia,
               r.Total, o.Numero AS NumeroOrden,
               r.IdProveedor, p.Codigo AS CodigoProveedor, p.Nombre AS Proveedor, c.Nombre AS Categoria
        INTO #rec
        FROM compras.Recepciones AS r
        INNER JOIN compras.OrdenesCompra       AS o ON o.IdOrdenCompra = r.IdOrdenCompra
        INNER JOIN compras.Proveedores         AS p ON p.IdProveedor   = r.IdProveedor
        INNER JOIN compras.CategoriasProveedor AS c ON c.IdCategoria   = p.IdCategoria
        WHERE r.FechaRecepcion BETWEEN @FechaDesde AND @FechaHasta
          AND (@IdProveedor IS NULL OR r.IdProveedor = @IdProveedor)
          AND (@IdCategoria IS NULL OR p.IdCategoria = @IdCategoria);

        /* 1. Resumen y calificación por proveedor */
        ;WITH Resumen AS (
            SELECT IdProveedor, CodigoProveedor, Proveedor, Categoria,
                   COUNT(*)                                                    AS TotalRecepciones,
                   SUM(CASE WHEN Cumplimiento = 'ATiempo'    THEN 1 ELSE 0 END) AS ATiempo,
                   SUM(CASE WHEN Cumplimiento = 'Anticipada' THEN 1 ELSE 0 END) AS Anticipadas,
                   SUM(CASE WHEN Cumplimiento = 'Retraso'    THEN 1 ELSE 0 END) AS ConRetraso,
                   CAST(AVG(CASE WHEN Cumplimiento = 'Retraso' THEN DiasDiferencia * 1.0 END) AS DECIMAL(6,1)) AS PromedioDiasRetraso,
                   MAX(CASE WHEN Cumplimiento = 'Retraso' THEN DiasDiferencia END) AS MaximoDiasRetraso
            FROM #rec
            GROUP BY IdProveedor, CodigoProveedor, Proveedor, Categoria
        )
        SELECT s.*,
               CAST((s.ATiempo + s.Anticipadas) * 100.0 / s.TotalRecepciones AS DECIMAL(5,2)) AS PorcentajeCumplimiento,
               CASE WHEN (s.ATiempo + s.Anticipadas) * 100.0 / s.TotalRecepciones >= 90 THEN N'Excelente'
                    WHEN (s.ATiempo + s.Anticipadas) * 100.0 / s.TotalRecepciones >= 75 THEN N'Bueno'
                    WHEN (s.ATiempo + s.Anticipadas) * 100.0 / s.TotalRecepciones >= 50 THEN N'Regular'
                    ELSE N'Deficiente' END AS Calificacion,
               (SELECT COUNT(*) FROM compras.OrdenesCompra AS o
                WHERE o.IdProveedor = s.IdProveedor
                  AND o.Estado IN ('Aprobada', 'Parcial')
                  AND o.FechaEsperada < @hoy) AS OrdenesAtrasadasHoy
        FROM Resumen AS s
        ORDER BY PorcentajeCumplimiento DESC, s.Proveedor;

        /* 2. Detalle de recepciones */
        SELECT Numero, NumeroOrden, CodigoProveedor, Proveedor, FechaEsperada, FechaRecepcion,
               DiasDiferencia, Cumplimiento, Total
        FROM #rec
        ORDER BY Proveedor, FechaRecepcion, Numero;

        /* 3. Totales generales */
        SELECT @FechaDesde AS FechaDesde, @FechaHasta AS FechaHasta,
               COUNT(*) AS Recepciones,
               SUM(CASE WHEN Cumplimiento = 'ATiempo'    THEN 1 ELSE 0 END) AS ATiempo,
               SUM(CASE WHEN Cumplimiento = 'Anticipada' THEN 1 ELSE 0 END) AS Anticipadas,
               SUM(CASE WHEN Cumplimiento = 'Retraso'    THEN 1 ELSE 0 END) AS ConRetraso,
               CAST(SUM(CASE WHEN Cumplimiento <> 'Retraso' THEN 1 ELSE 0 END) * 100.0
                    / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS PorcentajeCumplimiento,
               SYSDATETIME() AS FechaGeneracion
        FROM #rec;
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'rpt.sp_CumplimientoProveedores';
        THROW;
    END CATCH
END
GO

/* ====== REPORTE 3: CUENTAS POR PAGAR POR VENCIMIENTO (antigüedad) ======
   Reconstruye el saldo a la FECHA DE CORTE (pagos aprobados hasta ese
   día), así el reporte puede emitirse a cualquier fecha pasada.          */
CREATE OR ALTER PROCEDURE rpt.sp_CuentasPorPagarVencimiento
    @FechaCorte       DATE = NULL,   -- NULL = hoy
    @IdProveedor      INT  = NULL,
    @IdCategoria      INT  = NULL,
    @IncluirPagadas   BIT  = 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SET @FechaCorte = ISNULL(@FechaCorte, CAST(GETDATE() AS DATE));

        SELECT c.IdCuentaPagar, c.Numero, c.FechaEmision, c.FechaVencimiento, c.Monto,
               c.Monto - ISNULL(pg.Pagado, 0) AS SaldoAlCorte,
               DATEDIFF(DAY, c.FechaVencimiento, @FechaCorte) AS DiasVencida,
               compras.fn_RangoAntiguedad(c.FechaVencimiento, @FechaCorte) AS Rango,
               r.Numero AS NumeroRecepcion, o.Numero AS NumeroOrden,
               CONCAT(r.SerieFactura, CASE WHEN r.SerieFactura IS NOT NULL THEN '-' END, r.NumeroFactura) AS FacturaProveedor,
               c.IdProveedor, p.Codigo AS CodigoProveedor, p.Nombre AS Proveedor, p.Nit AS NitProveedor, p.DiasCredito
        INTO #cxp
        FROM compras.CuentasPorPagar AS c
        INNER JOIN compras.Recepciones   AS r ON r.IdRecepcion   = c.IdRecepcion
        INNER JOIN compras.OrdenesCompra AS o ON o.IdOrdenCompra = r.IdOrdenCompra
        INNER JOIN compras.Proveedores   AS p ON p.IdProveedor   = c.IdProveedor
        OUTER APPLY (SELECT SUM(x.Monto) AS Pagado
                     FROM compras.PagosProveedor AS x
                     WHERE x.IdCuentaPagar = c.IdCuentaPagar
                       AND x.Estado = 'Aprobado'
                       AND CAST(x.FechaConfirmacion AS DATE) <= @FechaCorte) AS pg
        WHERE c.FechaEmision <= @FechaCorte
          AND (@IdProveedor IS NULL OR c.IdProveedor = @IdProveedor)
          AND (@IdCategoria IS NULL OR p.IdCategoria = @IdCategoria);

        IF @IncluirPagadas = 0
            DELETE FROM #cxp WHERE SaldoAlCorte <= 0;

        /* 1. Resumen por proveedor (columnas por rango de antigüedad) */
        SELECT IdProveedor, CodigoProveedor, Proveedor, NitProveedor, DiasCredito,
               COUNT(*) AS Documentos,
               SUM(CASE WHEN Rango = N'Por vencer' THEN SaldoAlCorte ELSE 0 END) AS PorVencer,
               SUM(CASE WHEN Rango = N'1-30'       THEN SaldoAlCorte ELSE 0 END) AS Vencido_1_30,
               SUM(CASE WHEN Rango = N'31-60'      THEN SaldoAlCorte ELSE 0 END) AS Vencido_31_60,
               SUM(CASE WHEN Rango = N'61-90'      THEN SaldoAlCorte ELSE 0 END) AS Vencido_61_90,
               SUM(CASE WHEN Rango = N'Más de 90'  THEN SaldoAlCorte ELSE 0 END) AS Vencido_Mas_90,
               SUM(SaldoAlCorte) AS SaldoTotal,
               SUM(CASE WHEN DiasVencida > 0 THEN SaldoAlCorte ELSE 0 END) AS SaldoVencido,
               MIN(CASE WHEN SaldoAlCorte > 0 THEN FechaVencimiento END) AS ProximoVencimiento
        FROM #cxp
        GROUP BY IdProveedor, CodigoProveedor, Proveedor, NitProveedor, DiasCredito
        ORDER BY SaldoVencido DESC, SaldoTotal DESC;

        /* 2. Detalle de documentos */
        SELECT Numero, FacturaProveedor, NumeroOrden, NumeroRecepcion, CodigoProveedor, Proveedor,
               FechaEmision, FechaVencimiento, DiasVencida, Rango, Monto, SaldoAlCorte
        FROM #cxp
        ORDER BY FechaVencimiento, Proveedor;

        /* 3. Totales generales */
        SELECT @FechaCorte AS FechaCorte,
               COUNT(*) AS Documentos,
               ISNULL(SUM(CASE WHEN Rango = N'Por vencer' THEN SaldoAlCorte END), 0) AS PorVencer,
               ISNULL(SUM(CASE WHEN Rango = N'1-30'       THEN SaldoAlCorte END), 0) AS Vencido_1_30,
               ISNULL(SUM(CASE WHEN Rango = N'31-60'      THEN SaldoAlCorte END), 0) AS Vencido_31_60,
               ISNULL(SUM(CASE WHEN Rango = N'61-90'      THEN SaldoAlCorte END), 0) AS Vencido_61_90,
               ISNULL(SUM(CASE WHEN Rango = N'Más de 90'  THEN SaldoAlCorte END), 0) AS Vencido_Mas_90,
               ISNULL(SUM(SaldoAlCorte), 0) AS SaldoTotal,
               SYSDATETIME() AS FechaGeneracion
        FROM #cxp;
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'rpt.sp_CuentasPorPagarVencimiento';
        THROW;
    END CATCH
END
GO

PRINT N'[OK] 11 - Reportes.';
GO
