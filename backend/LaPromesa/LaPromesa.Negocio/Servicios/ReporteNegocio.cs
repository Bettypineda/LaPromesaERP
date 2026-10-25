using LaPromesa.Datos.Datos;
using LaPromesa.DTO.DTO;
using LaPromesa.Utilidades.Excepciones;

namespace LaPromesa.Negocio.Servicios
{
    /// <summary>Los tres reportes del módulo (compras, cumplimiento y cuentas por pagar).</summary>
    public class ReporteNegocio
    {
        private readonly ReporteDatos reporteDatos;

        public ReporteNegocio()
        {
            reporteDatos = new ReporteDatos();
        }

        public ReporteDTO ReporteComprasPorProveedor(ReportePeriodoFiltroDTO f)
        {
            var (desde, hasta) = Periodo(f);
            var r = reporteDatos.ReporteComprasPorProveedor(desde, hasta, f.IdProveedor, f.IdCategoria, f.IdBodega, f.Estado, f.IncluirAnuladas);
            return new ReporteDTO { Resumen = r.resumen, Detalle = r.detalle, Totales = r.totales };
        }

        public ReporteDTO ReporteCumplimientoProveedores(ReportePeriodoFiltroDTO f)
        {
            var (desde, hasta) = Periodo(f);
            var r = reporteDatos.ReporteCumplimientoProveedores(desde, hasta, f.IdProveedor, f.IdCategoria);
            return new ReporteDTO { Resumen = r.resumen, Detalle = r.detalle, Totales = r.totales };
        }

        public ReporteDTO ReporteCuentasPorPagar(ReporteCuentasFiltroDTO f)
        {
            var r = reporteDatos.ReporteCuentasPorPagar(f.FechaCorte, f.IdProveedor, f.IdCategoria, f.IncluirPagadas);
            return new ReporteDTO { Resumen = r.resumen, Detalle = r.detalle, Totales = r.totales };
        }

        private static (DateOnly, DateOnly) Periodo(ReportePeriodoFiltroDTO f)
        {
            if (f.FechaDesde is null || f.FechaHasta is null || f.FechaDesde > f.FechaHasta)
                throw new ExcepcionNegocio("Indique un rango de fechas válido (desde <= hasta).", 400, 51050);
            return (f.FechaDesde.Value, f.FechaHasta.Value);
        }
    }
}
