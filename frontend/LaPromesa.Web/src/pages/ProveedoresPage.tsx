import { useCallback, useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useAuth, useAvisos } from '../context/hooks'
import { consultarProveedores, eliminarProveedor, reactivarProveedor } from '../services/proveedorService'
import { consultarCategorias } from '../services/catalogoService'
import type { ProveedorConsulta, ProveedorFiltro } from '../interfaces/Proveedor'
import type { ResultadoPaginado } from '../interfaces/RespuestaApi'
import type { CategoriaConsulta } from '../interfaces/Catalogos'
import { formatoMoneda } from '../utils/formato'
import { leerError } from '../utils/errores'
import { useRetraso } from '../utils/useRetraso'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EncabezadoOrdenable from '../components/EncabezadoOrdenable'
import EstadoBadge from '../components/EstadoBadge'
import Paginacion from '../components/Paginacion'
import ModalMotivo from '../components/ModalMotivo'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'

function ProveedoresPage() {
  const { puede } = useAuth()
  const { avisar } = useAvisos()
  const [parametros] = useSearchParams()

  const [filtro, setFiltro] = useState<ProveedorFiltro>({
    buscar: '', estado: parametros.get('estado') ?? 'Activo', tipoPago: '', idCategoria: undefined,
    ordenarPor: 'Nombre', direccion: 'ASC', pagina: 1, tamanoPagina: 10,
  })
  const buscar = useRetraso(filtro.buscar)
  const [resultado, setResultado] = useState<ResultadoPaginado<ProveedorConsulta> | null>(null)
  const [categorias, setCategorias] = useState<CategoriaConsulta[]>([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)
  const [porInactivar, setPorInactivar] = useState<ProveedorConsulta | null>(null)
  const [procesando, setProcesando] = useState(false)

  const { estado, tipoPago, idCategoria, ordenarPor, direccion, pagina, tamanoPagina } = filtro

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      const respuesta = await consultarProveedores({ buscar, estado, tipoPago, idCategoria, ordenarPor, direccion, pagina, tamanoPagina })
      if (respuesta.exito) setResultado(respuesta.datos)
      else setError(respuesta.mensaje)
    } catch (e) {
      setError(leerError(e).mensaje)
    } finally {
      setCargando(false)
    }
  }, [buscar, estado, tipoPago, idCategoria, ordenarPor, direccion, pagina, tamanoPagina])

  useEffect(() => { cargar() }, [cargar])

  useEffect(() => {
    consultarCategorias(false).then((r) => r.exito && setCategorias(r.datos)).catch(() => undefined)
  }, [])

  const cambiar = (cambios: Partial<ProveedorFiltro>) => setFiltro((f) => ({ ...f, pagina: 1, ...cambios }))

  const ordenar = (campo: string) => setFiltro((f) => ({
    ...f, ordenarPor: campo, direccion: f.ordenarPor === campo && f.direccion === 'ASC' ? 'DESC' : 'ASC', pagina: 1,
  }))

  const limpiar = () => setFiltro((f) => ({ ...f, buscar: '', estado: 'Activo', tipoPago: '', idCategoria: undefined, pagina: 1 }))

  const inactivar = async (motivo: string) => {
    if (!porInactivar) return
    setProcesando(true)
    try {
      const r = await eliminarProveedor(porInactivar.idProveedor, motivo, porInactivar.rowVersion)
      avisar(r.mensaje || `${porInactivar.nombre} quedó inactivo.`)
      setPorInactivar(null)
      cargar()
    } catch (e) {
      avisar(leerError(e).mensaje, 'error')
    } finally {
      setProcesando(false)
    }
  }

  const reactivar = async (p: ProveedorConsulta) => {
    try {
      const r = await reactivarProveedor(p.idProveedor, p.rowVersion)
      avisar(r.mensaje || `${p.nombre} está activo de nuevo.`)
      cargar()
    } catch (e) {
      avisar(leerError(e).mensaje, 'error')
    }
  }

  const props = { ordenarPor: filtro.ordenarPor, direccion: filtro.direccion, onOrdenar: ordenar }

  return (
    <>
      <EncabezadoPagina
        titulo="Proveedores"
        descripcion="Empresas a las que La Promesa compra mercadería, con sus condiciones de pago y datos bancarios."
        acciones={puede('gestionarProveedores') && (
          <Link to="/proveedores/nuevo" className="btn btn-primary"><i className="bi bi-plus-lg" /> Agregar proveedor</Link>
        )}
      />

      <section className="panel">
        <div className="filtros">
          <div className="campo filtro-amplio">
            <label htmlFor="f-buscar" className="form-label">Buscar</label>
            <input id="f-buscar" type="search" className="form-control" placeholder="Nombre, NIT, contacto o código"
              value={filtro.buscar} onChange={(e) => cambiar({ buscar: e.target.value })} />
          </div>
          <div className="campo">
            <label htmlFor="f-estado" className="form-label">Estado</label>
            <select id="f-estado" className="form-select" value={filtro.estado} onChange={(e) => cambiar({ estado: e.target.value })}>
              <option value="">Todos</option>
              <option value="Activo">Activos</option>
              <option value="Inactivo">Inactivos</option>
            </select>
          </div>
          <div className="campo">
            <label htmlFor="f-tipo" className="form-label">Tipo de pago</label>
            <select id="f-tipo" className="form-select" value={filtro.tipoPago} onChange={(e) => cambiar({ tipoPago: e.target.value })}>
              <option value="">Todos</option>
              <option value="Contado">Contado</option>
              <option value="Credito">Crédito</option>
            </select>
          </div>
          <div className="campo">
            <label htmlFor="f-cat" className="form-label">Categoría</label>
            <select id="f-cat" className="form-select" value={filtro.idCategoria ?? ''}
              onChange={(e) => cambiar({ idCategoria: e.target.value ? Number(e.target.value) : undefined })}>
              <option value="">Todas</option>
              {categorias.map((c) => <option key={c.idCategoria} value={c.idCategoria}>{c.nombre}</option>)}
            </select>
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
                    <EncabezadoOrdenable campo="Codigo" texto="Código" {...props} />
                    <EncabezadoOrdenable campo="Nombre" texto="Proveedor" {...props} />
                    <EncabezadoOrdenable campo="Categoria" texto="Categoría" {...props} />
                    <th>Contacto</th>
                    <EncabezadoOrdenable campo="TipoPago" texto="Condición de pago" {...props} />
                    <EncabezadoOrdenable campo="SaldoPendiente" texto="Saldo por pagar" numero {...props} />
                    <EncabezadoOrdenable campo="Estado" texto="Estado" {...props} />
                    <th><span className="visually-hidden">Acciones</span></th>
                  </tr>
                </thead>
                <tbody style={{ opacity: cargando ? 0.55 : 1 }}>
                  {resultado.registros.length === 0 ? (
                    <tr><td colSpan={8}>
                      <SinRegistros titulo="No hay proveedores con estos filtros">
                        {puede('gestionarProveedores') && <Link to="/proveedores/nuevo">Agregar un proveedor</Link>}
                      </SinRegistros>
                    </td></tr>
                  ) : resultado.registros.map((p) => (
                    <tr key={p.idProveedor}>
                      <td className="nowrap texto-suave">{p.codigo}</td>
                      <td>
                        <Link to={`/proveedores/${p.idProveedor}`} className="celda-principal">{p.nombre}</Link>
                        <span className="celda-sub">NIT {p.nit}</span>
                      </td>
                      <td>{p.categoria}</td>
                      <td className="nowrap">
                        {p.contacto ?? '—'}
                        {p.telefono && <span className="celda-sub">{p.telefono}</span>}
                      </td>
                      <td className="nowrap">
                        {p.tipoPago === 'Credito' ? `Crédito ${p.diasCredito} días` : 'Contado'}
                        {p.tipoPago === 'Credito' && <span className="celda-sub">Límite {formatoMoneda(p.limiteCredito)}</span>}
                      </td>
                      <td className="numero">{formatoMoneda(p.saldoPendiente)}</td>
                      <td><EstadoBadge estado={p.estado} /></td>
                      <td className="acciones">
                        <Link to={`/proveedores/${p.idProveedor}`} className="btn-icono" title="Ver detalle" aria-label={`Ver ${p.nombre}`}>
                          <i className="bi bi-eye" />
                        </Link>
                        {puede('gestionarProveedores') && p.estado === 'Activo' && (
                          <Link to={`/proveedores/${p.idProveedor}/editar`} className="btn-icono" title="Editar" aria-label={`Editar ${p.nombre}`}>
                            <i className="bi bi-pencil" />
                          </Link>
                        )}
                        {puede('autorizarCompras') && (p.estado === 'Activo' ? (
                          <button type="button" className="btn-icono peligro" title="Inactivar" aria-label={`Inactivar ${p.nombre}`} onClick={() => setPorInactivar(p)}>
                            <i className="bi bi-slash-circle" />
                          </button>
                        ) : (
                          <button type="button" className="btn-icono exito" title="Reactivar" aria-label={`Reactivar ${p.nombre}`} onClick={() => reactivar(p)}>
                            <i className="bi bi-arrow-counterclockwise" />
                          </button>
                        ))}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <Paginacion pagina={resultado.pagina} totalPaginas={resultado.totalPaginas} total={resultado.total}
              tamanoPagina={resultado.tamanoPagina} onCambiar={(pagina) => setFiltro((f) => ({ ...f, pagina }))} />
          </>
        )}
      </section>

      <ModalMotivo
        abierto={!!porInactivar}
        titulo={`Inactivar a ${porInactivar?.nombre ?? ''}`}
        descripcion="El proveedor no se borra: queda inactivo, no podrá recibir nuevas órdenes y puede reactivarse después. No se permite si tiene órdenes abiertas o saldo pendiente."
        textoBoton="Inactivar proveedor"
        procesando={procesando}
        onConfirmar={inactivar}
        onCerrar={() => setPorInactivar(null)}
      />
    </>
  )
}

export default ProveedoresPage
