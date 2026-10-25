using LaPromesa.API.Configuracion;
using LaPromesa.DTO.DTO;
using LaPromesa.Negocio.Servicios;
using LaPromesa.Utilidades.Configuracion;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LaPromesa.API.Controllers
{
    /// <summary>Cuentas por pagar a proveedores y pagos (integración con la API bancaria externa).</summary>
    [Route("api/[controller]")]
    [Authorize(Roles = RolesSistema.VerFinanzas)]
    public class CuentasPorPagarController : ControladorBase
    {
        private readonly CuentaPorPagarNegocio cuentaNegocio;

        public CuentasPorPagarController()
        {
            cuentaNegocio = new CuentaPorPagarNegocio();
        }

        [HttpGet("ConsultarCuentasPorPagar")]
        public ActionResult<RespuestaApi<ResultadoPaginadoDTO<CuentaPorPagarConsultaDTO>>> ConsultarCuentasPorPagar([FromQuery] CuentaPorPagarFiltroDTO filtro)
        {
            try
            {
                var (lista, total) = cuentaNegocio.ConsultarCuentasPorPagar(filtro);
                return Ok(new RespuestaApi<ResultadoPaginadoDTO<CuentaPorPagarConsultaDTO>>
                {
                    Exito = true,
                    Mensaje = "Cuentas por pagar consultadas correctamente.",
                    Datos = Paginado(Mapeador.MapearLista<CuentaPorPagarConsultaDTO>(lista), total, filtro.Pagina, filtro.TamanoPagina)
                });
            }
            catch (Exception ex) { return Error<ResultadoPaginadoDTO<CuentaPorPagarConsultaDTO>>(ex, "Ocurrió un error al consultar las cuentas por pagar."); }
        }

        [HttpGet("BuscarCuentaPorPagar/{codigoCuentaPagar:int}")]
        public ActionResult<RespuestaApi<CuentaPorPagarDetalleDTO>> BuscarCuentaPorPagar(int codigoCuentaPagar)
        {
            try
            {
                var r = cuentaNegocio.BuscarCuentaPorPagar(codigoCuentaPagar);
                return Ok(new RespuestaApi<CuentaPorPagarDetalleDTO>
                {
                    Exito = true,
                    Mensaje = "Cuenta por pagar encontrada correctamente.",
                    Datos = new CuentaPorPagarDetalleDTO
                    {
                        Cuenta = Mapeador.Mapear<CuentaPorPagarConsultaDTO>(r.cuenta),
                        Pagos = Mapeador.MapearLista<PagoConsultaDTO>(r.pagos)
                    }
                });
            }
            catch (Exception ex) { return Error<CuentaPorPagarDetalleDTO>(ex, "Ocurrió un error al buscar la cuenta por pagar."); }
        }

        /// <summary>
        /// Registra un pago. Transferencia: se envía a la API bancaria y queda Aprobado, Rechazado
        /// o Pendiente (si el banco no respondió; se reintenta con ReintentarPago). Cheque/Efectivo: Aprobado.
        /// </summary>
        [HttpPost("PagarCuentaPorPagar")]
        [Authorize(Roles = RolesSistema.RegistrarPagos)]
        public ActionResult<RespuestaApi<PagoConsultaDTO>> PagarCuentaPorPagar([FromBody] PagoAgregarDTO dto)
        {
            try
            {
                var pago = cuentaNegocio.PagarCuentaPorPagar(dto, UsuarioActual);
                return Ok(new RespuestaApi<PagoConsultaDTO>
                {
                    Exito = pago.Estado != "Rechazado",
                    Mensaje = pago.Estado switch
                    {
                        "Aprobado" => $"Pago {pago.Numero} aprobado.",
                        "Rechazado" => $"Pago {pago.Numero} rechazado: {pago.MensajeBanco}",
                        _ => $"Pago {pago.Numero} pendiente de respuesta del banco: {pago.MensajeBanco}"
                    },
                    Datos = Mapeador.Mapear<PagoConsultaDTO>(pago)
                });
            }
            catch (Exception ex) { return Error<PagoConsultaDTO>(ex, "Ocurrió un error al registrar el pago."); }
        }

        [HttpGet("ConsultarPagosPendientes")]
        [Authorize(Roles = RolesSistema.RegistrarPagos)]
        public ActionResult<RespuestaApi<List<PagoConsultaDTO>>> ConsultarPagosPendientes()
        {
            try
            {
                return Ok(new RespuestaApi<List<PagoConsultaDTO>>
                {
                    Exito = true,
                    Mensaje = "Pagos pendientes consultados correctamente.",
                    Datos = Mapeador.MapearLista<PagoConsultaDTO>(cuentaNegocio.ConsultarPagosPendientes())
                });
            }
            catch (Exception ex) { return Error<List<PagoConsultaDTO>>(ex, "Ocurrió un error al consultar los pagos pendientes."); }
        }

        [HttpPut("ReintentarPago/{codigoPago:int}")]
        [Authorize(Roles = RolesSistema.RegistrarPagos)]
        public ActionResult<RespuestaApi<PagoConsultaDTO>> ReintentarPago(int codigoPago)
        {
            try
            {
                var pago = cuentaNegocio.ReintentarPago(codigoPago, UsuarioActual);
                return Ok(new RespuestaApi<PagoConsultaDTO>
                {
                    Exito = pago.Estado != "Rechazado",
                    Mensaje = $"Pago {pago.Numero}: {pago.Estado}. {pago.MensajeBanco}",
                    Datos = Mapeador.Mapear<PagoConsultaDTO>(pago)
                });
            }
            catch (Exception ex) { return Error<PagoConsultaDTO>(ex, "Ocurrió un error al reintentar el pago."); }
        }
    }
}
