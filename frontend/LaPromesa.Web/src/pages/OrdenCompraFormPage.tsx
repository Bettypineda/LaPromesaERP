import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useAvisos } from '../context/hooks'
import { agregarOrdenCompra, buscarOrdenCompra, editarOrdenCompra } from '../services/ordenCompraService'
import { consultarBodegas, consultarProductos } from '../services/catalogoService'
import { listarProveedores } from '../services/listasService'
import type { OrdenCompraAgregar } from '../interfaces/OrdenCompra'
import type { Bodega, Producto } from '../interfaces/Catalogos'
import type { ProveedorConsulta } from '../interfaces/Proveedor'
import { formatoMoneda, formatoNumero, hoyIso } from '../utils/formato'
import { leerError } from '../utils/errores'
import type { Errores } from '../utils/validaciones'
import EncabezadoPagina from '../components/EncabezadoPagina'
import Campo from '../components/Campo'
import { Cargando, MensajeError } from '../components/Estados'
import './Formularios.css'

const TASA_IVA = 0.12

interface LineaForm {
  clave: number
  idProducto: number
  cantidadPedida: string
  costoUnitario: string
}

let siguienteClave = 1
const lineaVacia = (): LineaForm => ({ clave: siguienteClave++, idProducto: 0, cantidadPedida: '', costoUnitario: '' })
const redondear = (n: number) => Math.round(n * 100) / 100

