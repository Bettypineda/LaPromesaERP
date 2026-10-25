namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta: Producto (TEMPORAL: inv.Productos, módulo de Inventarios).</summary>
    public class ProductoDTO
    {
        public int IdProducto { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string UnidadMedida { get; set; } = string.Empty;
        public decimal CostoPromedio { get; set; }
        public decimal StockMinimo { get; set; }
        public decimal Existencia { get; set; }
    }
}
