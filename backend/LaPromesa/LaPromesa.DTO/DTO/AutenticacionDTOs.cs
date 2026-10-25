using System.ComponentModel.DataAnnotations;

namespace LaPromesa.DTO.DTO
{
    public class IniciarSesionDTO
    {
        [Required(ErrorMessage = "El usuario es obligatorio."), StringLength(50, MinimumLength = 3, ErrorMessage = "Debe tener entre {2} y {1} caracteres.")]
        public string Usuario { get; set; } = string.Empty;
        [Required(ErrorMessage = "La contraseña es obligatoria."), StringLength(100, MinimumLength = 6, ErrorMessage = "Debe tener entre {2} y {1} caracteres.")]
        public string Contrasena { get; set; } = string.Empty;
    }

    public class RefreshTokenDTO
    {
        [Required(ErrorMessage = "El refresh token es obligatorio.")]
        public string RefreshToken { get; set; } = string.Empty;
    }

    public class UsuarioSesionDTO
    {
        public int IdUsuario { get; set; }
        public string Usuario { get; set; } = string.Empty;
        public string NombreCompleto { get; set; } = string.Empty;
        public string Rol { get; set; } = string.Empty;
    }

    public class TokenDTO
    {
        public string AccessToken { get; set; } = string.Empty;
        public DateTime AccessTokenExpira { get; set; }
        public string RefreshToken { get; set; } = string.Empty;
        public DateTime RefreshTokenExpira { get; set; }
        public UsuarioSesionDTO Usuario { get; set; } = new();
    }
}
