namespace LaPromesa.Utilidades.Excepciones
{
    /// <summary>
    /// Error controlado de negocio. Los procedimientos almacenados lanzan errores
    /// 51xxx (validación → 400), 52xxx (no existe → 404), 53xxx (regla → 409) y
    /// 54xxx (concurrencia → 409); la capa Datos los convierte en esta excepción.
    /// </summary>
    public class ExcepcionNegocio : Exception
    {
        public int EstadoHttp { get; }
        public int? Codigo { get; }

        public ExcepcionNegocio(string mensaje, int estadoHttp = 400, int? codigo = null)
            : base(mensaje)
        {
            EstadoHttp = estadoHttp;
            Codigo = codigo;
        }

        /// <summary>Estado HTTP correspondiente a un código de error de la base de datos.</summary>
        public static int EstadoDesdeCodigo(int codigo) => codigo switch
        {
            < 52000 => 400,
            < 53000 => 404,
            _ => 409
        };
    }
}
