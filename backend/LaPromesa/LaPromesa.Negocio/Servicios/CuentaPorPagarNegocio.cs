using LaPromesa.Datos.Datos;
using LaPromesa.DTO.DTO;
using LaPromesa.Entidades.Entidades;
using LaPromesa.Utilidades.Excepciones;

namespace LaPromesa.Negocio.Servicios
{
    /// <summary>
    /// Cuentas por pagar y pagos con la API bancaria:
    ///   1) reserva el pago en la BD (Pendiente, idempotente por OperacionId)
    ///   2) llama al banco con el mismo OperacionId
    ///   3) confirma (Aprobado/Rechazado) o registra el intento fallido para reintentar.
    /// </summary>
    public class CuentaPorPagarNegocio
    {
        private readonly CuentaPorPagarDatos cuentaDatos;
        private readonly BancoServicio banco;

        public CuentaPorPagarNegocio()
        {
            cuentaDatos = new CuentaPorPagarDatos();
            banco = new BancoServicio();
        }

        public (List<CuentaPorPagar> lista, int total) ConsultarCuentasPorPagar(CuentaPorPagarFiltroDTO f)
            => cuentaDatos.ConsultarCuentasPorPagar(f.IdProveedor, f.Estado, f.SoloVencidas, f.SoloConSaldo,
                f.VenceDesde, f.VenceHasta, f.Pagina, f.TamanoPagina);

        public (CuentaPorPagar cuenta, List<Pago> pagos) BuscarCuentaPorPagar(int idCuentaPagar)
        {
            var r = cuentaDatos.BuscarCuentaPorPagar(idCuentaPagar);
            if (r.cuenta is null) throw new ExcepcionNegocio("La cuenta por pagar no existe.", 404, 52004);
            return (r.cuenta, r.pagos);
        }

        public List<Pago> ConsultarPagosPendientes() => cuentaDatos.ConsultarPagosPendientes();

        public Pago PagarCuentaPorPagar(PagoAgregarDTO p, string usuario)
        {
            var pago = cuentaDatos.IniciarPago(p.IdCuentaPagar, p.OperacionId!.Value, p.Monto, p.Metodo,
                p.Banco, p.CuentaDestino, p.Referencia, usuario);

            // Cheque/efectivo ya quedan aprobados; una repetición idempotente puede devolver un pago ya resuelto.
            return pago.Estado == "Pendiente" ? ProcesarConBanco(pago, usuario) : pago;
        }

        public Pago ReintentarPago(int idPago, string usuario)
        {
            var pago = cuentaDatos.ConsultarPagosPendientes().FirstOrDefault(x => x.IdPago == idPago)
                       ?? throw new ExcepcionNegocio("El pago no existe o ya no está pendiente.", 409, 53015);
            return ProcesarConBanco(pago, usuario);
        }

        private Pago ProcesarConBanco(Pago pago, string usuario)
        {
            var r = banco.Transferir(pago.OperacionId, pago.Banco ?? "", pago.CuentaDestino ?? "", pago.Monto,
                $"Pago {pago.Numero} - {pago.NumeroCuentaPagar}");

            return r.Resultado switch
            {
                ResultadoBanco.Aprobado => cuentaDatos.ConfirmarPago(pago.IdPago, true, r.Autorizacion, r.Mensaje, usuario),
                ResultadoBanco.Rechazado => cuentaDatos.ConfirmarPago(pago.IdPago, false, null, r.Mensaje, usuario),
                _ => cuentaDatos.RegistrarIntentoPago(pago.IdPago, r.Mensaje, usuario)
            };
        }
    }
}
