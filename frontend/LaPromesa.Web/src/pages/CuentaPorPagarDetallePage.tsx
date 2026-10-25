import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react'
import { Link, useLocation, useParams } from 'react-router-dom'
import { useAuth, useAvisos } from '../context/hooks'
import { buscarCuentaPorPagar, pagarCuentaPorPagar, reintentarPago } from '../services/cuentaPorPagarService'
import type { CuentaPorPagarDetalle, MetodoPago, PagoConsulta } from '../interfaces/CuentaPorPagar'
import { formatoFecha, formatoFechaHora, formatoMoneda, nuevoGuid } from '../utils/formato'
import { leerError } from '../utils/errores'
import type { Errores } from '../utils/validaciones'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EstadoBadge from '../components/EstadoBadge'
import Campo from '../components/Campo'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'
import { AxiosError } from 'axios'
import './Formularios.css'

const METODOS: { valor: MetodoPago; texto: string; detalle: string; icono: string }[] = [
  { valor: 'Transferencia', texto: 'Transferencia', detalle: 'Se envía al banco y espera su autorización', icono: 'bi-bank' },
  { valor: 'Cheque', texto: 'Cheque', detalle: 'Requiere número de cheque', icono: 'bi-journal-text' },
  { valor: 'Efectivo', texto: 'Efectivo', detalle: 'Se aplica de inmediato', icono: 'bi-cash-coin' },
]

