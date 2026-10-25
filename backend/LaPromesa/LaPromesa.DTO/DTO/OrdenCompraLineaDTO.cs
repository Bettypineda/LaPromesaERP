namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta: Línea de una orden de compra (vista compras.vw_OrdenesCompraDetalle).</summary>
    public class OrdenCompraLineaDTO
    {
        public int IdDetalle { get; set; }
        public int IdOrdenCompra { get; set; }
        public string? NumeroOrden { get; set; }
        public int IdProducto { get; set; }
        public string? CodigoProducto { get; set; }
        public string? Producto { get; set; }
        public string? UnidadMedida { get; set; }
        public decimal CantidadPedida { get; set; }
        public decimal CantidadRecibida { get; set; }
        public decimal CantidadPendiente { get; set; }
        public decimal CostoUnitario { get; set; }
        public decimal Subtotal { get; set; }
    }
}
