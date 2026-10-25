import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAvisos } from '../context/hooks'
import { consultarPagosPendientes, reintentarPago } from '../services/cuentaPorPagarService'
import type { PagoConsulta } from '../interfaces/CuentaPorPagar'
import { formatoFechaHora, formatoMoneda } from '../utils/formato'
import { leerError } from '../utils/errores'
import EncabezadoPagina from '../components/EncabezadoPagina'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'

function PagosPendientesPage() {
  const { avisar } = useAvisos()
  const [pagos, setPagos] = useState<PagoConsulta[] | null>(null)
  const [error, setError] = useState('')
  const [enCurso, setEnCurso] = useState<number | null>(null)

  const cargar = useCallback(async () => {
    setError('')
    try {
      const r = await consultarPagosPendientes()
      if (r.exito) setPagos(r.datos)
      else setError(r.mensaje)
    } catch (e) {
      setError(leerError(e).mensaje)
    }
  }, [])

  useEffect(() => { cargar() }, [cargar])

  const reintentar = async (p: PagoConsulta) => {
    setEnCurso(p.idPago)
    try {
      const r = await reintentarPago(p.idPago)
      avisar(r.mensaje || `Pago ${p.numero}: ${r.datos.estado}.`, r.datos.estado === 'Rechazado' ? 'error' : 'exito')
      cargar()
    } catch (e) {
      avisar(leerError(e).mensaje, 'error')
    } finally {
      setEnCurso(null)
    }
  }

  return (
    <>
      <EncabezadoPagina
        titulo="Pagos en revisión"
        descripcion="Transferencias que el banco no confirmó (sin respuesta o tiempo agotado). Consulte de nuevo para aplicarlas o liberar el saldo."
        acciones={<button type="button" className="btn btn-claro" onClick={cargar}><i className="bi bi-arrow-clockwise" /> Actualizar</button>}
      />
      {error && <MensajeError texto={error} onReintentar={cargar} />}
      <section className="panel">
        {!pagos ? <Cargando /> : pagos.length === 0 ? (
          <SinRegistros icono="bi-check2-circle" titulo="Todas las transferencias están confirmadas" />
        ) : (
          <div className="tabla-envoltura">
            <table className="tabla">
              <thead><tr><th>Pago</th><th>Proveedor</th><th>Cuenta</th><th>Destino</th><th>Solicitado</th><th className="numero">Monto</th><th>Último mensaje</th><th /></tr></thead>
              <tbody>
                {pagos.map((p) => (
                  <tr key={p.idPago}>
                    <td><strong>{p.numero}</strong><span className="celda-sub">{p.intentos} intento(s)</span></td>
                    <td>{p.proveedor}</td>
                    <td><Link to={`/cuentas-por-pagar/${p.idCuentaPagar}`}>{p.numeroCuentaPagar}</Link></td>
                    <td>{p.banco}<span className="celda-sub">{p.cuentaDestino}</span></td>
                    <td className="nowrap">{formatoFechaHora(p.fechaSolicitud)}</td>
                    <td className="numero">{formatoMoneda(p.monto)}</td>
                    <td className="small texto-suave">{p.mensajeBanco ?? '—'}</td>
                    <td className="acciones">
                      <button type="button" className="btn btn-claro btn-sm" disabled={enCurso === p.idPago} onClick={() => reintentar(p)}>
                        {enCurso === p.idPago ? 'Consultando…' : 'Consultar al banco'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  )
}

export default PagosPendientesPage
