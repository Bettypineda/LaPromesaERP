namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta estándar de todas las APIs (formato del curso).</summary>
    public class RespuestaApi<T>
    {
        public bool Exito { get; set; }
        public string Mensaje { get; set; } = string.Empty;
        public T? Datos { get; set; }
        public string? Detalle { get; set; }
    }
}
