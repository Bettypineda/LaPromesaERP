namespace LaPromesa.DTO.DTO
{
    /// <summary>Resultado de un listado con paginación.</summary>
    public class ResultadoPaginadoDTO<T>
    {
        public List<T> Registros { get; set; } = new();
        public int Total { get; set; }
        public int Pagina { get; set; }
        public int TamanoPagina { get; set; }
        public int TotalPaginas => TamanoPagina <= 0 ? 0 : (int)Math.Ceiling(Total / (double)TamanoPagina);
    }
}
