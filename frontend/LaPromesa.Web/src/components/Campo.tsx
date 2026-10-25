import type { ReactNode } from 'react'

interface Props {
  id: string
  etiqueta: string
  error?: string
  ayuda?: ReactNode
  requerido?: boolean
  children: ReactNode
  className?: string
}

// Etiqueta + control + mensaje de validación (Bootstrap)
function Campo({ id, etiqueta, error, ayuda, requerido, children, className = '' }: Props) {
  return (
    <div className={`campo ${className}`}>
      <label htmlFor={id} className="form-label">
        {etiqueta}{requerido && <span className="requerido" aria-hidden="true"> *</span>}
      </label>
      {children}
      {error ? <div className="invalid-feedback d-block">{error}</div> : ayuda && <div className="form-text">{ayuda}</div>}
    </div>
  )
}

export default Campo
