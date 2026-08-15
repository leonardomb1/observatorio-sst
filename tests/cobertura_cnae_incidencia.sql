-- Falha se menos de 95% dos acidentes com CNAE informado encontrarem par no
-- estoque da RAIS. A juncao depende de dois ajustes fragilmente acoplados a
-- origem, o truncamento da subclasse e o zero a esquerda; se qualquer um deles
-- deixar de valer, o setor afetado sai da analise sem produzir erro.
with pareado as (
    select
        sum(acidentes) as com_denominador,
        (select sum(acidentes) from {{ ref('gold__acidentes_por_cnae') }}
          where cnae_codigo is not null
            and ano in (select distinct ano from {{ ref('gold__taxa_incidencia_cnae') }})
        ) as total
    from {{ ref('gold__taxa_incidencia_cnae') }}
)
select com_denominador, total, round(100.0 * com_denominador / total, 1) as cobertura_pct
from pareado
where com_denominador < total * 0.95
