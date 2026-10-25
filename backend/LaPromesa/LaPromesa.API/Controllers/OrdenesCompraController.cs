using LaPromesa.API.Configuracion;
using LaPromesa.DTO.DTO;
using LaPromesa.Entidades.Entidades;
using LaPromesa.Negocio.Servicios;
using LaPromesa.Utilidades.Configuracion;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LaPromesa.API.Controllers
{
    /// <summary>CRUD de Órdenes de compra (RQ04) y su proceso: aprobar, anular y recibir mercadería.</summary>
    [Route("api/[controller]")]
    [Authorize]
    public class OrdenesCompraController : ControladorBase
    {
        private readonly OrdenCompraNegocio ordenCompraNegocio;

        public OrdenesCompraController()
        {
            ordenCompraNegocio = new OrdenCompraNegocio();
        }

        // Método Consultar Órdenes de compra
        [HttpGet("ConsultarOrdenesCompra")]
        public ActionResult<RespuestaApi<ResultadoPaginadoDTO<OrdenCompraConsultaDTO>>> ConsultarOrdenesCompra([FromQuery] OrdenCompraFiltroDTO filtro)
        {
            try
            {
                var (lista, total) = ordenCompraNegocio.ConsultarOrdenesCompra(filtro);
                return Ok(new RespuestaApi<ResultadoPaginadoDTO<OrdenCompraConsultaDTO>>
                {
                    Exito = true,
                    Mensaje = "Órdenes de compra consultadas correctamente.",
                    Datos = Paginado(Mapeador.MapearLista<OrdenCompraConsultaDTO>(lista), total, filtro.Pagina, filtro.TamanoPagina)
                });
            }
            catch (Exception ex) { return Error<ResultadoPaginadoDTO<OrdenCompraConsultaDTO>>(ex, "Ocurrió un error al consultar las órdenes de compra."); }
        }

        // Método Buscar Orden de compra (encabezado, líneas, recepciones e historial de estados)
        [HttpGet("BuscarOrdenCompra/{codigoOrdenCompra:int}")]
        public ActionResult<RespuestaApi<OrdenCompraDetalleDTO>> BuscarOrdenCompra(int codigoOrdenCompra)
        {
            try
            {
                var r = ordenCompraNegocio.BuscarOrdenCompra(codigoOrdenCompra);
                return Ok(new RespuestaApi<OrdenCompraDetalleDTO>
                {
                    Exito = true,
                    Mensaje = "Orden de compra encontrada correctamente.",
                    Datos = new OrdenCompraDetalleDTO
                    {
                        Orden = Mapeador.Mapear<OrdenCompraConsultaDTO>(r.orden),
                        Lineas = Mapeador.MapearLista<OrdenCompraLineaDTO>(r.lineas),
                        Recepciones = Mapeador.MapearLista<RecepcionConsultaDTO>(r.recepciones),
                        Historial = Mapeador.MapearLista<HistorialOrdenDTO>(r.historial)
                    }
                });
            }
            catch (Exception ex) { return Error<OrdenCompraDetalleDTO>(ex, "Ocurrió un error al buscar la orden de compra."); }
        }

        // Método Agregar Orden de compra (queda Pendiente; el total lo calcula la base de datos)
        [HttpPost("AgregarOrdenCompra")]
        [Authorize(Roles = RolesSistema.CrearCompras)]
        public ActionResult<RespuestaApi<OrdenCompraConsultaDTO>> AgregarOrdenCompra([FromBody] OrdenCompraAgregarDTO dto)
        {
            try
            {
                var creada = ordenCompraNegocio.AgregarOrdenCompra(ConvertirOrden(dto), UsuarioActual);
                return StatusCode(201, new RespuestaApi<OrdenCompraConsultaDTO>
                {
                    Exito = true,
                    Mensaje = $"Orden de compra {creada.Numero} agregada correctamente.",
                    Datos = Mapeador.Mapear<OrdenCompraConsultaDTO>(creada)
                });
            }
            catch (Exception ex) { return Error<OrdenCompraConsultaDTO>(ex, "Ocurrió un error al agregar la orden de compra."); }
        }

        // Método Editar Orden de compra (solo en estado Pendiente)
        [HttpPut("EditarOrdenCompra")]
        [Authorize(Roles = RolesSistema.CrearCompras)]
        public ActionResult<RespuestaApi<OrdenCompraConsultaDTO>> EditarOrdenCompra([FromBody] OrdenCompraEditarDTO dto)
        {
            try
            {
                var orden = ConvertirOrden(dto);
                orden.IdOrdenCompra = dto.IdOrdenCompra;
                orden.RowVersion = dto.RowVersion;
                var editada = ordenCompraNegocio.EditarOrdenCompra(orden, UsuarioActual);
                return Ok(new RespuestaApi<OrdenCompraConsultaDTO>
                {
                    Exito = true,
                    Mensaje = "Orden de compra editada correctamente.",
                    Datos = Mapeador.Mapear<OrdenCompraConsultaDTO>(editada)
                });
            }
            catch (Exception ex) { return Error<OrdenCompraConsultaDTO>(ex, "Ocurrió un error al editar la orden de compra."); }
        }

        // Método Aprobar Orden de compra (quien la creó no puede aprobarla; valida límite de crédito)
        [HttpPut("AprobarOrdenCompra")]
        [Authorize(Roles = RolesSistema.AutorizarCompras)]
        public ActionResult<RespuestaApi<OrdenCompraConsultaDTO>> AprobarOrdenCompra([FromBody] OrdenCompraAprobarDTO dto)
        {
            try
            {
                var aprobada = ordenCompraNegocio.AprobarOrdenCompra(dto.IdOrdenCompra, dto.RowVersion, UsuarioActual);
                return Ok(new RespuestaApi<OrdenCompraConsultaDTO>
                {
                    Exito = true,
                    Mensaje = "Orden de compra aprobada correctamente.",
                    Datos = Mapeador.Mapear<OrdenCompraConsultaDTO>(aprobada)
                });
            }
            catch (Exception ex) { return Error<OrdenCompraConsultaDTO>(ex, "Ocurrió un error al aprobar la orden de compra."); }
        }

        // Método Eliminar Orden de compra: ANULACIÓN lógica con motivo (solo sin recepciones)
        [HttpDelete("EliminarOrdenCompra/{codigoOrdenCompra:int}")]
        [Authorize(Roles = RolesSistema.AutorizarCompras)]
        public ActionResult<RespuestaApi<OrdenCompraConsultaDTO>> EliminarOrdenCompra(int codigoOrdenCompra, [FromQuery] string? motivo, [FromQuery] string? rowVersion)
        {
            try
            {
                var anulada = ordenCompraNegocio.EliminarOrdenCompra(codigoOrdenCompra, motivo,
                    ProveedoresController.RowVersionDesdeTexto(rowVersion), UsuarioActual);
                return Ok(new RespuestaApi<OrdenCompraConsultaDTO>
                {
                    Exito = true,
                    Mensaje = "Orden de compra anulada correctamente (eliminación lógica).",
                    Datos = Mapeador.Mapear<OrdenCompraConsultaDTO>(anulada)
                });
            }
            catch (Exception ex) { return Error<OrdenCompraConsultaDTO>(ex, "Ocurrió un error al anular la orden de compra."); }
        }

        // Método Recibir Orden de compra: PROCESO recepción → inventario → cuenta por pagar
        [HttpPost("RecibirOrdenCompra")]
        [Authorize(Roles = RolesSistema.RecibirMercaderia)]
        public ActionResult<RespuestaApi<RecepcionConsultaDTO>> RecibirOrdenCompra([FromBody] RecepcionAgregarDTO dto)
        {
            try
            {
                var recepcion = ordenCompraNegocio.RecibirOrdenCompra(dto, UsuarioActual);
                return StatusCode(201, new RespuestaApi<RecepcionConsultaDTO>
                {
                    Exito = true,
                    Mensaje = $"Recepción {recepcion.Numero} registrada: inventario actualizado y cuenta por pagar {recepcion.NumeroCuentaPagar} generada.",
                    Datos = Mapeador.Mapear<RecepcionConsultaDTO>(recepcion)
                });
            }
            catch (Exception ex) { return Error<RecepcionConsultaDTO>(ex, "Ocurrió un error al registrar la recepción."); }
        }

        private static OrdenCompra ConvertirOrden(OrdenCompraAgregarDTO dto) => new()
        {
            IdProveedor = dto.IdProveedor,
            IdBodega = dto.IdBodega,
            FechaOrden = dto.FechaOrden ?? default,
            FechaEsperada = dto.FechaEsperada ?? default,
            Observaciones = dto.Observaciones,
            Detalle = dto.Lineas.Select(l => new OrdenCompraDetalle
            {
                IdProducto = l.IdProducto,
                CantidadPedida = l.CantidadPedida,
                CostoUnitario = l.CostoUnitario
            }).ToList()
        };
    }

    /// <summary>Consulta de recepciones (notas de compra, documentos definitivos).</summary>
    [Route("api/[controller]")]
    [Authorize]
    public class RecepcionesController : ControladorBase
    {
        private readonly OrdenCompraNegocio ordenCompraNegocio;

        public RecepcionesController()
        {
            ordenCompraNegocio = new OrdenCompraNegocio();
        }

        [HttpGet("ConsultarRecepciones")]
        public ActionResult<RespuestaApi<ResultadoPaginadoDTO<RecepcionConsultaDTO>>> ConsultarRecepciones([FromQuery] RecepcionFiltroDTO filtro)
        {
            try
            {
                var (lista, total) = ordenCompraNegocio.ConsultarRecepciones(filtro);
                return Ok(new RespuestaApi<ResultadoPaginadoDTO<RecepcionConsultaDTO>>
                {
                    Exito = true,
                    Mensaje = "Recepciones consultadas correctamente.",
                    Datos = Paginado(Mapeador.MapearLista<RecepcionConsultaDTO>(lista), total, filtro.Pagina, filtro.TamanoPagina)
                });
            }
            catch (Exception ex) { return Error<ResultadoPaginadoDTO<RecepcionConsultaDTO>>(ex, "Ocurrió un error al consultar las recepciones."); }
        }

        [HttpGet("BuscarRecepcion/{codigoRecepcion:int}")]
        public ActionResult<RespuestaApi<RecepcionDetalleDTO>> BuscarRecepcion(int codigoRecepcion)
        {
            try
            {
                var r = ordenCompraNegocio.BuscarRecepcion(codigoRecepcion);
                return Ok(new RespuestaApi<RecepcionDetalleDTO>
                {
                    Exito = true,
                    Mensaje = "Recepción encontrada correctamente.",
                    Datos = new RecepcionDetalleDTO
                    {
                        Recepcion = Mapeador.Mapear<RecepcionConsultaDTO>(r.recepcion),
                        Lineas = Mapeador.MapearLista<RecepcionLineaDTO>(r.lineas)
                    }
                });
            }
            catch (Exception ex) { return Error<RecepcionDetalleDTO>(ex, "Ocurrió un error al buscar la recepción."); }
        }
    }
}
