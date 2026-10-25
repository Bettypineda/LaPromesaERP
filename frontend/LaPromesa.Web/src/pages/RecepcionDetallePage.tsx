import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth } from '../context/hooks'
import { buscarRecepcion } from '../services/recepcionService'
import type { RecepcionDetalle } from '../interfaces/Recepcion'
import { formatoFecha, formatoFechaHora, formatoMoneda, formatoNumero } from '../utils/formato'
import { leerError } from '../utils/errores'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EstadoBadge from '../components/EstadoBadge'
import { Cargando, MensajeError } from '../components/Estados'

function RecepcionDetallePage() {
  const { id } = useParams()
  const { puede } = useAuth()
  const [detalle, setDetalle] = useState<RecepcionDetalle | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    buscarRecepcion(Number(id))
      .then((r) => (r.exito ? setDetalle(r.datos) : setError(r.mensaje)))
      .catch((e) => setError(leerError(e).mensaje))
  }, [id])

  if (error) return <MensajeError texto={error} />
  if (!detalle) return <Cargando texto="Cargando nota de compra…" />
  const r = detalle.recepcion

  return (
    <>
      <EncabezadoPagina
        titulo={`Nota de compra ${r.numero}`}
        descripcion={<>{r.proveedor} · factura {r.factura} &nbsp;<EstadoBadge estado={r.cumplimiento} /></>}
        volver={{ ruta: '/recepciones', texto: 'Recepciones' }}
        acciones={<button type="button" className="btn btn-claro" onClick={() => window.print()}><i className="bi bi-printer" /> Imprimir</button>}
      />

      <div className="rejilla-2">
        <section className="panel">
          <div className="panel-cabecera"><h2>Productos recibidos</h2></div>
          <div className="tabla-envoltura">
            <table className="tabla">
              <thead><tr><th>Producto</th><th className="numero">Cantidad</th><th className="numero">Costo</th><th className="numero">Subtotal</th></tr></thead>
              <tbody>
                {detalle.lineas.map((l) => (
                  <tr key={l.idRecepcionDetalle}>
                    <td><strong>{l.producto}</strong><span className="celda-sub">{l.codigoProducto} · {l.unidadMedida}</span></td>
                    <td className="numero">{formatoNumero(l.cantidad)}</td>
                    <td className="numero">{formatoMoneda(l.costoUnitario)}</td>
                    <td className="numero">{formatoMoneda(l.subtotal)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <dl className="totales">
            <dt>Subtotal</dt><dd>{formatoMoneda(r.subtotal)}</dd>
            <dt>IVA</dt><dd>{formatoMoneda(r.iva)}</dd>
            <dt>Total</dt><dd className="total-final">{formatoMoneda(r.total)}</dd>
          </dl>
        </section>

        <section className="panel">
          <div className="panel-cabecera"><h2>Datos de la recepción</h2></div>
          <div className="panel-cuerpo">
            <dl className="datos datos-columna">
              <div><dt>Orden de compra</dt><dd><Link to={`/ordenes-compra/${r.idOrdenCompra}`}>{r.numeroOrden}</Link></dd></div>
              <div><dt>Proveedor</dt><dd><Link to={`/proveedores/${r.idProveedor}`}>{r.proveedor}</Link><span className="celda-sub">NIT {r.nitProveedor}</span></dd></div>
              <div><dt>Bodega</dt><dd>{r.bodega}</dd></div>
              <div><dt>Fecha de recepción</dt><dd>{formatoFecha(r.fechaRecepcion)}</dd></div>
              <div><dt>Entrega esperada</dt><dd>{formatoFecha(r.fechaEsperada)}{r.diasDiferencia !== 0 && ` (${Math.abs(r.diasDiferencia)} día(s) ${r.diasDiferencia > 0 ? 'tarde' : 'antes'})`}</dd></div>
              <div><dt>Cuenta por pagar</dt><dd>{r.idCuentaPagar
                ? puede('verFinanzas') ? <Link to={`/cuentas-por-pagar/${r.idCuentaPagar}`}>{r.numeroCuentaPagar}</Link> : r.numeroCuentaPagar
                : '—'}</dd></div>
              {r.observaciones && <div><dt>Observaciones</dt><dd className="fw-normal">{r.observaciones}</dd></div>}
              <div><dt>Recibió</dt><dd>{r.recibidoPor}, {formatoFechaHora(r.fechaCreacion)}</dd></div>
            </dl>
          </div>
        </section>
      </div>
    </>
  )
}

export default RecepcionDetallePage
