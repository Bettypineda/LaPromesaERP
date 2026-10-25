interface Props {
  pagina: number
  totalPaginas: number
  total: number
  tamanoPagina: number
  onCambiar: (pagina: number) => void
}

function Paginacion({ pagina, totalPaginas, total, tamanoPagina, onCambiar }: Props) {
  if (total === 0) return null
  const desde = (pagina - 1) * tamanoPagina + 1
  const hasta = Math.min(pagina * tamanoPagina, total)

  const paginas: number[] = []
  const inicio = Math.max(1, Math.min(pagina - 2, totalPaginas - 4))
  for (let p = inicio; p <= Math.min(totalPaginas, inicio + 4); p++) paginas.push(p)

  return (
    <nav className="paginacion" aria-label="Paginación">
      <span className="paginacion-resumen">{desde}–{hasta} de {total}</span>
      <div className="paginacion-botones">
        <button type="button" className="btn-pagina" disabled={pagina <= 1} onClick={() => onCambiar(pagina - 1)} aria-label="Página anterior">
          <i className="bi bi-chevron-left" aria-hidden="true" />
        </button>
        {paginas.map((p) => (
          <button key={p} type="button" className={`btn-pagina ${p === pagina ? 'activa' : ''}`}
            aria-current={p === pagina ? 'page' : undefined} onClick={() => onCambiar(p)}>
            {p}
          </button>
        ))}
        <button type="button" className="btn-pagina" disabled={pagina >= totalPaginas} onClick={() => onCambiar(pagina + 1)} aria-label="Página siguiente">
          <i className="bi bi-chevron-right" aria-hidden="true" />
        </button>
      </div>
    </nav>
  )
}

export default Paginacion