function CuentaPorPagarDetallePage() {
  const { id } = useParams()
  const ubicacion = useLocation()
  const { puede } = useAuth()
  const { avisar } = useAvisos()
  const [detalle, setDetalle] = useState<CuentaPorPagarDetalle | null>(null)
  const [error, setError] = useState('')
  const [pago, setPago] = useState({ metodo: 'Transferencia' as MetodoPago, monto: '', banco: '', cuentaDestino: '', referencia: '' })
  // Un mismo operacionId por intento: si la red falla y se reenvía, el backend no duplica el pago
  const [operacionId, setOperacionId] = useState(nuevoGuid)
  const [errores, setErrores] = useState<Errores>({})
  const [mensajePago, setMensajePago] = useState('')
  const [ultimoPago, setUltimoPago] = useState<PagoConsulta | null>(null)
  const [enviando, setEnviando] = useState(false)
  const refPago = useRef<HTMLElement>(null)

  const cargar = useCallback(async () => {
    setError('')
    try {
      const r = await buscarCuentaPorPagar(Number(id))
      if (r.exito) {
        setDetalle(r.datos)
        const c = r.datos.cuenta
        setPago((p) => ({
          ...p,
          monto: c.saldoDisponible > 0 ? String(c.saldoDisponible) : '',
          banco: p.banco || c.banco || '',
          cuentaDestino: p.cuentaDestino || c.numeroCuenta || '',
        }))
      } else setError(r.mensaje)
    } catch (e) {
      setError(leerError(e).mensaje)
    }
  }, [id])

  useEffect(() => { cargar() }, [cargar])

  useEffect(() => {
    if (detalle && ubicacion.hash === '#pagar') refPago.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }, [detalle, ubicacion.hash])

  if (error) return <MensajeError texto={error} onReintentar={cargar} />
  if (!detalle) return <Cargando texto="Cargando cuenta…" />
  const c = detalle.cuenta
  const pagable = puede('registrarPagos') && c.saldoDisponible > 0

  const validar = (): Errores => {
    const e: Errores = {}
    const monto = Number(pago.monto)
    if (!(monto > 0)) e.monto = 'Escriba un monto mayor que cero.'
    else if (monto > c.saldoDisponible) e.monto = `No puede superar el saldo disponible (${formatoMoneda(c.saldoDisponible)}).`
    else if (Math.round(monto * 100) !== monto * 100) e.monto = 'Use máximo dos decimales.'
    if (pago.metodo === 'Transferencia') {
      if (!pago.banco.trim()) e.banco = 'Indique el banco de destino.'
      if (!pago.cuentaDestino.trim()) e.cuentaDestino = 'Indique la cuenta de destino.'
    }
    if (pago.metodo === 'Cheque' && !pago.referencia.trim()) e.referencia = 'Escriba el número de cheque.'
    return e
  }

  const pagar = async (evento: FormEvent) => {
    evento.preventDefault()
    setMensajePago('')
    setUltimoPago(null)
    const encontrados = validar()
    setErrores(encontrados)
    if (Object.keys(encontrados).length) return
    setEnviando(true)
    try {
      const r = await pagarCuentaPorPagar({
        idCuentaPagar: c.idCuentaPagar, operacionId, monto: Number(pago.monto), metodo: pago.metodo,
        banco: pago.metodo === 'Transferencia' ? pago.banco.trim() : '',
        cuentaDestino: pago.metodo === 'Transferencia' ? pago.cuentaDestino.trim() : '',
        referencia: pago.referencia.trim(),
      })
      setUltimoPago(r.datos)
      setOperacionId(nuevoGuid())
      if (r.datos?.estado === 'Aprobado') avisar(`Pago ${r.datos.numero} aplicado por ${formatoMoneda(r.datos.monto)}.`)
      else if (r.datos?.estado === 'Rechazado') avisar(`El banco rechazó el pago ${r.datos.numero}.`, 'error')
      else avisar(r.mensaje, 'info')
      setPago((p) => ({ ...p, referencia: '' }))
      cargar()
    } catch (e) {
      const { mensaje, campos } = leerError(e)
      setErrores(campos)
      // Sin respuesta del servidor: se conserva el operacionId para reintentar sin duplicar
      if (e instanceof AxiosError && !e.response) {
        setMensajePago(`${mensaje} Puede volver a intentar: el pago no se duplicará.`)
      } else {
        setMensajePago(mensaje)
        setOperacionId(nuevoGuid())
      }
    } finally {
      setEnviando(false)
    }
  }

  const reintentar = async (p: PagoConsulta) => {
    try {
      const r = await reintentarPago(p.idPago)
      avisar(r.mensaje || `Pago ${p.numero}: ${r.datos.estado}.`, r.datos.estado === 'Rechazado' ? 'error' : 'exito')
      cargar()
    } catch (e) {
      avisar(leerError(e).mensaje, 'error')
    }
  }

  const pagado = c.monto - c.saldo

  return (
    <>
      <EncabezadoPagina
        titulo={`Cuenta ${c.numero}`}
        descripcion={<>{c.proveedor} · factura {c.facturaProveedor} &nbsp;<EstadoBadge estado={c.estado} /></>}
        volver={{ ruta: '/cuentas-por-pagar', texto: 'Cuentas por pagar' }}
      />

      <div className="cifras">
        <div className="cifra"><span className="cifra-valor">{formatoMoneda(c.monto)}</span><span className="cifra-etiqueta">Monto de la factura</span></div>
        <div className="cifra"><span className="cifra-valor">{formatoMoneda(pagado)}</span><span className="cifra-etiqueta">Pagado</span></div>
        <div className="cifra"><span className="cifra-valor">{formatoMoneda(c.saldo)}</span><span className="cifra-etiqueta">Saldo</span></div>
        <div className="cifra">
          <span className={`cifra-valor ${c.diasVencida > 0 && c.saldo > 0 ? 'texto-error' : ''}`}>{formatoFecha(c.fechaVencimiento)}</span>
          <span className="cifra-etiqueta">{c.saldo > 0 && c.diasVencida > 0 ? `Vencida hace ${c.diasVencida} días` : 'Vencimiento'}</span>
        </div>
      </div>

      {c.montoEnProceso > 0 && (
        <div className="alerta alerta-alerta"><i className="bi bi-hourglass-split" />
          <span>{formatoMoneda(c.montoEnProceso)} en transferencias esperando confirmación del banco. Saldo disponible para pagar: {formatoMoneda(c.saldoDisponible)}.</span>
        </div>
      )}

      <div className="rejilla-2">
        <div>
          {pagable && (
            <section className="panel" id="pagar" ref={refPago}>
              <div className="panel-cabecera"><h2>Registrar pago</h2></div>
              <form className="panel-cuerpo" onSubmit={pagar} noValidate>
                {mensajePago && <MensajeError texto={mensajePago} />}
                {ultimoPago && (
                  <div className={`alerta ${ultimoPago.estado === 'Aprobado' ? 'alerta-ok' : ultimoPago.estado === 'Rechazado' ? 'alerta-error' : 'alerta-alerta'}`}>
                    <i className={`bi ${ultimoPago.estado === 'Aprobado' ? 'bi-check-circle' : ultimoPago.estado === 'Rechazado' ? 'bi-x-octagon' : 'bi-hourglass-split'}`} />
                    <span>
                      Pago {ultimoPago.numero}: <strong>{ultimoPago.estado}</strong>
                      {ultimoPago.referenciaBanco && <> · autorización {ultimoPago.referenciaBanco}</>}
                      {ultimoPago.mensajeBanco && <> · {ultimoPago.mensajeBanco}</>}
                    </span>
                  </div>
                )}

                <div className="opciones-pago mb-3" role="radiogroup" aria-label="Método de pago">
                  {METODOS.map((m) => (
                    <label key={m.valor} className={`opcion ${pago.metodo === m.valor ? 'seleccionada' : ''}`}>
                      <input type="radio" name="metodo" checked={pago.metodo === m.valor} onChange={() => setPago({ ...pago, metodo: m.valor })} />
                      <span><strong><i className={`bi ${m.icono}`} /> {m.texto}</strong><small>{m.detalle}</small></span>
                    </label>
                  ))}
                </div>

                <div className="rejilla-campos">
                  <Campo id="monto" etiqueta="Monto (Q)" requerido error={errores.monto} ayuda={`Disponible: ${formatoMoneda(c.saldoDisponible)}`}>
                    <input id="monto" type="number" min="0.01" max={c.saldoDisponible} step="0.01" inputMode="decimal"
                      className={`form-control ${errores.monto ? 'is-invalid' : ''}`} value={pago.monto}
                      onChange={(e) => setPago({ ...pago, monto: e.target.value })} />
                  </Campo>
                  {pago.metodo === 'Transferencia' && (
                    <>
                      <Campo id="banco" etiqueta="Banco destino" requerido error={errores.banco}>
                        <input id="banco" className={`form-control ${errores.banco ? 'is-invalid' : ''}`} maxLength={60}
                          value={pago.banco} onChange={(e) => setPago({ ...pago, banco: e.target.value })} />
                      </Campo>
                      <Campo id="cuentaDestino" etiqueta="Cuenta destino" requerido error={errores.cuentaDestino}>
                        <input id="cuentaDestino" className={`form-control ${errores.cuentaDestino ? 'is-invalid' : ''}`} maxLength={30}
                          value={pago.cuentaDestino} onChange={(e) => setPago({ ...pago, cuentaDestino: e.target.value })} />
                      </Campo>
                    </>
                  )}
                  <Campo id="referencia" etiqueta={pago.metodo === 'Cheque' ? 'Número de cheque' : 'Referencia interna'}
                    requerido={pago.metodo === 'Cheque'} error={errores.referencia}>
                    <input id="referencia" className={`form-control ${errores.referencia ? 'is-invalid' : ''}`} maxLength={50}
                      value={pago.referencia} onChange={(e) => setPago({ ...pago, referencia: e.target.value })} />
                  </Campo>
                </div>

                <div className="d-flex justify-content-between align-items-center gap-3 flex-wrap">
                  <small className="texto-suave">Operación {operacionId.substring(0, 8)}…</small>
                  <button type="submit" className="btn btn-acento" disabled={enviando}>
                    {enviando
                      ? <><span className="spinner-border spinner-border-sm" /> {pago.metodo === 'Transferencia' ? 'Esperando al banco…' : 'Registrando…'}</>
                      : `Pagar ${Number(pago.monto) > 0 ? formatoMoneda(Number(pago.monto)) : ''}`}
                  </button>
                </div>
              </form>
            </section>
          )}

          <section className="panel">
            <div className="panel-cabecera"><h2>Pagos realizados</h2></div>
            {detalle.pagos.length === 0 ? <SinRegistros icono="bi-wallet2" titulo="Aún no hay pagos para esta cuenta" /> : (
              <div className="tabla-envoltura">
                <table className="tabla">
                  <thead><tr><th>Pago</th><th>Método</th><th>Solicitado</th><th className="numero">Monto</th><th>Estado</th><th>Banco</th><th /></tr></thead>
                  <tbody>
                    {detalle.pagos.map((p) => (
                      <tr key={p.idPago}>
                        <td className="nowrap"><strong>{p.numero}</strong><span className="celda-sub">{p.registradoPor}</span></td>
                        <td className="nowrap">{p.metodo}{p.cuentaDestino && <span className="celda-sub">{p.cuentaDestino}</span>}</td>
                        <td className="nowrap">{formatoFechaHora(p.fechaSolicitud)}</td>
                        <td className="numero">{formatoMoneda(p.monto)}</td>
                        <td><EstadoBadge estado={p.estado} /></td>
                        <td className="small nowrap">{p.referenciaBanco ?? p.mensajeBanco ?? '—'}{p.intentos > 1 && <span className="celda-sub">{p.intentos} intentos</span>}</td>
                        <td className="acciones">
                          {p.estado === 'Pendiente' && puede('registrarPagos') && (
                            <button type="button" className="btn btn-claro btn-sm" onClick={() => reintentar(p)}>Consultar al banco</button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>

        <section className="panel">
          <div className="panel-cabecera"><h2>Origen de la deuda</h2></div>
          <div className="panel-cuerpo">
            <dl className="datos datos-columna">
              <div><dt>Proveedor</dt><dd><Link to={`/proveedores/${c.idProveedor}`}>{c.proveedor}</Link><span className="celda-sub">NIT {c.nitProveedor}</span></dd></div>
              <div><dt>Orden de compra</dt><dd><Link to={`/ordenes-compra/${c.idOrdenCompra}`}>{c.numeroOrden}</Link></dd></div>
              <div><dt>Recepción</dt><dd><Link to={`/recepciones/${c.idRecepcion}`}>{c.numeroRecepcion}</Link></dd></div>
              <div><dt>Factura</dt><dd>{c.facturaProveedor}</dd></div>
              <div><dt>Emitida</dt><dd>{formatoFecha(c.fechaEmision)}</dd></div>
              <div><dt>Antigüedad</dt><dd>{c.rangoAntiguedad}</dd></div>
              <div><dt>Cuenta del proveedor</dt><dd>{c.banco ? `${c.banco}, ${c.numeroCuenta}` : 'No registrada'}</dd></div>
            </dl>
          </div>
        </section>
      </div>
    </>
  )
}

export default CuentaPorPagarDetallePage
