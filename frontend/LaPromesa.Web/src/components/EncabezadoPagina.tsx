import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'

interface Props {
  titulo: string
  descripcion?: ReactNode
  volver?: { ruta: string; texto: string }
  acciones?: ReactNode
}

function EncabezadoPagina({ titulo, descripcion, volver, acciones }: Props) {
  return (
    <header className="encabezado">
      <div className="encabezado-texto">
        {volver && (
          <Link to={volver.ruta} className="encabezado-volver">
            <i className="bi bi-arrow-left" aria-hidden="true" /> {volver.texto}
          </Link>
        )}
        <h1>{titulo}</h1>
        {descripcion && <p>{descripcion}</p>}
      </div>
      {acciones && <div className="encabezado-acciones">{acciones}</div>}
    </header>
  )
}

export default EncabezadoPagina
