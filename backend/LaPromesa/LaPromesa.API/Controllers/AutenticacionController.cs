using System.Security.Claims;
using LaPromesa.API.Configuracion;
using LaPromesa.DTO.DTO;
using LaPromesa.Negocio.Servicios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LaPromesa.API.Controllers
{
    /// <summary>Inicio de sesión, renovación del token y cierre de sesión (JWT + refresh token).</summary>
    [Route("api/[controller]")]
    public class AutenticacionController : ControladorBase
    {
        private readonly AutenticacionNegocio autenticacionNegocio;

        public AutenticacionController()
        {
            autenticacionNegocio = new AutenticacionNegocio();
        }

        // Método Iniciar Sesión: access token (15 min) + refresh token (7 días)
        [HttpPost("IniciarSesion")]
        [AllowAnonymous]
        public ActionResult<RespuestaApi<TokenDTO>> IniciarSesion([FromBody] IniciarSesionDTO dto)
        {
            try
            {
                var usuario = autenticacionNegocio.ValidarCredenciales(dto.Usuario, dto.Contrasena);
                var (refresh, refreshExpira) = autenticacionNegocio.CrearRefreshToken(usuario.IdUsuario, Ip());
                return Ok(new RespuestaApi<TokenDTO>
                {
                    Exito = true,
                    Mensaje = "Sesión iniciada correctamente.",
                    Datos = ArmarToken(usuario, refresh, refreshExpira)
                });
            }
            catch (Exception ex) { return Error<TokenDTO>(ex, "Ocurrió un error al iniciar sesión."); }
        }

        // Método Renovar Token: el refresh token usado queda invalidado (rotación)
        [HttpPost("RenovarToken")]
        [AllowAnonymous]
        public ActionResult<RespuestaApi<TokenDTO>> RenovarToken([FromBody] RefreshTokenDTO dto)
        {
            try
            {
                var (usuario, refresh, refreshExpira) = autenticacionNegocio.RenovarToken(dto.RefreshToken, Ip());
                return Ok(new RespuestaApi<TokenDTO>
                {
                    Exito = true,
                    Mensaje = "Token renovado correctamente.",
                    Datos = ArmarToken(usuario, refresh, refreshExpira)
                });
            }
            catch (Exception ex) { return Error<TokenDTO>(ex, "Ocurrió un error al renovar el token."); }
        }

        // Método Cerrar Sesión: invalida el refresh token
        [HttpPost("CerrarSesion")]
        [Authorize]
        public ActionResult<RespuestaApi<bool>> CerrarSesion([FromBody] RefreshTokenDTO dto)
        {
            try
            {
                autenticacionNegocio.CerrarSesion(dto.RefreshToken);
                return Ok(new RespuestaApi<bool> { Exito = true, Mensaje = "Sesión cerrada correctamente.", Datos = true });
            }
            catch (Exception ex) { return Error<bool>(ex, "Ocurrió un error al cerrar sesión."); }
        }

        // Método Usuario Actual
        [HttpGet("UsuarioActual")]
        [Authorize]
        public ActionResult<RespuestaApi<UsuarioSesionDTO>> ConsultarUsuarioActual()
        {
            return Ok(new RespuestaApi<UsuarioSesionDTO>
            {
                Exito = true,
                Mensaje = "Usuario autenticado.",
                Datos = new UsuarioSesionDTO
                {
                    IdUsuario = int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : 0,
                    Usuario = User.Identity?.Name ?? "",
                    NombreCompleto = User.FindFirstValue("nombre") ?? "",
                    Rol = User.FindFirstValue(ClaimTypes.Role) ?? ""
                }
            });
        }

        private static TokenDTO ArmarToken(Entidades.Entidades.Usuario usuario, string refresh, DateTime refreshExpira)
        {
            var (access, accessExpira) = GeneradorTokenJwt.Generar(usuario);
            return new TokenDTO
            {
                AccessToken = access,
                AccessTokenExpira = accessExpira,
                RefreshToken = refresh,
                RefreshTokenExpira = refreshExpira,
                Usuario = new UsuarioSesionDTO
                {
                    IdUsuario = usuario.IdUsuario,
                    Usuario = usuario.NombreUsuario,
                    NombreCompleto = usuario.NombreCompleto,
                    Rol = usuario.Rol
                }
            };
        }

        private string? Ip() => HttpContext.Connection.RemoteIpAddress?.ToString();
    }
}
