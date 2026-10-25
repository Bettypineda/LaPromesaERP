namespace LaPromesa.Entidades.Entidades
{
    /// <summary>Categorías de proveedor (compras.CategoriasProveedor).</summary>
    public class Categoria
    {
        public int IdCategoria { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public bool Activo { get; set; }
        public DateTime FechaCreacion { get; set; }
        public string CreadoPor { get; set; } = string.Empty;
    }
}
