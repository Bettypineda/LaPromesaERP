import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../context/hooks'
import type { Permiso } from '../utils/roles'
import SinPermiso from './SinPermiso'

// Sin sesión → login. Con sesión pero sin el rol requerido → aviso de permiso.
function RutaProtegida({ permiso }: { permiso?: Permiso }) {
  const { usuario, puede, cierreManual } = useAuth()
  const ubicacion = useLocation()

  // Si la sesión venció se vuelve a la misma página después de ingresar; si cerró sesión, a Inicio
  if (!usuario) return <Navigate to="/login" replace state={cierreManual ? undefined : { desde: ubicacion.pathname }} />
  if (permiso && !puede(permiso)) return <SinPermiso />
  return <Outlet />
}

export default RutaProtegida
