namespace LaPromesa.Entidades.Entidades
{
    /// <summary>Bodega (TEMPORAL: inv.Bodegas, módulo de Inventarios).</summary>
    public class Bodega
    {
        public int IdBodega { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string? Ubicacion { get; set; }
    }
}
