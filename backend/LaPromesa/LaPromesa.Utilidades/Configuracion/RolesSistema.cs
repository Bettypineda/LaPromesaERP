namespace LaPromesa.Utilidades.Configuracion
{
    /// <summary>Roles del sistema (coinciden con la tabla seg.Roles) y combinaciones por operación.</summary>
    public static class RolesSistema
    {
        public const string Administrador = "Administrador";
        public const string Compras = "Compras";
        public const string Gerente = "Gerente";
        public const string Bodega = "Bodega";
        public const string Tesoreria = "Tesoreria";
        public const string Consulta = "Consulta";

        public const string GestionarProveedores = Administrador + "," + Compras;
        public const string AutorizarCompras = Administrador + "," + Gerente;
        public const string CrearCompras = Administrador + "," + Compras;
        public const string RecibirMercaderia = Administrador + "," + Bodega;
        public const string RegistrarPagos = Administrador + "," + Tesoreria;
        public const string VerFinanzas = Administrador + "," + Tesoreria + "," + Gerente + "," + Consulta;
        public const string VerReportes = Administrador + "," + Gerente + "," + Compras + "," + Tesoreria + "," + Consulta;
    }
}
