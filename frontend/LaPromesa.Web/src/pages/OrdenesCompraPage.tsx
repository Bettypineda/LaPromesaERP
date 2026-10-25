import { useCallback, useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useAuth } from '../context/hooks'
import { consultarOrdenesCompra } from '../services/ordenCompraService'
import { listarProveedores } from '../services/listasService'
import { consultarBodegas } from '../services/catalogoService'
import type { OrdenCompraConsulta, OrdenCompraFiltro } from '../interfaces/OrdenCompra'
import type { ResultadoPaginado } from '../interfaces/RespuestaApi'
import type { ProveedorConsulta } from '../interfaces/Proveedor'
import type { Bodega } from '../interfaces/Catalogos'
import { formatoFecha, formatoMoneda } from '../utils/formato'
import { leerError } from '../utils/errores'
import { useRetraso } from '../utils/useRetraso'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EncabezadoOrdenable from '../components/EncabezadoOrdenable'
import EstadoBadge from '../components/EstadoBadge'
import Paginacion from '../components/Paginacion'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'

const ESTADOS = ['Pendiente', 'Aprobada', 'Parcial', 'Recibida', 'Anulada']

function OrdenesCompraPage() {
  const { puede } = useAuth()
  const [parametros] = useSearchParams()
  const [filtro, setFiltro] = useState<OrdenCompraFiltro>({
    buscar: '',
    estado: parametros.get('estado') ?? '',
    idProveedor: parametros.get('proveedor') ? Number(parametros.get('proveedor')) : undefined,
    idBodega: undefined,
    fechaDesde: '', fechaHasta: '',
    soloAtrasadas: parametros.get('soloAtrasadas') === 'true',
    ordenarPor: 'FechaOrden', direccion: 'DESC', pagina: 1, tamanoPagina: 10,
  })
  const buscar = useRetraso(filtro.buscar)
  const [resultado, setResultado] = useState<ResultadoPaginado<OrdenCompraConsulta> | null>(null)
  const [proveedores, setProveedores] = useState<ProveedorConsulta[]>([])
  const [bodegas, setBodegas] = useState<Bodega[]>([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)

  const { estado, idProveedor, idBodega, fechaDesde, fechaHasta, soloAtrasadas, ordenarPor, direccion, pagina, tamanoPagina } = filtro

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    if (fechaDesde && fechaHasta && fechaDesde > fechaHasta) {
      setError('La fecha inicial no puede ser mayor que la final.')
      setCargando(false)
      return
    }
    try {
      const r = await consultarOrdenesCompra({ buscar, estado, idProveedor, idBodega, fechaDesde, fechaHasta, soloAtrasadas, ordenarPor, direccion, pagina, tamanoPagina })
      if (r.exito) setResultado(r.datos)
      else setError(r.mensaje)
    } catch (e) {
      setError(leerError(e).mensaje)
    } finally {
      setCargando(false)
    }
  }, [buscar, estado, idProveedor, idBodega, fechaDesde, fechaHasta, soloAtrasadas, ordenarPor, direccion, pagina, tamanoPagina])

  useEffect(() => { cargar() }, [cargar])

  useEffect(() => {
    listarProveedores(false).then(setProveedores)
    consultarBodegas().then((r) => r.exito && setBodegas(r.datos)).catch(() => undefined)
  }, [])

  const cambiar = (cambios: Partial<OrdenCompraFiltro>) => setFiltro((f) => ({ ...f, pagina: 1, ...cambios }))
  const ordenar = (campo: string) => setFiltro((f) => ({
    ...f, ordenarPor: campo, direccion: f.ordenarPor === campo && f.direccion === 'DESC' ? 'ASC' : 'DESC', pagina: 1,
  }))
  const limpiar = () => setFiltro((f) => ({
    ...f, buscar: '', estado: '', idProveedor: undefined, idBodega: undefined, fechaDesde: '', fechaHasta: '', soloAtrasadas: false, pagina: 1,
  }))

  const props = { ordenarPor, direccion, onOrdenar: ordenar }

  return (
    <>
      <EncabezadoPagina
        titulo="Órdenes de compra"
        descripcion="Pedidos a proveedores: se crean pendientes, gerencia las aprueba y bodega recibe la mercadería."
        acciones={puede('crearCompras') && (
          <Link to="/ordenes-compra/nueva" className="btn btn-primary"><i className="bi bi-plus-lg" /> Nueva orden</Link>
        )}
      />

      <div className="pestanas-estado" role="tablist" aria-label="Filtrar por estado">
        {['', ...ESTADOS].map((e) => (
          <button key={e || 'todas'} type="button" role="tab" aria-selected={estado === e}
            className={`pestana ${estado === e ? 'activa' : ''}`} onClick={() => cambiar({ estado: e })}>
            {e || 'Todas'}
          </button>
        ))}
      </div>

      <section className="panel">
        <div className="filtros">
          <div className="campo filtro-amplio">
            <label htmlFor="f-buscar" className="form-label">Buscar</label>
            <input id="f-buscar" type="search" className="form-control" placeholder="Número de orden, proveedor o NIT"
              value={filtro.buscar} onChange={(e) => cambiar({ buscar: e.target.value })} />
          </div>
          <div className="campo">
            <label htmlFor="f-prov" className="form-label">Proveedor</label>
            <select id="f-prov" className="form-select" value={idProveedor ?? ''}
              onChange={(e) => cambiar({ idProveedor: e.target.value ? Number(e.target.value) : undefined })}>
              <option value="">Todos</option>
              {proveedores.map((p) => <option key={p.idProveedor} value={p.idProveedor}>{p.nombre}</option>)}
            </select>
          </div>
          <div className="campo">
            <label htmlFor="f-bodega" className="form-label">Bodega</label>
            <select id="f-bodega" className="form-select" value={idBodega ?? ''}
              onChange={(e) => cambiar({ idBodega: e.target.value ? Number(e.target.value) : undefined })}>
              <option value="">Todas</option>
              {bodegas.map((b) => <option key={b.idBodega} value={b.idBodega}>{b.nombre}</option>)}
            </select>
          </div>
          <div className="campo">
            <label htmlFor="f-desde" className="form-label">Desde</label>
            <input id="f-desde" type="date" className="form-control" value={fechaDesde} onChange={(e) => cambiar({ fechaDesde: e.target.value })} />
          </div>
          <div className="campo">
            <label htmlFor="f-hasta" className="form-label">Hasta</label>
            <input id="f-hasta" type="date" className="form-control" value={fechaHasta} onChange={(e) => cambiar({ fechaHasta: e.target.value })} />
          </div>
          <div className="campo form-check form-switch mb-2">
            <input id="f-atras" type="checkbox" className="form-check-input" checked={!!soloAtrasadas}
              onChange={(e) => cambiar({ soloAtrasadas: e.target.checked })} />
            <label htmlFor="f-atras" className="form-check-label">Solo atrasadas</label>
          </div>
          <div className="filtros-acciones">
            <button type="button" className="btn btn-claro" onClick={limpiar}>Limpiar filtros</button>
          </div>
        </div>

        {error && <div className="panel-cuerpo"><MensajeError texto={error} onReintentar={cargar} /></div>}
        {cargando && !resultado ? <Cargando /> : resultado && (
          <>
            <div className="tabla-envoltura">
              <table className="tabla">
                <thead>
                  <tr>
                    <EncabezadoOrdenable campo="Numero" texto="Orden" {...props} />
                    <EncabezadoOrdenable campo="Proveedor" texto="Proveedor" {...props} />
                    <EncabezadoOrdenable campo="FechaOrden" texto="Fecha" {...props} />
                    <EncabezadoOrdenable campo="FechaEsperada" texto="Entrega" {...props} />
                    <th>Recibido</th>
                    <EncabezadoOrdenable campo="Total" texto="Total" numero {...props} />
                    <EncabezadoOrdenable campo="Estado" texto="Estado" {...props} />
                    <th><span className="visually-hidden">Acciones</span></th>
                  </tr>
                </thead>
                <tbody style={{ opacity: cargando ? 0.55 : 1 }}>
                  {resultado.registros.length === 0 ? (
                    <tr><td colSpan={8}>
                      <SinRegistros titulo="No hay órdenes con estos filtros">
                        {puede('crearCompras') && <Link to="/ordenes-compra/nueva">Crear una orden de compra</Link>}
                      </SinRegistros>
                    </td></tr>
                  ) : resultado.registros.map((o) => (
                    <tr key={o.idOrdenCompra}>
                      <td className="nowrap">
                        <Link to={`/ordenes-compra/${o.idOrdenCompra}`} className="celda-principal">{o.numero}</Link>
                        <span className="celda-sub">{o.bodega}</span>
                      </td>
                      <td>
                        {o.proveedor}
                        <span className="celda-sub">{o.tipoPago === 'Credito' ? `Crédito ${o.diasCredito} días` : 'Contado'}</span>
                      </td>
                      <td className="nowrap">{formatoFecha(o.fechaOrden)}</td>
                      <td className="nowrap">
                        {formatoFecha(o.fechaEsperada)}
                        {o.estaAtrasada && <span className="celda-sub texto-error">Atrasada</span>}
                      </td>
                      <td style={{ minWidth: 110 }}>
                        <div className="avance" title={`${o.porcentajeRecibido}% recibido`}>
                          <span style={{ width: `${Math.min(100, o.porcentajeRecibido)}%` }} />
                        </div>
                        <span className="celda-sub">{Math.round(o.porcentajeRecibido)} %</span>
                      </td>
                      <td className="numero">{formatoMoneda(o.total)}</td>
                      <td><EstadoBadge estado={o.estado} /></td>
                      <td className="acciones">
                        {puede('recibirMercaderia') && (o.estado === 'Aprobada' || o.estado === 'Parcial') && (
                          <Link to={`/ordenes-compra/${o.idOrdenCompra}/recibir`} className="btn btn-claro btn-sm">Recibir</Link>
                        )}
                        {puede('crearCompras') && o.estado === 'Pendiente' && (
                          <Link to={`/ordenes-compra/${o.idOrdenCompra}/editar`} className="btn-icono" title="Editar" aria-label={`Editar ${o.numero}`}><i className="bi bi-pencil" /></Link>
                        )}
                        <Link to={`/ordenes-compra/${o.idOrdenCompra}`} className="btn-icono" title="Ver detalle" aria-label={`Ver ${o.numero}`}><i className="bi bi-eye" /></Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Paginacion pagina={resultado.pagina} totalPaginas={resultado.totalPaginas} total={resultado.total}
              tamanoPagina={resultado.tamanoPagina} onCambiar={(p) => setFiltro((f) => ({ ...f, pagina: p }))} />
          </>
        )}
      </section>
    </>
  )
}

export default OrdenesCompraPage
