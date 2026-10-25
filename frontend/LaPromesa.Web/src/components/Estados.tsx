import type { ReactNode } from 'react'

export function Cargando({ texto = 'Cargando…' }: { texto?: string }) {
  return (
    <div className="cargando" role="status">
      <span className="spinner-border spinner-border-sm" aria-hidden="true" />
      <span>{texto}</span>
    </div>
  )
}

export function MensajeError({ texto, onReintentar }: { texto: string; onReintentar?: () => void }) {
  return (
    <div className="alerta alerta-error" role="alert">
      <i className="bi bi-exclamation-triangle" aria-hidden="true" />
      <span>{texto}</span>
      {onReintentar && <button type="button" className="btn btn-claro btn-sm" onClick={onReintentar}>Reintentar</button>}
    </div>
  )
}

export function SinRegistros({ icono = 'bi-inbox', titulo, children }: { icono?: string; titulo: string; children?: ReactNode }) {
  return (
    <div className="sin-registros">
      <i className={`bi ${icono}`} aria-hidden="true" />
      <strong>{titulo}</strong>
      {children && <div>{children}</div>}
    </div>
  )
}
