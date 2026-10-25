import { useEffect, useState, type FormEvent, type ReactNode } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useAvisos } from '../context/hooks'
import { descargarReporteCsv, generarReporte } from '../services/reporteService'
import { listarProveedores } from '../services/listasService'
import { consultarBodegas, consultarCategorias } from '../services/catalogoService'
import type { FilaReporte, Reporte, ReporteCuentasFiltro, ReportePeriodoFiltro } from '../interfaces/Reporte'
import type { ProveedorConsulta } from '../interfaces/Proveedor'
import type { Bodega, CategoriaConsulta } from '../interfaces/Catalogos'
import { formatoFecha, formatoFechaHora, formatoMoneda, formatoNumero, formatoPorcentaje, hoyIso } from '../utils/formato'
import { leerError } from '../utils/errores'
import EncabezadoPagina from '../components/EncabezadoPagina'
import EstadoBadge from '../components/EstadoBadge'
import { Cargando, MensajeError, SinRegistros } from '../components/Estados'
import { REPORTES, type Columna, type DefinicionReporte, type Formato } from './reportesConfig'
import './ReportesPage.css'

const formatear = (valor: FilaReporte[string] | undefined, formato: Formato = 'texto'): ReactNode => {
  if (valor === null || valor === undefined || valor === '') return '—'
  switch (formato) {
    case 'moneda': return formatoMoneda(Number(valor))
    case 'numero': return formatoNumero(Number(valor))
    case 'porcentaje': return formatoPorcentaje(Number(valor))
    case 'fecha': return formatoFecha(String(valor))
    case 'estado': return <EstadoBadge estado={String(valor)} />
    default: return String(valor)
  }
}

const esNumerico = (f?: Formato) => f === 'moneda' || f === 'numero' || f === 'porcentaje'
const claseCelda = (f?: Formato) => (esNumerico(f) ? 'numero' : f === 'fecha' ? 'nowrap' : undefined)

