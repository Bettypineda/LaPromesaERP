// Logotipo de La Promesa (marca de texto + isotipo)
function Marca({ compacta = false, clara = true }: { compacta?: boolean; clara?: boolean }) {
  return (
    <span className={`marca ${clara ? 'marca-clara' : 'marca-oscura'} ${compacta ? 'marca-compacta' : ''}`}>
      <svg className="marca-icono" viewBox="0 0 64 64" aria-hidden="true">
        <rect width="64" height="64" rx="14" className="marca-fondo" />
        <path d="M18 46V18h14a10 10 0 0 1 0 20h-6" fill="none" stroke="#E3A72F" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round" />
        <circle cx="44" cy="46" r="4" fill="#E3A72F" />
      </svg>
      <span className="marca-texto">
        <strong>La Promesa</strong>
        {!compacta && <small>Proveedores y compras</small>}
      </span>
    </span>
  )
}

export default Marca
