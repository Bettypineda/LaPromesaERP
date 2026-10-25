using System.Globalization;
using System.Text;
using LaPromesa.DTO.DTO;

namespace LaPromesa.API.Configuracion
{
    /// <summary>Convierte un reporte a CSV (separador ;) con BOM UTF-8 para abrirlo bien en Excel.</summary>
    public static class ExportadorCsv
    {
        public static byte[] Generar(ReporteDTO reporte)
        {
            var sb = new StringBuilder();
            Tabla(sb, "RESUMEN", reporte.Resumen);
            Tabla(sb, "DETALLE", reporte.Detalle);
            return Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(sb.ToString())).ToArray();
        }

        private static void Tabla(StringBuilder sb, string titulo, List<Dictionary<string, object?>> filas)
        {
            sb.AppendLine(titulo);
            if (filas.Count == 0) { sb.AppendLine("Sin datos"); sb.AppendLine(); return; }
            sb.AppendLine(string.Join(';', filas[0].Keys.Select(Escapar)));
            foreach (var f in filas)
                sb.AppendLine(string.Join(';', f.Values.Select(v => Escapar(Formatear(v)))));
            sb.AppendLine();
        }

        private static string Formatear(object? v) => v switch
        {
            null => "",
            DateOnly d => d.ToString("yyyy-MM-dd"),
            DateTime d => d.ToString("yyyy-MM-dd HH:mm"),
            decimal m => m.ToString("0.00", CultureInfo.InvariantCulture),
            _ => Convert.ToString(v, CultureInfo.InvariantCulture) ?? ""
        };

        private static string Escapar(string s)
            => s.IndexOfAny(new[] { ';', '"', '\n', '\r' }) >= 0 ? "\"" + s.Replace("\"", "\"\"") + "\"" : s;
    }
}
