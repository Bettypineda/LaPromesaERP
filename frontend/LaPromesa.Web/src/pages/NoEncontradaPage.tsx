import { Link } from 'react-router-dom'

function NoEncontradaPage() {
  return (
    <section className="pantalla-vacia">
      <i className="bi bi-signpost-split" aria-hidden="true" />
      <h1>No encontramos esta página</h1>
      <p>Revise la dirección o regrese al inicio para continuar.</p>
      <Link to="/" className="btn btn-primary">Ir al inicio</Link>
    </section>
  )
}

export default NoEncontradaPage
