using LaPromesa.Datos.Datos;
using LaPromesa.DTO.DTO;
using LaPromesa.Entidades.Entidades;
using LaPromesa.Utilidades.Excepciones;

namespace LaPromesa.Negocio.Servicios
{
    /// <summary>
    /// Órdenes de compra y su proceso:
    /// Pendiente → Aprobada → (recepción parcial) Parcial → Recibida; o Anulada con motivo.
    /// Cada recepción actualiza inventario y genera la cuenta por pagar en una sola transacción (BD).
    /// </summary>
    public class OrdenCompraNegocio
    {
        private readonly OrdenCompraDatos ordenCompraDatos;

        public OrdenCompraNegocio()
        {
            ordenCompraDatos = new OrdenCompraDatos();
        }

        public (List<OrdenCompra> lista, int total) ConsultarOrdenesCompra(OrdenCompraFiltroDTO f)
        {
            if (f.FechaDesde is not null && f.FechaHasta is not null && f.FechaDesde > f.FechaHasta)
                throw new ExcepcionNegocio("La fecha inicial no puede ser mayor que la fecha final.", 400, 51024);
            return ordenCompraDatos.ConsultarOrdenesCompra(f.Buscar, f.Estado, f.IdProveedor, f.IdBodega,
                f.FechaDesde, f.FechaHasta, f.SoloAtrasadas, f.OrdenarPor, f.Direccion.ToUpperInvariant(), f.Pagina, f.TamanoPagina);
        }

        public (OrdenCompra orden, List<OrdenCompraDetalle> lineas, List<Recepcion> recepciones, List<HistorialOrden> historial)
            BuscarOrdenCompra(int idOrdenCompra)
        {
            var r = ordenCompraDatos.BuscarOrdenCompra(idOrdenCompra);
            if (r.orden is null) throw new ExcepcionNegocio("La orden de compra no existe.", 404, 52002);
            return (r.orden, r.lineas, r.recepciones, r.historial);
        }

        public OrdenCompra AgregarOrdenCompra(OrdenCompra orden, string usuario)
        {
            ValidarLineas(orden);
            return ordenCompraDatos.AgregarOrdenCompra(orden, usuario);
        }

        public OrdenCompra EditarOrdenCompra(OrdenCompra orden, string usuario)
        {
            if (orden.RowVersion is null)
                throw new ExcepcionNegocio("Se requiere el rowVersion para editar.", 400, 51002);
            ValidarLineas(orden);
            return ordenCompraDatos.EditarOrdenCompra(orden, usuario);
        }

        public OrdenCompra AprobarOrdenCompra(int idOrdenCompra, byte[]? rowVersion, string usuario)
            => ordenCompraDatos.AprobarOrdenCompra(idOrdenCompra, rowVersion, usuario);

        // Eliminar = anulación lógica con motivo (solo si no tiene recepciones)
        public OrdenCompra EliminarOrdenCompra(int idOrdenCompra, string? motivo, byte[]? rowVersion, string usuario)
        {
            if (string.IsNullOrWhiteSpace(motivo) || motivo.Trim().Length < 10)
                throw new ExcepcionNegocio("El motivo de anulación es obligatorio (mínimo 10 caracteres).", 400, 51017);
            return ordenCompraDatos.AnularOrdenCompra(idOrdenCompra, motivo.Trim(), rowVersion, usuario);
        }

        // Proceso integrado: recepción → inventario → cuenta por pagar
        public Recepcion RecibirOrdenCompra(RecepcionAgregarDTO r, string usuario)
        {
            if (r.Lineas.Count == 0)
                throw new ExcepcionNegocio("Indique al menos una línea recibida.", 400, 51020);
            var lineas = r.Lineas.Select(l => new RecepcionDetalle { IdDetalleOrden = l.IdDetalle, Cantidad = l.Cantidad }).ToList();
            return ordenCompraDatos.RecibirOrdenCompra(r.IdOrdenCompra, r.FechaRecepcion, r.SerieFactura?.Trim(),
                r.NumeroFactura.Trim(), r.Observaciones, lineas, usuario);
        }

        public (List<Recepcion> lista, int total) ConsultarRecepciones(RecepcionFiltroDTO f)
            => ordenCompraDatos.ConsultarRecepciones(f.IdOrdenCompra, f.IdProveedor, f.Cumplimiento,
                f.FechaDesde, f.FechaHasta, f.Pagina, f.TamanoPagina);

        public (Recepcion recepcion, List<RecepcionDetalle> lineas) BuscarRecepcion(int idRecepcion)
        {
            var r = ordenCompraDatos.BuscarRecepcion(idRecepcion);
            if (r.recepcion is null) throw new ExcepcionNegocio("La recepción no existe.", 404, 52003);
            return (r.recepcion, r.lineas);
        }

        private static void ValidarLineas(OrdenCompra orden)
        {
            if (orden.Detalle.Count == 0)
                throw new ExcepcionNegocio("La orden debe tener al menos una línea.", 400, 51020);
            if (orden.Detalle.GroupBy(d => d.IdProducto).Any(g => g.Count() > 1))
                throw new ExcepcionNegocio("Un producto no puede repetirse en la misma orden.", 400, 51023);
        }
    }
}
