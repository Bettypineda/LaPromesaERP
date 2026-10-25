namespace LaPromesa.Entidades.Entidades
{
    /// <summary>Refresh token guardado como hash (seg.RefreshTokens).</summary>
    public class RefreshToken
    {
        public long IdToken { get; set; }
        public int IdUsuario { get; set; }
        public DateTime Expira { get; set; }
        public DateTime? RevocadoEn { get; set; }
    }
}
