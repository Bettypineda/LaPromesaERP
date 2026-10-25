import { useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth, useAvisos } from '../context/hooks'
import { buscarProveedor, eliminarProveedor, reactivarProveedor } from '../services/proveedorService'
import type { ProveedorDetalle } from '../interfaces/Proveedor'
import { formatoFecha, formatoFechaHora, formatoMoneda, formatoPorcentaje } from '../utils/formato'
import { leerError } from '../utils/errores'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EstadoBadge from '../components/EstadoBadge'
import ModalMotivo from '../components/ModalMotivo'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'
import BarraCumplimiento from '../components/BarraCumplimiento'

function ProveedorDetallePage() {
  const { id } = useParams()
  const { puede } = useAuth()
  const { avisar } = useAvisos()
  const [detalle, setDetalle] = useState<ProveedorDetalle | null>(null)
  const [error, setError] = useState('')
  const [modalInactivar, setModalInactivar] = useState(false)
  const [procesando, setProcesando] = useState(false)

  const cargar = useCallback(async () => {
    setError('')
    try {
      const r = await buscarProveedor(Number(id))
      if (r.exito) setDetalle(r.datos)
      else setError(r.mensaje)
    } catch (e) {
      setError(leerError(e).mensaje)
    }
  }, [id])

  useEffect(() => { cargar() }, [cargar])

  if (error) return <MensajeError texto={error} onReintentar={cargar} />
  if (!detalle) return <Cargando texto="Cargando proveedor…" />

  const p = detalle.proveedor
  const c = detalle.cumplimiento

  const inactivar = async (motivo: string) => {
    setProcesando(true)
    try {
      const r = await eliminarProveedor(p.idProveedor, motivo, p.rowVersion)
      avisar(r.mensaje || 'Proveedor inactivado.')
      setModalInactivar(false)
      cargar()
    } catch (e) {
      avisar(leerError(e).mensaje, 'error')
    } finally {
      setProcesando(false)
    }
  }

  const reactivar = async () => {
    try {
      const r = await reactivarProveedor(p.idProveedor, p.rowVersion)
      avisar(r.mensaje || 'Proveedor reactivado.')
      cargar()
    } catch (e) {
      avisar(leerError(e).mensaje, 'error')
    }
  }

  return (
    <>
      <EncabezadoPagina
        titulo={p.nombre}
        descripcion={<>{p.codigo} · NIT {p.nit} · {p.categoria} &nbsp;<EstadoBadge estado={p.estado} /></>}
        volver={{ ruta: '/proveedores', texto: 'Proveedores' }}
        acciones={<>
          {puede('crearCompras') && p.estado === 'Activo' && (
            <Link to={`/ordenes-compra/nueva?proveedor=${p.idProveedor}`} className="btn btn-acento"><i className="bi bi-receipt" /> Nueva orden</Link>
          )}
          {puede('gestionarProveedores') && p.estado === 'Activo' && (
            <Link to={`/proveedores/${p.idProveedor}/editar`} className="btn btn-claro"><i className="bi bi-pencil" /> Editar</Link>
          )}
          {puede('autorizarCompras') && (p.estado === 'Activo'
            ? <button type="button" className="btn btn-claro" onClick={() => setModalInactivar(true)}><i className="bi bi-slash-circle" /> Inactivar</button>
            : <button type="button" className="btn btn-exito" onClick={reactivar}><i className="bi bi-arrow-counterclockwise" /> Reactivar</button>)}
        </>}
      />

      {p.estado === 'Inactivo' && (
        <div className="alerta alerta-alerta">
          <i className="bi bi-slash-circle" />
          <span>Inactivado por <strong>{p.inactivadoPor}</strong> el {formatoFechaHora(p.fechaInactivacion)}. Motivo: {p.motivoInactivacion}</span>
        </div>
      )}

      <div className="cifras">
        <div className="cifra"><span className="cifra-valor">{formatoMoneda(p.saldoPendiente)}</span><span className="cifra-etiqueta">Saldo por pagar</span></div>
        <div className="cifra">
          <span className="cifra-valor">{p.tipoPago === 'Credito' && p.limiteCredito > 0 ? formatoMoneda(p.creditoDisponible) : '—'}</span>
          <span className="cifra-etiqueta">Crédito disponible</span>
        </div>
        <div className="cifra"><span className="cifra-valor">{p.ordenesAbiertas}</span><span className="cifra-etiqueta">Órdenes abiertas</span></div>
        <div className="cifra"><span className="cifra-valor">{formatoPorcentaje(c?.porcentajeCumplimiento)}</span><span className="cifra-etiqueta">Entregas a tiempo</span></div>
      </div>

      <div className="rejilla-2">
        <div>
          <section className="panel">
            <div className="panel-cabecera">
              <h2>Últimas órdenes de compra</h2>
              <Link to={`/ordenes-compra?proveedor=${p.idProveedor}`} className="btn-texto">Ver todas</Link>
            </div>
            {detalle.ultimasOrdenes.length === 0 ? <SinRegistros titulo="Este proveedor aún no tiene órdenes" /> : (
              <div className="tabla-envoltura">
                <table className="tabla">
                  <thead><tr><th>Orden</th><th>Fecha</th><th>Entrega</th><th className="numero">Total</th><th>Estado</th></tr></thead>
                  <tbody>
                    {detalle.ultimasOrdenes.map((o) => (
                      <tr key={o.idOrdenCompra}>
                        <td><Link to={`/ordenes-compra/${o.idOrdenCompra}`} className="celda-principal">{o.numero}</Link></td>
                        <td className="nowrap">{formatoFecha(o.fechaOrden)}</td>
                        <td className="nowrap">{formatoFecha(o.fechaEsperada)}</td>
                        <td className="numero">{formatoMoneda(o.total)}</td>
                        <td><EstadoBadge estado={o.estado} /></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          {puede('verFinanzas') && (
            <section className="panel">
              <div className="panel-cabecera"><h2>Cuentas por pagar</h2></div>
              {detalle.cuentasPorPagar.length === 0 ? <SinRegistros icono="bi-check2-circle" titulo="Sin cuentas pendientes" /> : (
                <div className="tabla-envoltura">
                  <table className="tabla">
                    <thead><tr><th>Cuenta</th><th>Factura</th><th>Vence</th><th className="numero">Saldo</th><th>Estado</th></tr></thead>
                    <tbody>
                      {detalle.cuentasPorPagar.map((cp) => (
                        <tr key={cp.idCuentaPagar}>
                          <td><Link to={`/cuentas-por-pagar/${cp.idCuentaPagar}`} className="celda-principal">{cp.numero}</Link></td>
                          <td>{cp.facturaProveedor}</td>
                          <td className="nowrap">
                            {formatoFecha(cp.fechaVencimiento)}
                            {cp.diasVencida > 0 && cp.saldo > 0 && <span className="celda-sub texto-error">{cp.diasVencida} días vencida</span>}
                          </td>
                          <td className="numero">{formatoMoneda(cp.saldo)}</td>
                          <td><EstadoBadge estado={cp.estado} /></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          )}
        </div>

        <div>
          <section className="panel">
            <div className="panel-cabecera"><h2>Datos del proveedor</h2></div>
            <div className="panel-cuerpo">
              <dl className="datos datos-columna">
                <div><dt>Contacto</dt><dd>{p.contacto ?? '—'}</dd></div>
                <div><dt>Teléfono</dt><dd>{p.telefono ?? '—'}</dd></div>
                <div><dt>Correo</dt><dd>{p.email ? <a href={`mailto:${p.email}`}>{p.email}</a> : '—'}</dd></div>
                <div><dt>Dirección</dt><dd>{[p.direccion, p.departamento].filter(Boolean).join(', ') || '—'}</dd></div>
                <div><dt>Condición de pago</dt><dd>{p.tipoPago === 'Credito' ? `Crédito a ${p.diasCredito} días` : 'Contado'}</dd></div>
                {p.tipoPago === 'Credito' && <div><dt>Límite de crédito</dt><dd>{p.limiteCredito > 0 ? formatoMoneda(p.limiteCredito) : 'Sin límite'}</dd></div>}
                <div><dt>Cuenta bancaria</dt><dd>{p.banco ? `${p.banco}, ${p.numeroCuenta}` : 'No registrada'}</dd></div>
                <div><dt>Última compra</dt><dd>{formatoFecha(p.ultimaCompra)}</dd></div>
              </dl>
            </div>
          </section>

          <section className="panel">
            <div className="panel-cabecera"><h2>Cumplimiento de entregas</h2></div>
            <div className="panel-cuerpo">
              {c && c.totalRecepciones > 0
                ? <BarraCumplimiento aTiempo={c.aTiempo} anticipada={c.anticipada} retraso={c.retraso} />
                : <p className="texto-suave m-0">Aún no hay recepciones para calcularlo.</p>}
            </div>
          </section>

          <section className="panel">
            <div className="panel-cabecera"><h2>Trazabilidad</h2></div>
            <div className="panel-cuerpo">
              <dl className="datos datos-columna">
                <div><dt>Registrado</dt><dd>{formatoFechaHora(p.fechaCreacion)} por {p.creadoPor}</dd></div>
                <div><dt>Última modificación</dt><dd>{p.fechaModificacion ? `${formatoFechaHora(p.fechaModificacion)} por ${p.modificadoPor}` : 'Sin cambios'}</dd></div>
              </dl>
            </div>
          </section>
        </div>
      </div>

      <ModalMotivo abierto={modalInactivar} titulo={`Inactivar a ${p.nombre}`}
        descripcion="El proveedor no se borra: queda inactivo y puede reactivarse después. No se permite si tiene órdenes abiertas o saldo pendiente."
        textoBoton="Inactivar proveedor" procesando={procesando} onConfirmar={inactivar} onCerrar={() => setModalInactivar(false)} />
    </>
  )
}

export default ProveedorDetallePage
