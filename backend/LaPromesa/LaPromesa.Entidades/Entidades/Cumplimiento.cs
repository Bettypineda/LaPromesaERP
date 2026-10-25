namespace LaPromesa.Entidades.Entidades
{
    /// <summary>Cumplimiento histórico de entregas de un proveedor (vista compras.vw_CumplimientoProveedores).</summary>
    public class Cumplimiento
    {
        public int TotalRecepciones { get; set; }
        public int ATiempo { get; set; }
        public int Retraso { get; set; }
        public int Anticipada { get; set; }
        public decimal? PorcentajeCumplimiento { get; set; }
    }
}
