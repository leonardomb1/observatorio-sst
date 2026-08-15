-- Falha se a juncao da CAT com o dicionario CID-10 do DATASUS cair abaixo de
-- 90% dos registros com codigo informado. A cobertura medida em agosto de 2026
-- era de 96,6%; uma queda indica mudanca de layout ou dicionario desatualizado.
with base as (
    select
        count(*) as total,
        sum(case when cid10_descricao is not null then 1 else 0 end) as resolvidos
    from {{ source('silver', 'acidentes') }}
    where cid10_codigo is not null and cid10_codigo <> ''
)
select total, resolvidos, round(100.0 * resolvidos / total, 1) as cobertura_pct
from base
where resolvidos < total * 0.90
