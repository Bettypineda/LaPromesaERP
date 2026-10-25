// Barra proporcional: entregas a tiempo, anticipadas y con retraso
function BarraCumplimiento({ aTiempo, anticipada, retraso }: { aTiempo: number; anticipada: number; retraso: number }) {
  const total = aTiempo + anticipada + retraso
  if (total === 0) return null
  const partes = [
    { clase: 'ok', texto: 'A tiempo', valor: aTiempo },
    { clase: 'info', texto: 'Anticipadas', valor: anticipada },
    { clase: 'error', texto: 'Con retraso', valor: retraso },
  ]
  return (
    <div className="cumplimiento">
      <div className="cumplimiento-barra" role="img"
        aria-label={partes.map((p) => `${p.texto}: ${p.valor}`).join(', ')}>
        {partes.filter((p) => p.valor > 0).map((p) => (
          <span key={p.clase} className={`cumplimiento-${p.clase}`} style={{ width: `${(p.valor / total) * 100}%` }} />
        ))}
      </div>
      <ul className="cumplimiento-leyenda">
        {partes.map((p) => (
          <li key={p.clase}><span className={`punto cumplimiento-${p.clase}`} />{p.texto}<strong>{p.valor}</strong></li>
        ))}
      </ul>
      <p className="texto-suave small m-0">{total} recepción(es) registradas</p>
    </div>
  )
}

export default BarraCumplimiento
