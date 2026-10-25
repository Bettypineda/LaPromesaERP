namespace LaPromesa.Utilidades.Configuracion
{
    /// <summary>
    /// Cadena de conexión a SQL Server (Docker, puerto 1435).
    /// Se asigna en Program.cs desde la configuración "ConexionSQL"
    /// (guardada en user-secrets, nunca en el repositorio).
    /// </summary>
    public class ConexionSQL
    {
        public static string CadenaConexion { get; set; } = string.Empty;
    }
}
