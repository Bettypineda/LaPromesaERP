import { useCallback, useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useAuth } from '../context/hooks'
import { consultarCuentasPorPagar } from '../services/cuentaPorPagarService'
import { listarProveedores } from '../services/listasService'
import type { CuentaPorPagarConsulta, CuentaPorPagarFiltro } from '../interfaces/CuentaPorPagar'
import type { ResultadoPaginado } from '../interfaces/RespuestaApi'
import type { ProveedorConsulta } from '../interfaces/Proveedor'
import { formatoFecha, formatoMoneda } from '../utils/formato'
import { leerError } from '../utils/errores'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EstadoBadge from '../components/EstadoBadge'
import Paginacion from '../components/Paginacion'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'

function CuentasPorPagarPage() {
  const { puede } = useAuth()
  const [parametros] = useSearchParams()
  const [filtro, setFiltro] = useState<CuentaPorPagarFiltro>({
    idProveedor: undefined, estado: '', soloVencidas: parametros.get('soloVencidas') === 'true', soloConSaldo: true,
    venceDesde: '', venceHasta: '', pagina: 1, tamanoPagina: 10,
  })
  const [resultado, setResultado] = useState<ResultadoPaginado<CuentaPorPagarConsulta> | null>(null)
  const [proveedores, setProveedores] = useState<ProveedorConsulta[]>([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      const r = await consultarCuentasPorPagar(filtro)
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

  const cambiar = (cambios: Partial<CuentaPorPagarFiltro>) => setFiltro((f) => ({ ...f, pagina: 1, ...cambios }))
  const saldoPagina = resultado?.registros.reduce((s, c) => s + c.saldo, 0) ?? 0

  return (
    <>
      <EncabezadoPagina
        titulo="Cuentas por pagar"
        descripcion="Deudas con proveedores generadas por cada recepción. Las transferencias se confirman con el banco."
        acciones={puede('verReportes') && (
          <Link to="/reportes?tipo=cuentas" className="btn btn-claro"><i className="bi bi-bar-chart-line" /> Antigüedad de saldos</Link>
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
            <label htmlFor="f-estado" className="form-label">Estado</label>
            <select id="f-estado" className="form-select" value={filtro.estado}
              onChange={(e) => cambiar({ estado: e.target.value, soloConSaldo: e.target.value === 'Pagada' ? false : filtro.soloConSaldo })}>
              <option value="">Todos</option>
              <option value="Pendiente">Pendiente</option>
              <option value="Parcial">Parcial</option>
              <option value="Pagada">Pagada</option>
            </select>
          </div>
          <div className="campo">
            <label htmlFor="f-desde" className="form-label">Vence desde</label>
            <input id="f-desde" type="date" className="form-control" value={filtro.venceDesde} onChange={(e) => cambiar({ venceDesde: e.target.value })} />
          </div>
          <div className="campo">
            <label htmlFor="f-hasta" className="form-label">Vence hasta</label>
            <input id="f-hasta" type="date" className="form-control" value={filtro.venceHasta} onChange={(e) => cambiar({ venceHasta: e.target.value })} />
          </div>
          <div className="campo">
            <div className="form-check form-switch">
              <input id="f-venc" type="checkbox" className="form-check-input" checked={!!filtro.soloVencidas} onChange={(e) => cambiar({ soloVencidas: e.target.checked })} />
              <label htmlFor="f-venc" className="form-check-label">Solo vencidas</label>
            </div>
            <div className="form-check form-switch">
              <input id="f-saldo" type="checkbox" className="form-check-input" checked={!filtro.soloConSaldo} onChange={(e) => cambiar({ soloConSaldo: !e.target.checked })} />
              <label htmlFor="f-saldo" className="form-check-label">Incluir pagadas</label>
            </div>
          </div>
        </div>

        {error && <div className="panel-cuerpo"><MensajeError texto={error} onReintentar={cargar} /></div>}
        {cargando && !resultado ? <Cargando /> : resultado && (
          <>
            <div className="tabla-envoltura">
              <table className="tabla">
                <thead>
                  <tr>
                    <th>Cuenta</th><th>Proveedor</th><th>Documento</th><th>Vencimiento</th>
                    <th className="numero">Monto</th><th className="numero">Saldo</th><th>Estado</th>
                    <th><span className="visually-hidden">Acciones</span></th>
                  </tr>
                </thead>
                <tbody style={{ opacity: cargando ? 0.55 : 1 }}>
                  {resultado.registros.length === 0 ? (
                    <tr><td colSpan={8}><SinRegistros icono="bi-check2-circle" titulo="No hay cuentas con estos filtros" /></td></tr>
                  ) : resultado.registros.map((c) => (
                    <tr key={c.idCuentaPagar}>
                      <td><Link to={`/cuentas-por-pagar/${c.idCuentaPagar}`} className="celda-principal">{c.numero}</Link></td>
                      <td>{c.proveedor}<span className="celda-sub">NIT {c.nitProveedor}</span></td>
                      <td>Factura {c.facturaProveedor}<span className="celda-sub">{c.numeroOrden} · {c.numeroRecepcion}</span></td>
                      <td className="nowrap">
                        {formatoFecha(c.fechaVencimiento)}
                        {c.saldo > 0 && (c.diasVencida > 0
                          ? <span className="celda-sub texto-error">{c.diasVencida} días vencida</span>
                          : <span className="celda-sub">{c.rangoAntiguedad}</span>)}
                      </td>
                      <td className="numero">{formatoMoneda(c.monto)}</td>
                      <td className="numero">
                        <strong>{formatoMoneda(c.saldo)}</strong>
                        {c.montoEnProceso > 0 && <span className="celda-sub texto-alerta">{formatoMoneda(c.montoEnProceso)} en proceso</span>}
                      </td>
                      <td><EstadoBadge estado={c.estado} /></td>
                      <td className="acciones">
                        {puede('registrarPagos') && c.saldoDisponible > 0 ? (
                          <Link to={`/cuentas-por-pagar/${c.idCuentaPagar}#pagar`} className="btn btn-claro btn-sm">Pagar</Link>
                        ) : (
                          <Link to={`/cuentas-por-pagar/${c.idCuentaPagar}`} className="btn-icono" aria-label={`Ver ${c.numero}`} title="Ver detalle"><i className="bi bi-eye" /></Link>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
                {resultado.registros.length > 0 && (
                  <tfoot>
                    <tr><td colSpan={5} className="text-end">Saldo de esta página</td><td className="numero">{formatoMoneda(saldoPagina)}</td><td colSpan={2} /></tr>
                  </tfoot>
                )}
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

export default CuentasPorPagarPage
