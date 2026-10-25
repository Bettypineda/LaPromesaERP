using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace LaPromesa.DTO.DTO
{
    /// <summary>NIT guatemalteco con dígito verificador (módulo 11). Misma regla que compras.fn_NitValido.</summary>
    [AttributeUsage(AttributeTargets.Property)]
    public class NitGuatemalaAttribute : ValidationAttribute
    {
        public NitGuatemalaAttribute() : base("El NIT no es válido (verifique el dígito verificador, ej. 1234567-9).") { }

        public override bool IsValid(object? value)
        {
            if (value is not string texto || string.IsNullOrWhiteSpace(texto)) return true;
            var n = texto.Trim().Replace("-", "").Replace(" ", "").ToUpperInvariant();
            if (n.Length < 2 || n.Length > 13) return false;
            var cuerpo = n[..^1];
            var dv = n[^1];
            if (!cuerpo.All(char.IsAsciiDigit)) return false;
            var suma = 0;
            for (var i = 0; i < cuerpo.Length; i++)
                suma += (cuerpo[i] - '0') * (cuerpo.Length - i + 1);
            var r = (11 - suma % 11) % 11;
            return r == 10 ? dv == 'K' : dv == (char)('0' + r);
        }
    }

    /// <summary>Teléfono de Guatemala: 8 dígitos iniciando en 2-7 (acepta guion, espacios o +502).</summary>
    [AttributeUsage(AttributeTargets.Property)]
    public class TelefonoGuatemalaAttribute : ValidationAttribute
    {
        public TelefonoGuatemalaAttribute() : base("El teléfono debe tener 8 dígitos y comenzar con 2 a 7 (ej. 2360-1111).") { }

        public override bool IsValid(object? value)
        {
            if (value is not string texto || string.IsNullOrWhiteSpace(texto)) return true;
            var t = Regex.Replace(texto, @"[\s\-\(\)]", "");
            if (t.StartsWith("+502")) t = t[4..];
            return Regex.IsMatch(t, "^[2-7][0-9]{7}$");
        }
    }
}
