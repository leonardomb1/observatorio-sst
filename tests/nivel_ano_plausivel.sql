{{ config(severity='warn') }}
-- Avisa quando o nivel de um ano consolidado fica fora de 0,6 a 1,6 vez o do
-- ano consolidado anterior. O status do ano mede completude dentro do ano, e
-- um ano inteiro com metade do volume ainda sairia consolidado; este teste e o
-- ponto cego coberto.
with niveis as (
    select c.ano, max(c.nivel_ano) as nivel_ano
    from {{ ref('gold__cobertura_cat_mensal') }} c
    join {{ ref('gold__status_ano') }} s on s.ano = c.ano and s.ano_status = 'consolidado'
    group by c.ano
),
pares as (
    select ano, nivel_ano, lag(nivel_ano) over (order by ano) as nivel_anterior
    from niveis
)
select ano, nivel_ano, nivel_anterior
from pares
where nivel_anterior is not null
  and (nivel_ano < nivel_anterior * 0.6 or nivel_ano > nivel_anterior * 1.6)
