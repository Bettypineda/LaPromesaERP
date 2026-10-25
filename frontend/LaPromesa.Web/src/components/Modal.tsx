import { useEffect, useRef, type ReactNode } from 'react'

interface Props {
  abierto: boolean
  titulo: string
  onCerrar: () => void
  children: ReactNode
  pie?: ReactNode
  ancho?: 'normal' | 'amplio'
}

// Ventana modal accesible (Escape cierra, el foco entra al abrir)
function Modal({ abierto, titulo, onCerrar, children, pie, ancho = 'normal' }: Props) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!abierto) return
    const alTeclear = (e: KeyboardEvent) => { if (e.key === 'Escape') onCerrar() }
    document.addEventListener('keydown', alTeclear)
    const enfocable = ref.current?.querySelector<HTMLElement>('input, textarea, select, button:not(.modal-cerrar)')
    enfocable?.focus()
    return () => document.removeEventListener('keydown', alTeclear)
  }, [abierto, onCerrar])

  if (!abierto) return null
  return (
    <div className="modal-fondo" onMouseDown={(e) => { if (e.target === e.currentTarget) onCerrar() }}>
      <div ref={ref} className={`modal-caja modal-${ancho}`} role="dialog" aria-modal="true" aria-labelledby="modal-titulo">
        <div className="modal-cabecera">
          <h2 id="modal-titulo">{titulo}</h2>
          <button type="button" className="modal-cerrar" aria-label="Cerrar" onClick={onCerrar}>
            <i className="bi bi-x-lg" aria-hidden="true" />
          </button>
        </div>
        <div className="modal-cuerpo">{children}</div>
        {pie && <div className="modal-pie">{pie}</div>}
      </div>
    </div>
  )
}

export default Modal
