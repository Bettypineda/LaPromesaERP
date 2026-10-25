interface Props {
  campo: string
  texto: string
  ordenarPor: string
  direccion: 'ASC' | 'DESC'
  onOrdenar: (campo: string) => void
  numero?: boolean
}

// Encabezado de columna que ordena el listado en el servidor
function EncabezadoOrdenable({ campo, texto, ordenarPor, direccion, onOrdenar, numero }: Props) {
  const activo = ordenarPor === campo
  return (
    <th className={numero ? 'numero' : undefined} aria-sort={activo ? (direccion === 'ASC' ? 'ascending' : 'descending') : 'none'}>
      <button type="button" className={`th-orden ${activo ? 'activo' : ''}`} onClick={() => onOrdenar(campo)}>
        {texto}
        <i className={`bi ${activo ? (direccion === 'ASC' ? 'bi-caret-up-fill' : 'bi-caret-down-fill') : 'bi-chevron-expand'}`} aria-hidden="true" />
      </button>
    </th>
  )
}

export default EncabezadoOrdenable
