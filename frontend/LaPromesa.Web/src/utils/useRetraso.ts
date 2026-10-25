import { useEffect, useState } from 'react'

// Espera a que el usuario deje de escribir antes de consultar la API
export function useRetraso<T>(valor: T, milisegundos = 350) {
  const [retrasado, setRetrasado] = useState(valor)
  useEffect(() => {
    const t = window.setTimeout(() => setRetrasado(valor), milisegundos)
    return () => window.clearTimeout(t)
  }, [valor, milisegundos])
  return retrasado
}
