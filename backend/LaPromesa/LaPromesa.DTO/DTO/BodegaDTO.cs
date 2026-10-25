namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta: Bodega (TEMPORAL: inv.Bodegas, módulo de Inventarios).</summary>
    public class BodegaDTO
    {
        public int IdBodega { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string? Ubicacion { get; set; }
    }
}
