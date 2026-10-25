using LaPromesa.API.Configuracion;
using LaPromesa.DTO.DTO;
using LaPromesa.Negocio.Servicios;
using LaPromesa.Utilidades.Configuracion;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LaPromesa.API.Controllers
{
    /// <summary>Catálogos para formularios (TEMPORAL: bodegas y productos de inv.*, módulo de Inventarios).</summary>
    [Route("api/[controller]")]
    [Authorize]
    public class CatalogosController : ControladorBase
    {
        private readonly CatalogoNegocio catalogoNegocio;

        public CatalogosController()
        {
            catalogoNegocio = new CatalogoNegocio();
        }

        [HttpGet("ConsultarBodegas")]
        public ActionResult<RespuestaApi<List<BodegaDTO>>> ConsultarBodegas()
        {
            try
            {
                return Ok(new RespuestaApi<List<BodegaDTO>>
                {
                    Exito = true,
                    Mensaje = "Bodegas consultadas correctamente.",
                    Datos = Mapeador.MapearLista<BodegaDTO>(catalogoNegocio.ConsultarBodegas())
                });
            }
            catch (Exception ex) { return Error<List<BodegaDTO>>(ex, "Ocurrió un error al consultar las bodegas."); }
        }

        [HttpGet("ConsultarProductos")]
        public ActionResult<RespuestaApi<List<ProductoDTO>>> ConsultarProductos([FromQuery] string? buscar)
        {
            try
            {
                return Ok(new RespuestaApi<List<ProductoDTO>>
                {
                    Exito = true,
                    Mensaje = "Productos consultados correctamente.",
                    Datos = Mapeador.MapearLista<ProductoDTO>(catalogoNegocio.ConsultarProductos(buscar))
                });
            }
            catch (Exception ex) { return Error<List<ProductoDTO>>(ex, "Ocurrió un error al consultar los productos."); }
        }
    }
}
