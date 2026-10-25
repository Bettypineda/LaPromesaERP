import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth, useAvisos } from '../context/hooks'
import { buscarOrdenCompra, recibirOrdenCompra } from '../services/ordenCompraService'
import type { OrdenCompraDetalle } from '../interfaces/OrdenCompra'
import type { RecepcionConsulta } from '../interfaces/Recepcion'
import { formatoFecha, formatoMoneda, formatoNumero, hoyIso } from '../utils/formato'
import { leerError } from '../utils/errores'
import type { Errores } from '../utils/validaciones'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EstadoBadge from '../components/EstadoBadge'
import Campo from '../components/Campo'
import { Cargando, MensajeError } from '../components/Estados'
import './Formularios.css'
import './RecibirOrdenPage.css'

interface LineaRecibir {
  idDetalle: number
  incluir: boolean
  cantidad: string
}

// Diferencia en días contra la fecha esperada (la base de datos aplica la tolerancia configurada)
const diferenciaDias = (fechaRecepcion: string, fechaEsperada: string) =>
  Math.round((Date.parse(fechaRecepcion) - Date.parse(fechaEsperada)) / 86400000)

function RecibirOrdenPage() {
  const { id } = useParams()
  const { puede } = useAuth()
  const { avisar } = useAvisos()
  const [detalle, setDetalle] = useState<OrdenCompraDetalle | null>(null)
  const [lineas, setLineas] = useState<LineaRecibir[]>([])
  const [factura, setFactura] = useState({ serieFactura: '', numeroFactura: '', fechaRecepcion: hoyIso(), observaciones: '' })
  const [errores, setErrores] = useState<Errores>({})
  const [mensaje, setMensaje] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [resultado, setResultado] = useState<RecepcionConsulta | null>(null)

  useEffect(() => {
    buscarOrdenCompra(Number(id))
      .then((r) => {
        if (!r.exito) { setMensaje(r.mensaje); return }
        setDetalle(r.datos)
        setLineas(r.datos.lineas.filter((l) => l.cantidadPendiente > 0)
          .map((l) => ({ idDetalle: l.idDetalle, incluir: true, cantidad: String(l.cantidadPendiente) })))
      })
      .catch((e) => setMensaje(leerError(e).mensaje))
  }, [id])

  const lineaOrden = (idDetalle: number) => detalle?.lineas.find((l) => l.idDetalle === idDetalle)

  const subtotal = useMemo(() => lineas.reduce((s, l) => {
    const lo = detalle?.lineas.find((x) => x.idDetalle === l.idDetalle)
    return l.incluir && lo ? s + (Number(l.cantidad) || 0) * lo.costoUnitario : s
  }, 0), [lineas, detalle])
  const tasa = detalle?.orden.tasaIva ?? 0.12
  const total = Math.round(subtotal * (1 + tasa) * 100) / 100

  if (mensaje && !detalle) return <MensajeError texto={mensaje} />
  if (!detalle) return <Cargando texto="Cargando orden…" />

  const o = detalle.orden
  const recibible = o.estado === 'Aprobada' || o.estado === 'Parcial'

  if (resultado) {
    return (
      <div className="recepcion-lista">
        <i className="bi bi-check2-circle recepcion-lista-icono" aria-hidden="true" />
        <h1>Mercadería recibida</h1>
        <p className="texto-suave">La nota {resultado.numero} quedó registrada y el proceso se completó en la base de datos.</p>
        <ol className="recepcion-resultado">
          <li><strong>Nota de compra {resultado.numero}</strong><span>Factura {resultado.factura} por {formatoMoneda(resultado.total)}</span></li>
          <li><strong>Inventario actualizado</strong><span>Existencias sumadas en {resultado.bodega}</span></li>
          <li>
            <strong>Cuenta por pagar {resultado.numeroCuentaPagar ?? ''}</strong>
            <span>Generada para {resultado.proveedor}</span>
          </li>
          <li><strong>Cumplimiento del proveedor</strong><span><EstadoBadge estado={resultado.cumplimiento} /> {resultado.diasDiferencia !== 0 && `${Math.abs(resultado.diasDiferencia)} día(s)`}</span></li>
        </ol>
        <div className="d-flex gap-2 flex-wrap justify-content-center">
          <Link to={`/ordenes-compra/${o.idOrdenCompra}`} className="btn btn-primary">Ver la orden</Link>
          <Link to={`/recepciones/${resultado.idRecepcion}`} className="btn btn-claro">Ver la nota de compra</Link>
          {resultado.idCuentaPagar && puede('verFinanzas') && (
            <Link to={`/cuentas-por-pagar/${resultado.idCuentaPagar}`} className="btn btn-claro">Ver la cuenta por pagar</Link>
          )}
        </div>
      </div>
    )
  }

  const validar = (): Errores => {
    const e: Errores = {}
    if (!factura.numeroFactura.trim()) e.numeroFactura = 'El número de factura del proveedor es obligatorio.'
    if (!factura.fechaRecepcion) e.fechaRecepcion = 'Indique la fecha de recepción.'
    else if (factura.fechaRecepcion > hoyIso()) e.fechaRecepcion = 'La fecha de recepción no puede ser futura.'
    else if (factura.fechaRecepcion < o.fechaOrden) e.fechaRecepcion = 'No puede ser anterior a la fecha de la orden.'
    const incluidas = lineas.filter((l) => l.incluir)
    if (incluidas.length === 0) e.lineas = 'Marque al menos un producto recibido.'
    incluidas.forEach((l) => {
      const lo = lineaOrden(l.idDetalle)
      const c = Number(l.cantidad)
      if (!(c > 0)) e[`cant-${l.idDetalle}`] = 'Mayor que cero.'
      else if (lo && c > lo.cantidadPendiente) e[`cant-${l.idDetalle}`] = `Máximo ${formatoNumero(lo.cantidadPendiente)}.`
    })
    return e
  }

  const confirmar = async (evento: FormEvent) => {
    evento.preventDefault()
    setMensaje('')
    const encontrados = validar()
    setErrores(encontrados)
    if (Object.keys(encontrados).length) return
    setGuardando(true)
    try {
      const r = await recibirOrdenCompra({
        idOrdenCompra: o.idOrdenCompra,
        fechaRecepcion: factura.fechaRecepcion,
        serieFactura: factura.serieFactura.trim(),
        numeroFactura: factura.numeroFactura.trim(),
        observaciones: factura.observaciones.trim(),
        lineas: lineas.filter((l) => l.incluir).map((l) => ({ idDetalle: l.idDetalle, cantidad: Number(l.cantidad) })),
      })
      if (r.exito) {
        avisar(`Recepción ${r.datos.numero} registrada.`)
        setResultado(r.datos)
      } else setMensaje(r.mensaje)
    } catch (e) {
      const { mensaje: texto, campos } = leerError(e)
      setMensaje(texto)
      setErrores(campos)
    } finally {
      setGuardando(false)
    }
  }

  const diferencia = factura.fechaRecepcion ? diferenciaDias(factura.fechaRecepcion, o.fechaEsperada) : null
  const prevision = diferencia === null ? null
    : diferencia === 0 ? 'Coincide con la entrega esperada.'
      : `${Math.abs(diferencia)} día(s) ${diferencia > 0 ? 'después' : 'antes'} de la entrega esperada.`

  return (
    <>
      <EncabezadoPagina
        titulo={`Recibir mercadería · ${o.numero}`}
        descripcion={<>{o.proveedor} · entrega esperada {formatoFecha(o.fechaEsperada)} en {o.bodega}</>}
        volver={{ ruta: `/ordenes-compra/${o.idOrdenCompra}`, texto: 'Detalle de la orden' }}
      />

      {!recibible && (
        <div className="alerta alerta-alerta"><i className="bi bi-info-circle" />
          <span>La orden está <strong>{o.estado}</strong>. Solo se reciben órdenes aprobadas o con recepción parcial.</span>
        </div>
      )}
      {mensaje && <MensajeError texto={mensaje} />}

      <form className="formulario recepcion" onSubmit={confirmar} noValidate>
        <section className="panel">
          <div className="panel-cabecera"><h2>Factura del proveedor</h2></div>
          <div className="panel-cuerpo rejilla-campos">
            <Campo id="serieFactura" etiqueta="Serie" error={errores.serieFactura}>
              <input id="serieFactura" className="form-control" maxLength={20} value={factura.serieFactura}
                onChange={(e) => setFactura({ ...factura, serieFactura: e.target.value })} />
            </Campo>
            <Campo id="numeroFactura" etiqueta="Número de factura" requerido error={errores.numeroFactura}>
              <input id="numeroFactura" className={`form-control ${errores.numeroFactura ? 'is-invalid' : ''}`} maxLength={30}
                value={factura.numeroFactura} onChange={(e) => setFactura({ ...factura, numeroFactura: e.target.value })} />
            </Campo>
            <Campo id="fechaRecepcion" etiqueta="Fecha de recepción" requerido error={errores.fechaRecepcion}
              ayuda={prevision}>
              <input id="fechaRecepcion" type="date" max={hoyIso()} min={o.fechaOrden}
                className={`form-control ${errores.fechaRecepcion ? 'is-invalid' : ''}`}
                value={factura.fechaRecepcion} onChange={(e) => setFactura({ ...factura, fechaRecepcion: e.target.value })} />
            </Campo>
            <Campo id="obs" etiqueta="Observaciones" className="campo-doble">
              <input id="obs" className="form-control" maxLength={300} placeholder="Ej. 2 cajas con empaque dañado"
                value={factura.observaciones} onChange={(e) => setFactura({ ...factura, observaciones: e.target.value })} />
            </Campo>
          </div>
        </section>

        <section className="panel">
          <div className="panel-cabecera">
            <h2>Productos recibidos</h2>
            <span className="texto-suave small">Ajuste la cantidad si llegó menos de lo pendiente</span>
          </div>
          {errores.lineas && <div className="panel-cuerpo pb-0"><div className="alerta alerta-error"><span>{errores.lineas}</span></div></div>}
          <div className="tabla-envoltura">
            <table className="tabla lineas">
              <thead>
                <tr>
                  <th style={{ width: 40 }}><span className="visually-hidden">Incluir</span></th>
                  <th>Producto</th>
                  <th className="numero">Pedido</th>
                  <th className="numero">Pendiente</th>
                  <th className="col-cantidad">Recibido ahora</th>
                  <th className="numero">Costo</th>
                  <th className="numero">Subtotal</th>
                </tr>
              </thead>
              <tbody>
                {lineas.length === 0 && (
                  <tr><td colSpan={7} className="text-center texto-suave py-4">No hay productos pendientes de recibir.</td></tr>
                )}
                {lineas.map((l) => {
                  const lo = lineaOrden(l.idDetalle)!
                  const err = errores[`cant-${l.idDetalle}`]
                  return (
                    <tr key={l.idDetalle} className={l.incluir ? '' : 'linea-excluida'}>
                      <td>
                        <input type="checkbox" className="form-check-input" checked={l.incluir} aria-label={`Incluir ${lo.producto}`}
                          onChange={(e) => setLineas(lineas.map((x) => x.idDetalle === l.idDetalle ? { ...x, incluir: e.target.checked } : x))} />
                      </td>
                      <td><strong>{lo.producto}</strong><span className="celda-sub">{lo.codigoProducto} · {lo.unidadMedida}</span></td>
                      <td className="numero">{formatoNumero(lo.cantidadPedida)}</td>
                      <td className="numero">{formatoNumero(lo.cantidadPendiente)}</td>
                      <td>
                        <input type="number" min="0.01" max={lo.cantidadPendiente} step="0.01" disabled={!l.incluir}
                          aria-label={`Cantidad recibida de ${lo.producto}`} className={`form-control ${err ? 'is-invalid' : ''}`}
                          value={l.cantidad} onChange={(e) => setLineas(lineas.map((x) => x.idDetalle === l.idDetalle ? { ...x, cantidad: e.target.value } : x))} />
                        {err && <div className="invalid-feedback">{err}</div>}
                      </td>
                      <td className="numero">{formatoMoneda(lo.costoUnitario)}</td>
                      <td className="numero">{l.incluir ? formatoMoneda((Number(l.cantidad) || 0) * lo.costoUnitario) : '—'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          <dl className="totales">
            <dt>Subtotal</dt><dd>{formatoMoneda(subtotal)}</dd>
            <dt>Total con IVA</dt><dd className="total-final">{formatoMoneda(total)}</dd>
          </dl>
        </section>

        <aside className="recepcion-efectos" aria-label="Qué sucede al confirmar">
          <h2>Al confirmar, en una sola transacción:</h2>
          <ol>
            <li>Se registra la nota de compra con la factura del proveedor.</li>
            <li>Las existencias de {o.bodega} aumentan con lo recibido.</li>
            <li>Se genera la cuenta por pagar, con vencimiento {o.tipoPago === 'Credito' ? `a ${o.diasCredito} días` : 'inmediato (contado)'}.</li>
            <li>La orden pasa a parcial o recibida, según lo pendiente.</li>
          </ol>
        </aside>

        <div className="formulario-acciones">
          <Link to={`/ordenes-compra/${o.idOrdenCompra}`} className="btn btn-claro">Cancelar</Link>
          <button type="submit" className="btn btn-acento" disabled={guardando || !recibible || lineas.length === 0}>
            {guardando ? <><span className="spinner-border spinner-border-sm" /> Registrando…</> : 'Confirmar recepción'}
          </button>
        </div>
      </form>
    </>
  )
}

export default RecibirOrdenPage
