using LaPromesa.API.Configuracion;
using LaPromesa.DTO.DTO;
using LaPromesa.Entidades.Entidades;
using LaPromesa.Negocio.Servicios;
using LaPromesa.Utilidades.Configuracion;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LaPromesa.API.Controllers
{
    /// <summary>CRUD de Proveedores (RQ25).</summary>
    [Route("api/[controller]")]
    [Authorize]
    public class ProveedoresController : ControladorBase
    {
        private readonly ProveedorNegocio proveedorNegocio;

        public ProveedoresController()
        {
            proveedorNegocio = new ProveedorNegocio();
        }

        // Método Consultar Proveedores (búsqueda, filtros, ordenamiento y paginación)
        [HttpGet("ConsultarProveedores")]
        public ActionResult<RespuestaApi<ResultadoPaginadoDTO<ProveedorConsultaDTO>>> ConsultarProveedores([FromQuery] ProveedorFiltroDTO filtro)
        {
            try
            {
                var (lista, total) = proveedorNegocio.ConsultarProveedores(filtro);
                return Ok(new RespuestaApi<ResultadoPaginadoDTO<ProveedorConsultaDTO>>
                {
                    Exito = true,
                    Mensaje = "Proveedores consultados correctamente.",
                    Datos = Paginado(Mapeador.MapearLista<ProveedorConsultaDTO>(lista), total, filtro.Pagina, filtro.TamanoPagina)
                });
            }
            catch (Exception ex) { return Error<ResultadoPaginadoDTO<ProveedorConsultaDTO>>(ex, "Ocurrió un error al consultar los proveedores."); }
        }

        // Método Buscar Proveedor (con últimas órdenes, cuentas por pagar y cumplimiento)
        [HttpGet("BuscarProveedor/{codigoProveedor:int}")]
        public ActionResult<RespuestaApi<ProveedorDetalleDTO>> BuscarProveedor(int codigoProveedor)
        {
            try
            {
                var r = proveedorNegocio.BuscarProveedor(codigoProveedor);
                return Ok(new RespuestaApi<ProveedorDetalleDTO>
                {
                    Exito = true,
                    Mensaje = "Proveedor encontrado correctamente.",
                    Datos = new ProveedorDetalleDTO
                    {
                        Proveedor = Mapeador.Mapear<ProveedorConsultaDTO>(r.proveedor),
                        UltimasOrdenes = Mapeador.MapearLista<OrdenCompraConsultaDTO>(r.ordenes),
                        CuentasPorPagar = Mapeador.MapearLista<CuentaPorPagarConsultaDTO>(r.cuentas),
                        Cumplimiento = r.cumplimiento is null ? null : Mapeador.Mapear<CumplimientoDTO>(r.cumplimiento)
                    }
                });
            }
            catch (Exception ex) { return Error<ProveedorDetalleDTO>(ex, "Ocurrió un error al buscar el proveedor."); }
        }

        // Método Agregar Proveedor
        [HttpPost("AgregarProveedor")]
        [Authorize(Roles = RolesSistema.GestionarProveedores)]
        public ActionResult<RespuestaApi<ProveedorConsultaDTO>> AgregarProveedor([FromBody] ProveedorAgregarDTO dto)
        {
            try
            {
                var creado = proveedorNegocio.AgregarProveedor(Mapeador.Mapear<Proveedor>(dto), UsuarioActual);
                return StatusCode(201, new RespuestaApi<ProveedorConsultaDTO>
                {
                    Exito = true,
                    Mensaje = $"Proveedor {creado.Codigo} agregado correctamente.",
                    Datos = Mapeador.Mapear<ProveedorConsultaDTO>(creado)
                });
            }
            catch (Exception ex) { return Error<ProveedorConsultaDTO>(ex, "Ocurrió un error al agregar el proveedor."); }
        }

        // Método Editar Proveedor
        [HttpPut("EditarProveedor")]
        [Authorize(Roles = RolesSistema.GestionarProveedores)]
        public ActionResult<RespuestaApi<ProveedorConsultaDTO>> EditarProveedor([FromBody] ProveedorEditarDTO dto)
        {
            try
            {
                var editado = proveedorNegocio.EditarProveedor(Mapeador.Mapear<Proveedor>(dto), UsuarioActual);
                return Ok(new RespuestaApi<ProveedorConsultaDTO>
                {
                    Exito = true,
                    Mensaje = "Proveedor editado correctamente.",
                    Datos = Mapeador.Mapear<ProveedorConsultaDTO>(editado)
                });
            }
            catch (Exception ex) { return Error<ProveedorConsultaDTO>(ex, "Ocurrió un error al editar el proveedor."); }
        }

        // Método Eliminar Proveedor: eliminación LÓGICA (queda Inactivo con fecha, usuario y motivo)
        [HttpDelete("EliminarProveedor/{codigoProveedor:int}")]
        [Authorize(Roles = RolesSistema.AutorizarCompras)]
        public ActionResult<RespuestaApi<ProveedorConsultaDTO>> EliminarProveedor(int codigoProveedor, [FromQuery] string? motivo, [FromQuery] string? rowVersion)
        {
            try
            {
                var inactivado = proveedorNegocio.EliminarProveedor(codigoProveedor, motivo, RowVersionDesdeTexto(rowVersion), UsuarioActual);
                return Ok(new RespuestaApi<ProveedorConsultaDTO>
                {
                    Exito = true,
                    Mensaje = "Proveedor inactivado correctamente (eliminación lógica).",
                    Datos = Mapeador.Mapear<ProveedorConsultaDTO>(inactivado)
                });
            }
            catch (Exception ex) { return Error<ProveedorConsultaDTO>(ex, "Ocurrió un error al eliminar el proveedor."); }
        }

        // Método Reactivar Proveedor
        [HttpPut("ReactivarProveedor/{codigoProveedor:int}")]
        [Authorize(Roles = RolesSistema.AutorizarCompras)]
        public ActionResult<RespuestaApi<ProveedorConsultaDTO>> ReactivarProveedor(int codigoProveedor, [FromQuery] string? rowVersion)
        {
            try
            {
                var reactivado = proveedorNegocio.ReactivarProveedor(codigoProveedor, RowVersionDesdeTexto(rowVersion), UsuarioActual);
                return Ok(new RespuestaApi<ProveedorConsultaDTO>
                {
                    Exito = true,
                    Mensaje = "Proveedor reactivado correctamente.",
                    Datos = Mapeador.Mapear<ProveedorConsultaDTO>(reactivado)
                });
            }
            catch (Exception ex) { return Error<ProveedorConsultaDTO>(ex, "Ocurrió un error al reactivar el proveedor."); }
        }

        internal static byte[]? RowVersionDesdeTexto(string? base64)
        {
            if (string.IsNullOrWhiteSpace(base64)) return null;
            try { return Convert.FromBase64String(base64); }
            catch (FormatException) { throw new Utilidades.Excepciones.ExcepcionNegocio("El rowVersion no tiene un formato válido.", 400); }
        }
    }

    /// <summary>Categorías de proveedor.</summary>
    [Route("api/[controller]")]
    [Authorize]
    public class CategoriasController : ControladorBase
    {
        private readonly ProveedorNegocio proveedorNegocio;

        public CategoriasController()
        {
            proveedorNegocio = new ProveedorNegocio();
        }

        [HttpGet("ConsultarCategorias")]
        public ActionResult<RespuestaApi<List<CategoriaConsultaDTO>>> ConsultarCategorias([FromQuery] bool soloActivas = true)
        {
            try
            {
                return Ok(new RespuestaApi<List<CategoriaConsultaDTO>>
                {
                    Exito = true,
                    Mensaje = "Categorías consultadas correctamente.",
                    Datos = Mapeador.MapearLista<CategoriaConsultaDTO>(proveedorNegocio.ConsultarCategorias(soloActivas))
                });
            }
            catch (Exception ex) { return Error<List<CategoriaConsultaDTO>>(ex, "Ocurrió un error al consultar las categorías."); }
        }

        [HttpPost("AgregarCategoria")]
        [Authorize(Roles = RolesSistema.GestionarProveedores)]
        public ActionResult<RespuestaApi<CategoriaConsultaDTO>> AgregarCategoria([FromBody] CategoriaAgregarDTO dto)
        {
            try
            {
                var creada = proveedorNegocio.AgregarCategoria(Mapeador.Mapear<Categoria>(dto), UsuarioActual);
                return StatusCode(201, new RespuestaApi<CategoriaConsultaDTO>
                {
                    Exito = true,
                    Mensaje = "Categoría agregada correctamente.",
                    Datos = Mapeador.Mapear<CategoriaConsultaDTO>(creada)
                });
            }
            catch (Exception ex) { return Error<CategoriaConsultaDTO>(ex, "Ocurrió un error al agregar la categoría."); }
        }
    }
}
