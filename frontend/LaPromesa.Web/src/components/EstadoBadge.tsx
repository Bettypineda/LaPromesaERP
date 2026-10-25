// Etiqueta de color para cada estado del módulo
const CLASE: Record<string, string> = {
  Activo: 'ok', Inactivo: 'apagado',
  Pendiente: 'espera', Aprobada: 'info', Parcial: 'alerta', Recibida: 'ok', Anulada: 'error',
  Pagada: 'ok', Aprobado: 'ok', Rechazado: 'error',
  ATiempo: 'ok', Anticipada: 'info', Retraso: 'error',
  Excelente: 'ok', Bueno: 'info', Regular: 'alerta', Deficiente: 'error',
}

const TEXTO: Record<string, string> = { ATiempo: 'A tiempo', Retraso: 'Con retraso' }

function EstadoBadge({ estado }: { estado: string | null | undefined }) {
  if (!estado) return <span className="estado estado-apagado">—</span>
  return <span className={`estado estado-${CLASE[estado] ?? 'apagado'}`}>{TEXTO[estado] ?? estado}</span>
}

export default EstadoBadge
