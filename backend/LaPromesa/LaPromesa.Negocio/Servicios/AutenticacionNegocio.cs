using System.Security.Cryptography;
using System.Text;
using LaPromesa.Datos.Datos;
using LaPromesa.Entidades.Entidades;
using LaPromesa.Utilidades.Configuracion;
using LaPromesa.Utilidades.Excepciones;

namespace LaPromesa.Negocio.Servicios
{
    /// <summary>
    /// Inicio de sesión (BCrypt + bloqueo tras 5 intentos), refresh tokens con rotación
    /// (el usado se invalida; si se reutiliza uno revocado se cierran todas las sesiones) y cierre de sesión.
    /// El access token JWT lo firma la capa API.
    /// </summary>
    public class AutenticacionNegocio
    {
        private const string MensajeCredenciales = "Usuario o contraseña incorrectos.";
        // Hash de una cadena cualquiera: iguala el tiempo de respuesta cuando el usuario no existe.
        private const string HashFicticio = "$2a$11$jGkLtYNBWNjUVvmSEhf66.YkxfdMECOUzd0y3tyvPBb0tl8Vp5bkS";

        private readonly UsuarioDatos usuarioDatos;

        public AutenticacionNegocio()
        {
            usuarioDatos = new UsuarioDatos();
        }

        public Usuario ValidarCredenciales(string nombreUsuario, string contrasena)
        {
            var u = usuarioDatos.BuscarPorNombre(nombreUsuario.Trim());
            if (u is null || !u.Activo)
            {
                BCrypt.Net.BCrypt.Verify("tiempo-constante", HashFicticio);
                throw new ExcepcionNegocio(MensajeCredenciales, 401);
            }
            if (u.BloqueadoHasta is { } hasta && hasta > DateTime.UtcNow)
                throw new ExcepcionNegocio("Usuario bloqueado temporalmente por intentos fallidos. Intente en 15 minutos.", 401);

            if (!BCrypt.Net.BCrypt.Verify(contrasena, u.PasswordHash))
            {
                usuarioDatos.RegistrarIntentoFallido(u.IdUsuario);
                throw new ExcepcionNegocio(MensajeCredenciales, 401);
            }
            usuarioDatos.RegistrarAccesoExitoso(u.IdUsuario);
            return u;
        }

        /// <summary>Crea y guarda (como hash SHA-256) un refresh token nuevo.</summary>
        public (string token, DateTime expira) CrearRefreshToken(int idUsuario, string? ip)
        {
            var (token, hash, expira) = GenerarRefresh();
            usuarioDatos.GuardarRefreshToken(idUsuario, hash, expira, ip);
            return (token, expira);
        }

        /// <summary>Valida y rota el refresh token. Devuelve el usuario y el nuevo refresh token.</summary>
        public (Usuario usuario, string token, DateTime expira) RenovarToken(string refreshToken, string? ip)
        {
            var hash = Hash(refreshToken);
            var guardado = usuarioDatos.BuscarRefreshToken(hash)
                           ?? throw new ExcepcionNegocio("Refresh token inválido.", 401);

            if (guardado.RevocadoEn is not null)
            {
                usuarioDatos.RevocarTodos(guardado.IdUsuario, "Reutilizado");
                throw new ExcepcionNegocio("El refresh token ya fue utilizado. Inicie sesión nuevamente.", 401);
            }
            if (guardado.Expira <= DateTime.UtcNow)
                throw new ExcepcionNegocio("El refresh token expiró. Inicie sesión nuevamente.", 401);

            var u = usuarioDatos.BuscarPorId(guardado.IdUsuario);
            if (u is null || !u.Activo) throw new ExcepcionNegocio("Usuario inactivo.", 401);

            var (nuevo, nuevoHash, expira) = GenerarRefresh();
            if (!usuarioDatos.RevocarRefreshToken(hash, "Rotado", nuevoHash))
                throw new ExcepcionNegocio("El refresh token ya fue utilizado. Inicie sesión nuevamente.", 401);
            usuarioDatos.GuardarRefreshToken(u.IdUsuario, nuevoHash, expira, ip);
            return (u, nuevo, expira);
        }

        public void CerrarSesion(string refreshToken)
            => usuarioDatos.RevocarRefreshToken(Hash(refreshToken), "Logout", null);

        /// <summary>Crea un usuario demo por rol si no existen usuarios (solo Development).</summary>
        public int CrearUsuariosDemo(string contrasena)
        {
            if (usuarioDatos.ContarUsuarios() > 0) return 0;
            var usuarios = new (string usuario, string nombre, string rol)[]
            {
                ("admin", "Administrador del sistema", RolesSistema.Administrador),
                ("sara.compras", "Sara (Compras)", RolesSistema.Compras),
                ("gerente.general", "Gerente General", RolesSistema.Gerente),
                ("bodega.central", "Encargado Bodega Central", RolesSistema.Bodega),
                ("tesoreria", "Tesorería", RolesSistema.Tesoreria),
                ("consulta", "Usuario de consulta", RolesSistema.Consulta)
            };
            foreach (var (usuario, nombre, rol) in usuarios)
                usuarioDatos.AgregarUsuario(usuario, nombre, BCrypt.Net.BCrypt.HashPassword(contrasena, 11), rol);
            return usuarios.Length;
        }

        private static (string token, string hash, DateTime expira) GenerarRefresh()
        {
            var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64))
                .Replace('+', '-').Replace('/', '_').TrimEnd('=');
            return (token, Hash(token), DateTime.UtcNow.AddDays(ConfiguracionJwt.DiasRefreshToken));
        }

        private static string Hash(string token)
            => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    }
}
