namespace LaPromesa.Utilidades.Configuracion
{
    /// <summary>Parámetros de los tokens JWT (se asignan en Program.cs).</summary>
    public class ConfiguracionJwt
    {
        public static string Emisor { get; set; } = string.Empty;
        public static string Audiencia { get; set; } = string.Empty;
        public static string Clave { get; set; } = string.Empty;
        public static int MinutosAccessToken { get; set; } = 15;
        public static int DiasRefreshToken { get; set; } = 7;
    }
}
