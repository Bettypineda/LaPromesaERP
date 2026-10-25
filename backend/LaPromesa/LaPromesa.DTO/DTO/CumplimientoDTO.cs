namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta: Cumplimiento histórico de entregas de un proveedor (vista compras.vw_CumplimientoProveedores).</summary>
    public class CumplimientoDTO
    {
        public int TotalRecepciones { get; set; }
        public int ATiempo { get; set; }
        public int Retraso { get; set; }
        public int Anticipada { get; set; }
        public decimal? PorcentajeCumplimiento { get; set; }
    }
}
