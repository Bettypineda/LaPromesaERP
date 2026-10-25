namespace LaPromesa.Entidades.Entidades
{
    /// <summary>Cambio de estado de una orden (compras.OrdenesCompraHistorial).</summary>
    public class HistorialOrden
    {
        public string? EstadoAnterior { get; set; }
        public string EstadoNuevo { get; set; } = string.Empty;
        public DateTime Fecha { get; set; }
        public string Usuario { get; set; } = string.Empty;
        public string? Comentario { get; set; }
    }
}
