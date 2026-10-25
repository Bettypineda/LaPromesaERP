import type { HistorialOrden, OrdenCompraConsulta } from '../interfaces/OrdenCompra'
import { formatoFechaHora } from '../utils/formato'

// Recorrido de la orden: Pendiente → Aprobada → Parcial → Recibida (o Anulada)
const PASOS = [
  { estado: 'Pendiente', texto: 'Creada', icono: 'bi-pencil-square' },
  { estado: 'Aprobada', texto: 'Aprobada', icono: 'bi-patch-check' },
  { estado: 'Parcial', texto: 'Recepción parcial', icono: 'bi-box-seam' },
  { estado: 'Recibida', texto: 'Recibida completa', icono: 'bi-check2-all' },
]
const ORDEN: Record<string, number> = { Pendiente: 0, Aprobada: 1, Parcial: 2, Recibida: 3 }

function RecorridoOrden({ orden, historial }: { orden: OrdenCompraConsulta; historial: HistorialOrden[] }) {
  const anulada = orden.estado === 'Anulada'
  const actual = anulada
    ? Math.max(0, ...historial.filter((h) => h.estadoNuevo !== 'Anulada').map((h) => ORDEN[h.estadoNuevo] ?? 0))
    : ORDEN[orden.estado] ?? 0

  const cuando = (estado: string) => {
    const h = [...historial].reverse().find((x) => x.estadoNuevo === estado)
    return h ? { fecha: formatoFechaHora(h.fecha), usuario: h.usuario } : null
  }

  // Si la orden se recibió completa en una sola entrega, el paso "parcial" se marca como omitido
  const omitido = (estado: string) => estado === 'Parcial' && orden.estado === 'Recibida' && !cuando('Parcial')

  return (
    <ol className={`recorrido ${anulada ? 'recorrido-anulada' : ''}`} aria-label="Recorrido de la orden">
      {PASOS.map((p, i) => {
        const estado = anulada && i > actual ? 'bloqueado' : i < actual || (i === actual && orden.estado === 'Recibida') ? 'hecho' : i === actual ? 'actual' : 'futuro'
        const dato = cuando(p.estado)
        return (
          <li key={p.estado} className={`recorrido-paso ${omitido(p.estado) ? 'omitido' : estado}`}
            aria-current={estado === 'actual' ? 'step' : undefined}>
            <span className="recorrido-icono"><i className={`bi ${p.icono}`} aria-hidden="true" /></span>
            <span className="recorrido-texto">
              <strong>{p.texto}</strong>
              <small>{omitido(p.estado) ? 'Se recibió en una sola entrega' : dato ? `${dato.fecha} · ${dato.usuario}` : estado === 'actual' ? 'En curso' : ' '}</small>
            </span>
          </li>
        )
      })}
      {anulada && (
        <li className="recorrido-paso anulado" aria-current="step">
          <span className="recorrido-icono"><i className="bi bi-x-lg" aria-hidden="true" /></span>
          <span className="recorrido-texto">
            <strong>Anulada</strong>
            <small>{formatoFechaHora(orden.fechaAnulacion)} · {orden.anuladoPor}</small>
          </span>
        </li>
      )}
    </ol>
  )
}

export default RecorridoOrden
