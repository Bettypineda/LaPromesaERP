using LaPromesa.API.Configuracion;
using LaPromesa.DTO.DTO;
using LaPromesa.Negocio.Servicios;
using LaPromesa.Utilidades.Configuracion;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LaPromesa.API.Controllers
{
    /// <summary>
    /// Reportes con filtros. Devuelven { totales, resumen, detalle } o un CSV para Excel con formato=csv.
    /// La impresión / PDF se hace desde el frontend.
    /// </summary>
    [Route("api/[controller]")]
    [Authorize(Roles = RolesSistema.VerReportes)]
    public class ReportesController : ControladorBase
    {
        private readonly ReporteNegocio reporteNegocio;

        public ReportesController()
        {
            reporteNegocio = new ReporteNegocio();
        }

        // Reporte 1: compras por proveedor y período
        [HttpGet("ReporteComprasPorProveedor")]
        public ActionResult<RespuestaApi<ReporteDTO>> ReporteComprasPorProveedor([FromQuery] ReportePeriodoFiltroDTO filtro)
        {
            try { return Responder(reporteNegocio.ReporteComprasPorProveedor(filtro), filtro.Formato, "compras_por_proveedor"); }
            catch (Exception ex) { return Error<ReporteDTO>(ex, "Ocurrió un error al generar el reporte de compras."); }
        }

        // Reporte 2: cumplimiento de entregas de proveedores (a tiempo, retraso, anticipada - RQ27)
        [HttpGet("ReporteCumplimientoProveedores")]
        public ActionResult<RespuestaApi<ReporteDTO>> ReporteCumplimientoProveedores([FromQuery] ReportePeriodoFiltroDTO filtro)
        {
            try { return Responder(reporteNegocio.ReporteCumplimientoProveedores(filtro), filtro.Formato, "cumplimiento_proveedores"); }
            catch (Exception ex) { return Error<ReporteDTO>(ex, "Ocurrió un error al generar el reporte de cumplimiento."); }
        }

        // Reporte 3: cuentas por pagar por vencimiento (antigüedad de saldos a una fecha de corte)
        [HttpGet("ReporteCuentasPorPagar")]
        public ActionResult<RespuestaApi<ReporteDTO>> ReporteCuentasPorPagar([FromQuery] ReporteCuentasFiltroDTO filtro)
        {
            try { return Responder(reporteNegocio.ReporteCuentasPorPagar(filtro), filtro.Formato, "cuentas_por_pagar"); }
            catch (Exception ex) { return Error<ReporteDTO>(ex, "Ocurrió un error al generar el reporte de cuentas por pagar."); }
        }

        private ActionResult Responder(ReporteDTO reporte, string? formato, string nombre)
        {
            if (string.Equals(formato, "csv", StringComparison.OrdinalIgnoreCase))
                return File(ExportadorCsv.Generar(reporte), "text/csv; charset=utf-8", $"{nombre}_{DateTime.Now:yyyyMMdd_HHmm}.csv");

            return Ok(new RespuestaApi<ReporteDTO>
            {
                Exito = true,
                Mensaje = $"Reporte generado: {reporte.Detalle.Count} registros.",
                Datos = reporte
            });
        }
    }
}
