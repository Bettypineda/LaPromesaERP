namespace LaPromesa.Utilidades.Configuracion
{
    /// <summary>Datos de conexión a la API externa de pagos bancarios (BancoSimulado.API).</summary>
    public class ConfiguracionBanco
    {
        public static string UrlBase { get; set; } = "http://localhost:5100";
        public static string ApiKey { get; set; } = string.Empty;
        public static int TimeoutSegundos { get; set; } = 10;
    }
}