function OrdenCompraFormPage() {
  const { id } = useParams()
  const edicion = !!id
  const [parametros] = useSearchParams()
  const navegar = useNavigate()
  const { avisar } = useAvisos()

  const [proveedores, setProveedores] = useState<ProveedorConsulta[]>([])
  const [bodegas, setBodegas] = useState<Bodega[]>([])
  const [productos, setProductos] = useState<Producto[]>([])
  const [encabezado, setEncabezado] = useState({
    idProveedor: Number(parametros.get('proveedor')) || 0, idBodega: 0, fechaEsperada: hoyIso(7), observaciones: '',
  })
  const [lineas, setLineas] = useState<LineaForm[]>([lineaVacia()])
  const [rowVersion, setRowVersion] = useState<string | null>(null)
  const [numero, setNumero] = useState('')
  const [errores, setErrores] = useState<Errores>({})
  const [intento, setIntento] = useState(false)
  const [mensaje, setMensaje] = useState('')
  const [cargando, setCargando] = useState(true)
  const [guardando, setGuardando] = useState(false)

  useEffect(() => {
    const catalogos = Promise.all([
      listarProveedores(true).then(setProveedores),
      consultarBodegas().then((r) => r.exito && setBodegas(r.datos)),
      consultarProductos().then((r) => r.exito && setProductos(r.datos)),
    ])
    const orden = edicion
      ? buscarOrdenCompra(Number(id)).then((r) => {
        if (!r.exito) { setMensaje(r.mensaje); return }
        const o = r.datos.orden
        if (o.estado !== 'Pendiente') setMensaje(`La orden ${o.numero} está ${o.estado}: solo se pueden editar órdenes pendientes.`)
        setNumero(o.numero)
        setRowVersion(o.rowVersion)
        setEncabezado({ idProveedor: o.idProveedor, idBodega: o.idBodega, fechaEsperada: o.fechaEsperada, observaciones: o.observaciones ?? '' })
        setLineas(r.datos.lineas.map((l) => ({
          clave: siguienteClave++, idProducto: l.idProducto, cantidadPedida: String(l.cantidadPedida), costoUnitario: String(l.costoUnitario),
        })))
      })
      : Promise.resolve()
    Promise.all([catalogos, orden])
      .catch((e) => setMensaje(leerError(e).mensaje))
      .finally(() => setCargando(false))
  }, [edicion, id])

  const proveedor = proveedores.find((p) => p.idProveedor === encabezado.idProveedor)

  const subtotal = useMemo(() => redondear(lineas.reduce((s, l) =>
    s + (Number(l.cantidadPedida) || 0) * (Number(l.costoUnitario) || 0), 0)), [lineas])
  const iva = redondear(subtotal * TASA_IVA)
  const total = redondear(subtotal + iva)

  const validar = (): Errores => {
    const e: Errores = {}
    if (!encabezado.idProveedor) e.idProveedor = 'Seleccione un proveedor.'
    if (!encabezado.idBodega) e.idBodega = 'Seleccione la bodega que recibirá la mercadería.'
    if (!encabezado.fechaEsperada) e.fechaEsperada = 'Indique la fecha esperada de entrega.'
    else if (encabezado.fechaEsperada < hoyIso()) e.fechaEsperada = 'La fecha de entrega no puede ser anterior a hoy.'
    const usados = new Set<number>()
    lineas.forEach((l, i) => {
      if (!l.idProducto) e[`linea-${i}-producto`] = 'Seleccione un producto.'
      else if (usados.has(l.idProducto)) e[`linea-${i}-producto`] = 'Este producto ya está en la orden.'
      usados.add(l.idProducto)
      if (!(Number(l.cantidadPedida) > 0)) e[`linea-${i}-cantidad`] = 'Mayor que cero.'
      if (!(Number(l.costoUnitario) > 0)) e[`linea-${i}-costo`] = 'Mayor que cero.'
    })
    if (lineas.length === 0) e.lineas = 'La orden debe tener al menos un producto.'
    return e
  }

  useEffect(() => { if (intento) setErrores(validar()) }, [encabezado, lineas]) // eslint-disable-line react-hooks/exhaustive-deps

  const cambiarLinea = (clave: number, cambios: Partial<LineaForm>) =>
    setLineas((ls) => ls.map((l) => (l.clave === clave ? { ...l, ...cambios } : l)))

  const elegirProducto = (clave: number, idProducto: number) => {
    const p = productos.find((x) => x.idProducto === idProducto)
    const actual = lineas.find((l) => l.clave === clave)
    cambiarLinea(clave, {
      idProducto,
      costoUnitario: actual?.costoUnitario || (p && p.costoPromedio > 0 ? String(p.costoPromedio) : ''),
    })
  }

  const guardar = async (evento: FormEvent) => {
    evento.preventDefault()
    setIntento(true)
    setMensaje('')
    const encontrados = validar()
    setErrores(encontrados)
    if (Object.keys(encontrados).length) return

    const datos: OrdenCompraAgregar = {
      ...encabezado,
      observaciones: encabezado.observaciones.trim(),
      lineas: lineas.map((l) => ({ idProducto: l.idProducto, cantidadPedida: Number(l.cantidadPedida), costoUnitario: Number(l.costoUnitario) })),
    }
    setGuardando(true)
    try {
      const r = edicion
        ? await editarOrdenCompra({ ...datos, idOrdenCompra: Number(id), rowVersion })
        : await agregarOrdenCompra(datos)
      if (r.exito) {
        avisar(edicion ? `Orden ${r.datos.numero} actualizada.` : `Orden ${r.datos.numero} creada. Queda pendiente de aprobación.`)
        navegar(`/ordenes-compra/${r.datos.idOrdenCompra}`)
      } else setMensaje(r.mensaje)
    } catch (e) {
      const { mensaje: texto, campos } = leerError(e)
      setMensaje(texto)
      setErrores(campos)
    } finally {
      setGuardando(false)
    }
  }

  if (cargando) return <Cargando texto="Cargando catálogos…" />

  const excedeCredito = proveedor?.tipoPago === 'Credito' && proveedor.limiteCredito > 0
    && proveedor.creditoDisponible !== null && total > proveedor.creditoDisponible

  return (
    <>
      <EncabezadoPagina
        titulo={edicion ? `Editar orden ${numero}` : 'Nueva orden de compra'}
        descripcion="La orden se guarda como pendiente. El subtotal, IVA (12 %) y total definitivos los calcula la base de datos."
        volver={{ ruta: edicion ? `/ordenes-compra/${id}` : '/ordenes-compra', texto: edicion ? 'Detalle de la orden' : 'Órdenes de compra' }}
      />

      {mensaje && <MensajeError texto={mensaje} />}

      <form className="formulario" onSubmit={guardar} noValidate>
        <section className="panel">
          <div className="panel-cabecera"><h2>Proveedor y entrega</h2></div>
          <div className="panel-cuerpo rejilla-campos">
            <Campo id="idProveedor" etiqueta="Proveedor" requerido error={errores.idProveedor} className="campo-doble"
              ayuda={proveedor && `${proveedor.tipoPago === 'Credito' ? `Crédito a ${proveedor.diasCredito} días` : 'Pago de contado'}${proveedor.tipoPago === 'Credito' && proveedor.limiteCredito > 0 ? `, disponible ${formatoMoneda(proveedor.creditoDisponible)}` : ''}`}>
              <select id="idProveedor" className={`form-select ${errores.idProveedor ? 'is-invalid' : ''}`} value={encabezado.idProveedor || ''}
                onChange={(e) => setEncabezado({ ...encabezado, idProveedor: Number(e.target.value) })}>
                <option value="">Seleccione…</option>
                {proveedores.map((p) => <option key={p.idProveedor} value={p.idProveedor}>{p.nombre} ({p.nit})</option>)}
              </select>
            </Campo>
            <Campo id="idBodega" etiqueta="Bodega de destino" requerido error={errores.idBodega}>
              <select id="idBodega" className={`form-select ${errores.idBodega ? 'is-invalid' : ''}`} value={encabezado.idBodega || ''}
                onChange={(e) => setEncabezado({ ...encabezado, idBodega: Number(e.target.value) })}>
                <option value="">Seleccione…</option>
                {bodegas.map((b) => <option key={b.idBodega} value={b.idBodega}>{b.nombre}</option>)}
              </select>
            </Campo>
            <Campo id="fechaEsperada" etiqueta="Entrega esperada" requerido error={errores.fechaEsperada}>
              <input id="fechaEsperada" type="date" min={hoyIso()} className={`form-control ${errores.fechaEsperada ? 'is-invalid' : ''}`}
                value={encabezado.fechaEsperada} onChange={(e) => setEncabezado({ ...encabezado, fechaEsperada: e.target.value })} />
            </Campo>
            <Campo id="observaciones" etiqueta="Observaciones" className="campo-doble" ayuda={`${encabezado.observaciones.length}/300`}>
              <textarea id="observaciones" className="form-control" rows={2} maxLength={300}
                value={encabezado.observaciones} onChange={(e) => setEncabezado({ ...encabezado, observaciones: e.target.value })} />
            </Campo>
          </div>
        </section>

        <section className="panel">
          <div className="panel-cabecera">
            <h2>Productos</h2>
            <button type="button" className="btn btn-claro btn-sm" onClick={() => setLineas([...lineas, lineaVacia()])} disabled={lineas.length >= 100}>
              <i className="bi bi-plus-lg" /> Agregar producto
            </button>
          </div>
          {errores.lineas && <div className="panel-cuerpo pb-0"><div className="alerta alerta-error"><span>{errores.lineas}</span></div></div>}
          <div className="tabla-envoltura">
            <table className="tabla lineas">
              <thead>
                <tr>
                  <th className="col-producto">Producto</th>
                  <th className="col-cantidad">Cantidad</th>
                  <th className="col-costo">Costo unitario (Q)</th>
                  <th className="numero">Subtotal</th>
                  <th><span className="visually-hidden">Quitar</span></th>
                </tr>
              </thead>
              <tbody>
                {lineas.map((l, i) => {
                  const p = productos.find((x) => x.idProducto === l.idProducto)
                  const usados = new Set(lineas.filter((o) => o.clave !== l.clave).map((o) => o.idProducto))
                  return (
                    <tr key={l.clave}>
                      <td>
                        <select aria-label={`Producto de la línea ${i + 1}`} className={`form-select ${errores[`linea-${i}-producto`] ? 'is-invalid' : ''}`}
                          value={l.idProducto || ''} onChange={(e) => elegirProducto(l.clave, Number(e.target.value))}>
                          <option value="">Seleccione…</option>
                          {productos.map((x) => (
                            <option key={x.idProducto} value={x.idProducto} disabled={usados.has(x.idProducto)}>{x.codigo} · {x.nombre}</option>
                          ))}
                        </select>
                        {errores[`linea-${i}-producto`]
                          ? <div className="invalid-feedback d-block">{errores[`linea-${i}-producto`]}</div>
                          : p && <span className="celda-sub">{p.unidadMedida} · existencia {formatoNumero(p.existencia)}</span>}
                      </td>
                      <td>
                        <input type="number" min="0.01" step="0.01" inputMode="decimal" aria-label={`Cantidad de la línea ${i + 1}`}
                          className={`form-control ${errores[`linea-${i}-cantidad`] ? 'is-invalid' : ''}`}
                          value={l.cantidadPedida} onChange={(e) => cambiarLinea(l.clave, { cantidadPedida: e.target.value })} />
                        {errores[`linea-${i}-cantidad`] && <div className="invalid-feedback">{errores[`linea-${i}-cantidad`]}</div>}
                      </td>
                      <td>
                        <input type="number" min="0.0001" step="0.01" inputMode="decimal" aria-label={`Costo de la línea ${i + 1}`}
                          className={`form-control ${errores[`linea-${i}-costo`] ? 'is-invalid' : ''}`}
                          value={l.costoUnitario} onChange={(e) => cambiarLinea(l.clave, { costoUnitario: e.target.value })} />
                        {errores[`linea-${i}-costo`] && <div className="invalid-feedback">{errores[`linea-${i}-costo`]}</div>}
                      </td>
                      <td className="numero pt-3">{formatoMoneda((Number(l.cantidadPedida) || 0) * (Number(l.costoUnitario) || 0))}</td>
                      <td className="acciones">
                        <button type="button" className="btn-icono peligro" aria-label={`Quitar línea ${i + 1}`} title="Quitar"
                          disabled={lineas.length === 1} onClick={() => setLineas(lineas.filter((x) => x.clave !== l.clave))}>
                          <i className="bi bi-trash3" />
                        </button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          <dl className="totales">
            <dt>Subtotal</dt><dd>{formatoMoneda(subtotal)}</dd>
            <dt>IVA 12 %</dt><dd>{formatoMoneda(iva)}</dd>
            <dt>Total estimado</dt><dd className="total-final">{formatoMoneda(total)}</dd>
          </dl>
        </section>

        {excedeCredito && (
          <div className="alerta alerta-alerta">
            <i className="bi bi-exclamation-triangle" />
            <span>El total supera el crédito disponible del proveedor ({formatoMoneda(proveedor?.creditoDisponible)}). La aprobación podría ser rechazada.</span>
          </div>
        )}

        <div className="formulario-acciones">
          <Link to={edicion ? `/ordenes-compra/${id}` : '/ordenes-compra'} className="btn btn-claro">Cancelar</Link>
          <button type="submit" className="btn btn-primary" disabled={guardando}>
            {guardando ? <><span className="spinner-border spinner-border-sm" /> Guardando…</> : edicion ? 'Guardar cambios' : 'Crear orden'}
          </button>
        </div>
      </form>
    </>
  )
}

export default OrdenCompraFormPage
