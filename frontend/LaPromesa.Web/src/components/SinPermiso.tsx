import { Link } from 'react-router-dom'
import { useAuth } from '../context/hooks'

function SinPermiso() {
  const { usuario } = useAuth()
  return (
    <section className="pantalla-vacia">
      <i className="bi bi-shield-lock" aria-hidden="true" />
      <h1>Esta sección no está disponible para su rol</h1>
      <p>Ingresó como <strong>{usuario?.rol}</strong>. Si necesita acceso, solicítelo al administrador del sistema.</p>
      <Link to="/" className="btn btn-primary">Volver al inicio</Link>
    </section>
  )
}

export default SinPermiso
