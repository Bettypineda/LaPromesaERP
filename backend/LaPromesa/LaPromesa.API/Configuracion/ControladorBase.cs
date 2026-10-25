using LaPromesa.DTO.DTO;
using LaPromesa.Utilidades.Excepciones;
using Microsoft.AspNetCore.Mvc;

namespace LaPromesa.API.Configuracion
{
    /// <summary>
    /// Base de los controladores: usuario autenticado y respuestas de error con el formato RespuestaApi.
    ///   ExcepcionNegocio → 400 / 401 / 404 / 409 con el mensaje de la regla.
    ///   Otros errores    → 500 (el detalle técnico solo se muestra en Development).
    /// </summary>
    [ApiController]
    [Produces("application/json")]
    public abstract class ControladorBase : ControllerBase
    {
        protected string UsuarioActual
            => User.Identity?.Name ?? throw new ExcepcionNegocio("Sesión no válida.", 401);

        protected ObjectResult Error<T>(Exception ex, string mensajeGeneral)
        {
            if (ex is ExcepcionNegocio negocio)
            {
                return StatusCode(negocio.EstadoHttp, new RespuestaApi<T>
                {
                    Exito = false,
                    Mensaje = negocio.Message,
                    Datos = default,
                    Detalle = negocio.Codigo is null ? null : $"Código {negocio.Codigo}"
                });
            }

            var entorno = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>();
            HttpContext.RequestServices.GetRequiredService<ILogger<ControladorBase>>()
                .LogError(ex, "Error no controlado en {Ruta}", HttpContext.Request.Path);

            return StatusCode(500, new RespuestaApi<T>
            {
                Exito = false,
                Mensaje = mensajeGeneral,
                Datos = default,
                Detalle = entorno.IsDevelopment() ? ex.Message : null
            });
        }

        protected static ResultadoPaginadoDTO<T> Paginado<T>(List<T> registros, int total, int pagina, int tamano)
            => new() { Registros = registros, Total = total, Pagina = pagina, TamanoPagina = tamano };
    }
}
