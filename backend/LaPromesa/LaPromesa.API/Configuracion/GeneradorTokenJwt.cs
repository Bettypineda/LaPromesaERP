using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using LaPromesa.Entidades.Entidades;
using LaPromesa.Utilidades.Configuracion;
using Microsoft.IdentityModel.Tokens;

namespace LaPromesa.API.Configuracion
{
    /// <summary>Firma el access token JWT (HMAC-SHA256) con usuario y rol.</summary>
    public static class GeneradorTokenJwt
    {
        public static (string token, DateTime expira) Generar(Usuario usuario)
        {
            var expira = DateTime.UtcNow.AddMinutes(ConfiguracionJwt.MinutosAccessToken);
            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, usuario.IdUsuario.ToString()),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
                new Claim(ClaimTypes.Name, usuario.NombreUsuario),
                new Claim(ClaimTypes.Role, usuario.Rol),
                new Claim("nombre", usuario.NombreCompleto)
            };
            var credenciales = new SigningCredentials(
                new SymmetricSecurityKey(Encoding.UTF8.GetBytes(ConfiguracionJwt.Clave)), SecurityAlgorithms.HmacSha256);
            var jwt = new JwtSecurityToken(ConfiguracionJwt.Emisor, ConfiguracionJwt.Audiencia, claims,
                notBefore: DateTime.UtcNow, expires: expira, signingCredentials: credenciales);
            return (new JwtSecurityTokenHandler().WriteToken(jwt), expira);
        }
    }
}