function ReportesPage() {
  const { avisar } = useAvisos()
  const [parametros, setParametros] = useSearchParams()
  const def = REPORTES.find((r) => r.id === parametros.get('tipo')) ?? REPORTES[0]

  const [periodo, setPeriodo] = useState<ReportePeriodoFiltro>({
    fechaDesde: hoyIso(-90), fechaHasta: hoyIso(), idProveedor: undefined, idCategoria: undefined, idBodega: undefined, estado: '', incluirAnuladas: false,
  })
  const [corte, setCorte] = useState<ReporteCuentasFiltro>({ fechaCorte: hoyIso(), idProveedor: undefined, idCategoria: undefined, incluirPagadas: false })
  const [reporte, setReporte] = useState<Reporte | null>(null)
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)
  const [descargando, setDescargando] = useState(false)
  const [proveedores, setProveedores] = useState<ProveedorConsulta[]>([])
  const [categorias, setCategorias] = useState<CategoriaConsulta[]>([])
  const [bodegas, setBodegas] = useState<Bodega[]>([])

  useEffect(() => {
    listarProveedores(false).then(setProveedores)
    consultarCategorias(false).then((r) => r.exito && setCategorias(r.datos)).catch(() => undefined)
    consultarBodegas().then((r) => r.exito && setBodegas(r.datos)).catch(() => undefined)
  }, [])

  const filtroActual = () => (def.porPeriodo ? periodo : corte)

  const generar = async (evento?: FormEvent) => {
    evento?.preventDefault()
    if (def.porPeriodo && periodo.fechaDesde > periodo.fechaHasta) {
      setError('La fecha inicial no puede ser mayor que la final.')
      return
    }
    setCargando(true)
    setError('')
    try {
      const r = await generarReporte(def.tipo, filtroActual())
      if (r.exito) setReporte(r.datos)
      else setError(r.mensaje)
    } catch (e) {
      setReporte(null)
      setError(leerError(e).mensaje)
    } finally {
      setCargando(false)
    }
  }

  // Al cambiar de reporte se genera con los filtros por defecto
  useEffect(() => {
    setReporte(null)
    generar()
  }, [def.id]) // eslint-disable-line react-hooks/exhaustive-deps

  const descargar = async () => {
    setDescargando(true)
    try {
      await descargarReporteCsv(def.tipo, filtroActual())
      avisar('Archivo CSV descargado. Ábralo con Excel.')
    } catch (e) {
      avisar(leerError(e, 'No se pudo descargar el archivo.').mensaje, 'error')
    } finally {
      setDescargando(false)
    }
  }

  return (
    <>
      <EncabezadoPagina
        titulo="Reportes"
        descripcion="Información consolidada del módulo de compras, lista para imprimir o abrir en Excel."
        acciones={<>
          <button type="button" className="btn btn-claro" onClick={descargar} disabled={descargando || !reporte}>
            <i className="bi bi-filetype-csv" /> {descargando ? 'Descargando…' : 'Descargar CSV'}
          </button>
          <button type="button" className="btn btn-claro" onClick={() => window.print()} disabled={!reporte}>
            <i className="bi bi-printer" /> Imprimir
          </button>
        </>}
      />

      <div className="reportes-selector no-imprimir" role="tablist" aria-label="Reporte">
        {REPORTES.map((r) => (
          <button key={r.id} type="button" role="tab" aria-selected={r.id === def.id}
            className={`reporte-opcion ${r.id === def.id ? 'activa' : ''}`} onClick={() => setParametros({ tipo: r.id })}>
            <strong>{r.titulo}</strong>
            <span>{r.descripcion}</span>
          </button>
        ))}
      </div>

      <form className="panel no-imprimir" onSubmit={generar}>
        <div className="filtros">
          {def.porPeriodo ? (
            <>
              <div className="campo">
                <label htmlFor="r-desde" className="form-label">Desde</label>
                <input id="r-desde" type="date" className="form-control" required value={periodo.fechaDesde}
                  onChange={(e) => setPeriodo({ ...periodo, fechaDesde: e.target.value })} />
              </div>
              <div className="campo">
                <label htmlFor="r-hasta" className="form-label">Hasta</label>
                <input id="r-hasta" type="date" className="form-control" required value={periodo.fechaHasta}
                  onChange={(e) => setPeriodo({ ...periodo, fechaHasta: e.target.value })} />
              </div>
            </>
          ) : (
            <div className="campo">
              <label htmlFor="r-corte" className="form-label">Fecha de corte</label>
              <input id="r-corte" type="date" className="form-control" required value={corte.fechaCorte}
                onChange={(e) => setCorte({ ...corte, fechaCorte: e.target.value })} />
            </div>
          )}
          <SelectorId id="r-prov" etiqueta="Proveedor" opciones={proveedores.map((p) => [p.idProveedor, p.nombre])}
            valor={def.porPeriodo ? periodo.idProveedor : corte.idProveedor}
            onCambiar={(v) => (def.porPeriodo ? setPeriodo({ ...periodo, idProveedor: v }) : setCorte({ ...corte, idProveedor: v }))} />
          <SelectorId id="r-cat" etiqueta="Categoría" opciones={categorias.map((c) => [c.idCategoria, c.nombre])}
            valor={def.porPeriodo ? periodo.idCategoria : corte.idCategoria}
            onCambiar={(v) => (def.porPeriodo ? setPeriodo({ ...periodo, idCategoria: v }) : setCorte({ ...corte, idCategoria: v }))} />
          {def.id === 'compras' && (
            <>
              <SelectorId id="r-bod" etiqueta="Bodega" opciones={bodegas.map((b) => [b.idBodega, b.nombre])}
                valor={periodo.idBodega} onCambiar={(v) => setPeriodo({ ...periodo, idBodega: v })} />
              <div className="campo">
                <label htmlFor="r-estado" className="form-label">Estado</label>
                <select id="r-estado" className="form-select" value={periodo.estado} onChange={(e) => setPeriodo({ ...periodo, estado: e.target.value })}>
                  <option value="">Todos</option>
                  {['Pendiente', 'Aprobada', 'Parcial', 'Recibida', 'Anulada'].map((e) => <option key={e}>{e}</option>)}
                </select>
              </div>
              <div className="campo form-check form-switch mb-2">
                <input id="r-anul" type="checkbox" className="form-check-input" checked={!!periodo.incluirAnuladas}
                  onChange={(e) => setPeriodo({ ...periodo, incluirAnuladas: e.target.checked })} />
                <label htmlFor="r-anul" className="form-check-label">Incluir anuladas</label>
              </div>
            </>
          )}
          {def.id === 'cuentas' && (
            <div className="campo form-check form-switch mb-2">
              <input id="r-pag" type="checkbox" className="form-check-input" checked={!!corte.incluirPagadas}
                onChange={(e) => setCorte({ ...corte, incluirPagadas: e.target.checked })} />
              <label htmlFor="r-pag" className="form-check-label">Incluir pagadas</label>
            </div>
          )}
          <div className="filtros-acciones">
            <button type="submit" className="btn btn-primary" disabled={cargando}>{cargando ? 'Generando…' : 'Generar reporte'}</button>
          </div>
        </div>
      </form>

      {error && <MensajeError texto={error} onReintentar={() => generar()} />}
      {cargando && !reporte && <Cargando texto="Generando reporte…" />}
      {reporte && <ResultadoReporte def={def} reporte={reporte} cargando={cargando}
        periodo={def.porPeriodo ? `${formatoFecha(periodo.fechaDesde)} al ${formatoFecha(periodo.fechaHasta)}` : `al ${formatoFecha(corte.fechaCorte)}`} />}
    </>
  )
}

