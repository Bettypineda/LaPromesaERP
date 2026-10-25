import { useContext } from 'react'
import { AuthContext } from './AuthContext'
import { AvisosContext } from './AvisosContext'

export const useAuth = () => {
  const contexto = useContext(AuthContext)
  if (!contexto) throw new Error('useAuth debe usarse dentro de AuthProvider')
  return contexto
}

export const useAvisos = () => {
  const contexto = useContext(AvisosContext)
  if (!contexto) throw new Error('useAvisos debe usarse dentro de AvisosProvider')
  return contexto
}
