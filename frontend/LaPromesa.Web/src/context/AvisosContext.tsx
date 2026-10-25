import { createContext, useCallback, useMemo, useState, type ReactNode } from 'react'

type TipoAviso = 'exito' | 'error' | 'info'

interface Aviso {
  id: number
  tipo: TipoAviso
  texto: string
}

export interface ContextoAvisos {
  avisar: (texto: string, tipo?: TipoAviso) => void
}

export const AvisosContext = createContext<ContextoAvisos | null>(null)

const ICONO: Record<TipoAviso, string> = {
  exito: 'bi-check-circle-fill',
  error: 'bi-exclamation-octagon-fill',
  info: 'bi-info-circle-fill',
}

// Avisos breves (toasts) que confirman lo que acaba de pasar
export function AvisosProvider({ children }: { children: ReactNode }) {
  const [avisos, setAvisos] = useState<Aviso[]>([])

  const quitar = useCallback((id: number) => setAvisos((lista) => lista.filter((a) => a.id !== id)), [])

  const avisar = useCallback((texto: string, tipo: TipoAviso = 'exito') => {
    const id = Date.now() + Math.random()
    setAvisos((lista) => [...lista, { id, tipo, texto }])
    window.setTimeout(() => quitar(id), tipo === 'error' ? 7000 : 4500)
  }, [quitar])

  const valor = useMemo(() => ({ avisar }), [avisar])

  return (
    <AvisosContext.Provider value={valor}>
      {children}
      <div className="avisos" role="status" aria-live="polite">
        {avisos.map((a) => (
          <div key={a.id} className={`aviso aviso-${a.tipo}`}>
            <i className={`bi ${ICONO[a.tipo]}`} aria-hidden="true" />
            <span>{a.texto}</span>
            <button type="button" className="aviso-cerrar" aria-label="Cerrar aviso" onClick={() => quitar(a.id)}>
              <i className="bi bi-x-lg" aria-hidden="true" />
            </button>
          </div>
        ))}
      </div>
    </AvisosContext.Provider>
  )
}
