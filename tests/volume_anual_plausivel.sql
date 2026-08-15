-- Falha se algum ano completo sair da faixa historica conhecida, entre 300 mil
-- e 800 mil acidentes. Serve de rede contra carga parcial ou duplicada: um ano
-- com metade do volume normal costuma significar backfill interrompido.
select ano, sum(acidentes) as acidentes
from {{ ref('gold__acidentes_mensal_uf') }}
where ano < (select max(ano) from {{ ref('gold__acidentes_mensal_uf') }})
  and ano > (select min(ano) from {{ ref('gold__acidentes_mensal_uf') }})
group by ano
having sum(acidentes) < 300000 or sum(acidentes) > 800000
