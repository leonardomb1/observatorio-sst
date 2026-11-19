-- Falha se algum ano do SIM, exceto o preliminar, tiver menos de 120 mil ou
-- mais de 200 mil obitos por causas externas. O pais registra perto de 150 mil
-- por ano; fora da faixa, o mais provavel e um arquivo truncado na carga ou
-- um ano carregado duas vezes.
with por_ano as (
    select ano_arquivo, count(*) as obitos
    from {{ ref('silver__sim_causas_externas') }}
    group by ano_arquivo
)
select ano_arquivo, obitos
from por_ano
where ano_arquivo < (select max(ano_arquivo) from por_ano)
  and obitos not between 120000 and 200000