function SelectorId({ id, etiqueta, opciones, valor, onCambiar }: {
  id: string; etiqueta: string; opciones: [number, string][]; valor?: number; onCambiar: (v?: number) => void
}) {
  return (
    <div className="campo">
      <label htmlFor={id} className="form-label">{etiqueta}</label>
      <select id={id} className="form-select" value={valor ?? ''} onChange={(e) => onCambiar(e.target.value ? Number(e.target.value) : undefined)}>
        <option value="">Todos</option>
        {opciones.map(([v, t]) => <option key={v} value={v}>{t}</option>)}
      </select>
    </div>
  )
}

function ResultadoReporte({ def, reporte, cargando, periodo }: { def: DefinicionReporte; reporte: Reporte; cargando: boolean; periodo: string }) {
  const t = reporte.totales ?? {}
  return (
    <div style={{ opacity: cargando ? 0.55 : 1 }}>
      <div className="reporte-titulo-impresion">
        <h2>{def.titulo}</h2>
        <p>Período {periodo} · generado {formatoFechaHora(String(t.fechaGeneracion ?? new Date().toISOString()))}</p>
      </div>

      <div className="cifras">
        {def.cifras.map((c) => (
          <div key={c.clave} className="cifra">
            <span className="cifra-valor">{formatear(t[c.clave], c.formato)}</span>
            <span className="cifra-etiqueta">{c.titulo}</span>
          </div>
        ))}
      </div>

      <TablaReporte titulo={def.resumenTitulo} columnas={def.resumen} filas={reporte.resumen} barra={def.barra} />
      <TablaReporte titulo={def.detalleTitulo} columnas={def.detalle} filas={reporte.detalle} />
    </div>
  )
}

function TablaReporte({ titulo, columnas, filas, barra }: {
  titulo: string; columnas: Columna[]; filas: FilaReporte[]; barra?: { clave: string; titulo: string }
}) {
  const totales = columnas.some((c) => c.total)
  return (
    <section className="panel">
      <div className="panel-cabecera"><h2>{titulo}</h2><span className="texto-suave small">{filas.length} registro(s)</span></div>
      {filas.length === 0 ? <SinRegistros icono="bi-bar-chart" titulo="No hay datos para estos filtros" /> : (
        <div className="tabla-envoltura">
          <table className="tabla tabla-reporte">
            <thead>
              <tr>
                {columnas.map((c) => <th key={c.clave} className={esNumerico(c.formato) ? 'numero' : undefined}>{c.titulo}</th>)}
                {barra && <th>{barra.titulo}</th>}
              </tr>
            </thead>
            <tbody>
              {filas.map((f, i) => (
                <tr key={i}>
                  {columnas.map((c) => <td key={c.clave} className={claseCelda(c.formato)}>{formatear(f[c.clave], c.formato)}</td>)}
                  {barra && (
                    <td>
                      <div className="celda-barra">
                        <span className="barra-reporte"><span style={{ width: `${Math.min(100, Number(f[barra.clave] ?? 0))}%` }} /></span>
                        <span className="numero">{formatoPorcentaje(Number(f[barra.clave] ?? 0))}</span>
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
            {totales && (
              <tfoot>
                <tr>
                  {columnas.map((c, i) => (
                    <td key={c.clave} className={esNumerico(c.formato) ? 'numero' : undefined}>
                      {c.total ? formatear(filas.reduce((s, f) => s + Number(f[c.clave] ?? 0), 0), c.formato) : i === 0 ? 'Totales' : ''}
                    </td>
                  ))}
                  {barra && <td />}
                </tr>
              </tfoot>
            )}
          </table>
        </div>
      )}
    </section>
  )
}

export default ReportesPage
