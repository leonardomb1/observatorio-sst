{{ config(severity='warn') }}
-- Avisa sobre mes ausente ou em lacuna que nao esteja documentado em
-- seeds/cat_arquivos_conhecidos.csv. Lacuna conhecida da origem fica listada
-- la; lacuna nova pode ser carga que falhou sem erro.
select c.ano, c.mes, c.status_mes, c.razao_esperado
from {{ ref('gold__cobertura_cat_mensal') }} c
left join {{ ref('cat_arquivos_conhecidos') }} k
    on k.periodo = concat(c.ano, lpad(c.mes, 2, '0'))
where c.status_mes in ('ausente', 'lacuna')
  and k.periodo is null
