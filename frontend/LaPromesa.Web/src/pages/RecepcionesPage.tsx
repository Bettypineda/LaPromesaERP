import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../context/hooks'
import { consultarRecepciones } from '../services/recepcionService'
import { listarProveedores } from '../services/listasService'
import type { RecepcionConsulta, RecepcionFiltro } from '../interfaces/Recepcion'
import type { ResultadoPaginado } from '../interfaces/RespuestaApi'
import type { ProveedorConsulta } from '../interfaces/Proveedor'
import { formatoFecha, formatoMoneda } from '../utils/formato'
import { leerError } from '../utils/errores'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EstadoBadge from '../components/EstadoBadge'
import Paginacion from '../components/Paginacion'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'

function RecepcionesPage() {
  const { puede } = useAuth()
  const [filtro, setFiltro] = useState<RecepcionFiltro>({
    idProveedor: undefined, cumplimiento: '', fechaDesde: '', fechaHasta: '', pagina: 1, tamanoPagina: 10,
  })
  const [resultado, setResultado] = useState<ResultadoPaginado<RecepcionConsulta> | null>(null)
  const [proveedores, setProveedores] = useState<ProveedorConsulta[]>([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      const r = await consultarRecepciones(filtro)
      if (r.exito) setResultado(r.datos)
      else setError(r.mensaje)
    } catch (e) {
      setError(leerError(e).mensaje)
    } finally {
      setCargando(false)
    }
  }, [filtro])

  useEffect(() => { cargar() }, [cargar])
  useEffect(() => { listarProveedores(false).then(setProveedores) }, [])

  const cambiar = (cambios: Partial<RecepcionFiltro>) => setFiltro((f) => ({ ...f, pagina: 1, ...cambios }))

  return (
    <>
      <EncabezadoPagina
        titulo="Recepciones de mercadería"
        descripcion="Notas de compra registradas por bodega. Cada una suma inventario y genera su cuenta por pagar."
        acciones={puede('recibirMercaderia') && (
          <Link to="/ordenes-compra?estado=Aprobada" className="btn btn-primary"><i className="bi bi-box-seam" /> Recibir una orden</Link>
        )}
      />

      <section className="panel">
        <div className="filtros">
          <div className="campo filtro-amplio">
            <label htmlFor="f-prov" className="form-label">Proveedor</label>
            <select id="f-prov" className="form-select" value={filtro.idProveedor ?? ''}
              onChange={(e) => cambiar({ idProveedor: e.target.value ? Number(e.target.value) : undefined })}>
              <option value="">Todos</option>
              {proveedores.map((p) => <option key={p.idProveedor} value={p.idProveedor}>{p.nombre}</option>)}
            </select>
          </div>
          <div className="campo">
            <label htmlFor="f-cump" className="form-label">Cumplimiento</label>
            <select id="f-cump" className="form-select" value={filtro.cumplimiento} onChange={(e) => cambiar({ cumplimiento: e.target.value })}>
              <option value="">Todos</option>
              <option value="ATiempo">A tiempo</option>
              <option value="Anticipada">Anticipada</option>
              <option value="Retraso">Con retraso</option>
            </select>
          </div>
          <div className="campo">
            <label htmlFor="f-desde" className="form-label">Desde</label>
            <input id="f-desde" type="date" className="form-control" value={filtro.fechaDesde} onChange={(e) => cambiar({ fechaDesde: e.target.value })} />
          </div>
          <div className="campo">
            <label htmlFor="f-hasta" className="form-label">Hasta</label>
            <input id="f-hasta" type="date" className="form-control" value={filtro.fechaHasta} onChange={(e) => cambiar({ fechaHasta: e.target.value })} />
          </div>
        </div>

        {error && <div className="panel-cuerpo"><MensajeError texto={error} onReintentar={cargar} /></div>}
        {cargando && !resultado ? <Cargando /> : resultado && (
          <>
            <div className="tabla-envoltura">
              <table className="tabla">
                <thead>
                  <tr>
                    <th>Nota</th><th>Orden</th><th>Proveedor</th><th>Recibida</th><th>Factura</th>
                    <th>Cumplimiento</th><th className="numero">Total</th><th>Recibió</th>
                  </tr>
                </thead>
                <tbody style={{ opacity: cargando ? 0.55 : 1 }}>
                  {resultado.registros.length === 0 ? (
                    <tr><td colSpan={8}><SinRegistros icono="bi-box-seam" titulo="No hay recepciones con estos filtros" /></td></tr>
                  ) : resultado.registros.map((r) => (
                    <tr key={r.idRecepcion}>
                      <td><Link to={`/recepciones/${r.idRecepcion}`} className="celda-principal">{r.numero}</Link></td>
                      <td><Link to={`/ordenes-compra/${r.idOrdenCompra}`}>{r.numeroOrden}</Link></td>
                      <td>{r.proveedor}<span className="celda-sub">{r.bodega}</span></td>
                      <td className="nowrap">{formatoFecha(r.fechaRecepcion)}<span className="celda-sub">esperada {formatoFecha(r.fechaEsperada)}</span></td>
                      <td>{r.factura}</td>
                      <td><EstadoBadge estado={r.cumplimiento} /></td>
                      <td className="numero">{formatoMoneda(r.total)}</td>
                      <td>{r.recibidoPor}</td>
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

export default RecepcionesPage
