import { useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth, useAvisos } from '../context/hooks'
import { aprobarOrdenCompra, buscarOrdenCompra, eliminarOrdenCompra } from '../services/ordenCompraService'
import type { OrdenCompraDetalle } from '../interfaces/OrdenCompra'
import { formatoFecha, formatoFechaHora, formatoMoneda, formatoNumero } from '../utils/formato'
import { leerError } from '../utils/errores'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EstadoBadge from '../components/EstadoBadge'
import RecorridoOrden from '../components/RecorridoOrden'
import Modal from '../components/Modal'
import ModalMotivo from '../components/ModalMotivo'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'

function OrdenCompraDetallePage() {
  const { id } = useParams()
  const { puede } = useAuth()
  const { avisar } = useAvisos()
  const [detalle, setDetalle] = useState<OrdenCompraDetalle | null>(null)
  const [error, setError] = useState('')
  const [modalAprobar, setModalAprobar] = useState(false)
  const [modalAnular, setModalAnular] = useState(false)
  const [procesando, setProcesando] = useState(false)

  const cargar = useCallback(async () => {
    setError('')
    try {
      const r = await buscarOrdenCompra(Number(id))
      if (r.exito) setDetalle(r.datos)
      else setError(r.mensaje)
    } catch (e) {
      setError(leerError(e).mensaje)
    }
  }, [id])

  useEffect(() => { cargar() }, [cargar])

  if (error) return <MensajeError texto={error} onReintentar={cargar} />
  if (!detalle) return <Cargando texto="Cargando orden…" />

  const o = detalle.orden

  const aprobar = async () => {
    setProcesando(true)
    try {
      const r = await aprobarOrdenCompra(o.idOrdenCompra, o.rowVersion)
      avisar(r.mensaje || `Orden ${o.numero} aprobada.`)
      setModalAprobar(false)
      cargar()
    } catch (e) {
      avisar(leerError(e).mensaje, 'error')
    } finally {
      setProcesando(false)
    }
  }

  const anular = async (motivo: string) => {
    setProcesando(true)
    try {
      const r = await eliminarOrdenCompra(o.idOrdenCompra, motivo, o.rowVersion)
      avisar(r.mensaje || `Orden ${o.numero} anulada.`)
      setModalAnular(false)
      cargar()
    } catch (e) {
      avisar(leerError(e).mensaje, 'error')
    } finally {
      setProcesando(false)
    }
  }

  const puedeAnular = puede('autorizarCompras') && (o.estado === 'Pendiente' || o.estado === 'Aprobada') && detalle.recepciones.length === 0

  return (
    <>
      <EncabezadoPagina
        titulo={`Orden ${o.numero}`}
        descripcion={<>{o.proveedor} · para {o.bodega} &nbsp;<EstadoBadge estado={o.estado} /></>}
        volver={{ ruta: '/ordenes-compra', texto: 'Órdenes de compra' }}
        acciones={<>
          {puede('recibirMercaderia') && (o.estado === 'Aprobada' || o.estado === 'Parcial') && (
            <Link to={`/ordenes-compra/${o.idOrdenCompra}/recibir`} className="btn btn-acento"><i className="bi bi-box-seam" /> Recibir mercadería</Link>
          )}
          {puede('autorizarCompras') && o.estado === 'Pendiente' && (
            <button type="button" className="btn btn-exito" onClick={() => setModalAprobar(true)}><i className="bi bi-patch-check" /> Aprobar</button>
          )}
          {puede('crearCompras') && o.estado === 'Pendiente' && (
            <Link to={`/ordenes-compra/${o.idOrdenCompra}/editar`} className="btn btn-claro"><i className="bi bi-pencil" /> Editar</Link>
          )}
          {puedeAnular && (
            <button type="button" className="btn btn-claro" onClick={() => setModalAnular(true)}><i className="bi bi-x-circle" /> Anular</button>
          )}
          <button type="button" className="btn btn-claro" onClick={() => window.print()}><i className="bi bi-printer" /> Imprimir</button>
        </>}
      />

      <RecorridoOrden orden={o} historial={detalle.historial} />

      {o.estado === 'Anulada' && (
        <div className="alerta alerta-error"><i className="bi bi-x-circle" /><span>Motivo de anulación: {o.motivoAnulacion}</span></div>
      )}
      {o.estaAtrasada && (
        <div className="alerta alerta-alerta"><i className="bi bi-clock-history" /><span>La entrega esperada era el {formatoFecha(o.fechaEsperada)} y aún hay producto pendiente de recibir.</span></div>
      )}

      <div className="rejilla-2">
        <div>
          <section className="panel">
            <div className="panel-cabecera">
              <h2>Productos</h2>
              <span className="texto-suave small">{formatoNumero(o.porcentajeRecibido)} % recibido</span>
            </div>
            <div className="tabla-envoltura">
              <table className="tabla">
                <thead>
                  <tr>
                    <th>Producto</th>
                    <th className="numero">Pedido</th>
                    <th className="numero">Recibido</th>
                    <th className="numero">Pendiente</th>
                    <th className="numero">Costo</th>
                    <th className="numero">Subtotal</th>
                  </tr>
                </thead>
                <tbody>
                  {detalle.lineas.map((l) => (
                    <tr key={l.idDetalle}>
                      <td>
                        <strong>{l.producto}</strong>
                        <span className="celda-sub">{l.codigoProducto} · {l.unidadMedida}</span>
                      </td>
                      <td className="numero">{formatoNumero(l.cantidadPedida)}</td>
                      <td className="numero">{formatoNumero(l.cantidadRecibida)}</td>
                      <td className={`numero ${l.cantidadPendiente > 0 && o.estado !== 'Anulada' ? 'texto-alerta' : ''}`}>{formatoNumero(l.cantidadPendiente)}</td>
                      <td className="numero">{formatoMoneda(l.costoUnitario)}</td>
                      <td className="numero">{formatoMoneda(l.subtotal)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <dl className="totales">
              <dt>Subtotal</dt><dd>{formatoMoneda(o.subtotal)}</dd>
              <dt>IVA {formatoNumero(o.tasaIva * 100)} %</dt><dd>{formatoMoneda(o.iva)}</dd>
              <dt>Total</dt><dd className="total-final">{formatoMoneda(o.total)}</dd>
            </dl>
          </section>

          <section className="panel">
            <div className="panel-cabecera"><h2>Recepciones</h2></div>
            {detalle.recepciones.length === 0 ? (
              <SinRegistros icono="bi-box-seam" titulo="Todavía no se ha recibido mercadería">
                {o.estado === 'Pendiente' && 'La orden debe aprobarse antes de recibir.'}
              </SinRegistros>
            ) : (
              <div className="tabla-envoltura">
                <table className="tabla">
                  <thead><tr><th>Recepción</th><th>Fecha</th><th>Factura</th><th>Cumplimiento</th><th className="numero">Total</th><th>Cuenta por pagar</th></tr></thead>
                  <tbody>
                    {detalle.recepciones.map((r) => (
                      <tr key={r.idRecepcion}>
                        <td className="nowrap"><Link to={`/recepciones/${r.idRecepcion}`} className="celda-principal">{r.numero}</Link></td>
                        <td className="nowrap">{formatoFecha(r.fechaRecepcion)}</td>
                        <td className="nowrap">{r.factura}</td>
                        <td><EstadoBadge estado={r.cumplimiento} /></td>
                        <td className="numero">{formatoMoneda(r.total)}</td>
                        <td className="nowrap">
                          {r.idCuentaPagar
                            ? puede('verFinanzas') ? <Link to={`/cuentas-por-pagar/${r.idCuentaPagar}`}>{r.numeroCuentaPagar}</Link> : r.numeroCuentaPagar
                            : '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>

        <div>
          <section className="panel">
            <div className="panel-cabecera"><h2>Datos de la orden</h2></div>
            <div className="panel-cuerpo">
              <dl className="datos datos-columna">
                <div><dt>Proveedor</dt><dd><Link to={`/proveedores/${o.idProveedor}`}>{o.proveedor}</Link><span className="celda-sub">NIT {o.nitProveedor}</span></dd></div>
                <div><dt>Condición de pago</dt><dd>{o.tipoPago === 'Credito' ? `Crédito a ${o.diasCredito} días` : 'Contado'}</dd></div>
                <div><dt>Fecha de la orden</dt><dd>{formatoFecha(o.fechaOrden)}</dd></div>
                <div><dt>Entrega esperada</dt><dd>{formatoFecha(o.fechaEsperada)}</dd></div>
                <div><dt>Bodega</dt><dd>{o.bodega}</dd></div>
                {o.observaciones && <div><dt>Observaciones</dt><dd className="fw-normal">{o.observaciones}</dd></div>}
                <div><dt>Creada por</dt><dd>{o.creadoPor}, {formatoFechaHora(o.fechaCreacion)}</dd></div>
                {o.aprobadoPor && <div><dt>Aprobada por</dt><dd>{o.aprobadoPor}, {formatoFechaHora(o.fechaAprobacion)}</dd></div>}
              </dl>
            </div>
          </section>

          <section className="panel">
            <div className="panel-cabecera"><h2>Historial de cambios</h2></div>
            <div className="panel-cuerpo">
              {detalle.historial.length === 0 ? <p className="texto-suave m-0">Sin movimientos.</p> : (
                <ul className="historial">
                  {detalle.historial.map((h, i) => (
                    <li key={i}>
                      <strong>{h.estadoAnterior ? `${h.estadoAnterior} → ${h.estadoNuevo}` : h.estadoNuevo}</strong>
                      <small>{formatoFechaHora(h.fecha)} · {h.usuario}</small>
                      {h.comentario && <p>{h.comentario}</p>}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </section>
        </div>
      </div>

      <Modal abierto={modalAprobar} titulo={`Aprobar la orden ${o.numero}`} onCerrar={() => setModalAprobar(false)}
        pie={<>
          <button type="button" className="btn btn-claro" onClick={() => setModalAprobar(false)} disabled={procesando}>Cancelar</button>
          <button type="button" className="btn btn-exito" onClick={aprobar} disabled={procesando}>{procesando ? 'Aprobando…' : 'Aprobar orden'}</button>
        </>}>
        <p>Al aprobarla, bodega podrá recibir la mercadería y ya no se podrá editar.</p>
        <dl className="datos">
          <div><dt>Proveedor</dt><dd>{o.proveedor}</dd></div>
          <div><dt>Total</dt><dd>{formatoMoneda(o.total)}</dd></div>
          <div><dt>Entrega</dt><dd>{formatoFecha(o.fechaEsperada)}</dd></div>
        </dl>
      </Modal>

      <ModalMotivo abierto={modalAnular} titulo={`Anular la orden ${o.numero}`}
        descripcion="La orden no se borra: queda anulada con su motivo y su historial. Solo se permite si aún no tiene recepciones."
        textoBoton="Anular orden" procesando={procesando} onConfirmar={anular} onCerrar={() => setModalAnular(false)} />
    </>
  )
}

export default OrdenCompraDetallePage
