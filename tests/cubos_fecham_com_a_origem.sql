-- Falha se algum cubo de filtro perder ou duplicar registros em relacao a sua
-- origem, ou se alguma linha ficar sem UF quando a origem tinha UF. Os cubos
-- passam por juncoes de dimensao (UF por nome, por codigo ou por sigla); uma
-- grafia que nao casa faria os filtros mostrarem menos do que existe, sem erro.
with checks as (
    select 'acidentes' as cubo,
           (select sum(acidentes) from {{ ref('gold__cubo_acidentes') }}) as no_cubo,
           (select count(*) from {{ ref('silver__acidentes') }} where ano is not null) as na_origem
    union all
    select 'incapacidade',
           (select sum(concessoes) from {{ ref('gold__cubo_incapacidade') }}),
           (select sum(concessoes) from {{ ref('silver__inss_incapacidade') }} where natureza is not null)
    union all
    select 'sinan',
           (select sum(notificacoes) from {{ ref('gold__cubo_sinan') }}),
           (select count(*) from {{ ref('silver__sinan_trabalho') }})
    union all
    select 'sim',
           (select sum(obitos) from {{ ref('gold__cubo_sim') }}),
           (select count(*) from {{ ref('silver__sim_causas_externas') }} where ano is not null)
    union all
    select 'prf',
           (select sum(envolvidos) from {{ ref('gold__cubo_prf') }}),
           (select count(*) from {{ ref('silver__prf_envolvidos') }})
    union all
    select 'acidentes sem uf',
           (select coalesce(sum(acidentes), 0) from {{ ref('gold__cubo_acidentes') }} where uf_sigla is null),
           (select count(*) from {{ ref('silver__acidentes') }} where ano is not null and uf_empregador is null)
    union all
    select 'incapacidade sem uf',
           (select coalesce(sum(concessoes), 0) from {{ ref('gold__cubo_incapacidade') }} where uf_sigla is null),
           (select coalesce(sum(concessoes), 0) from {{ ref('silver__inss_incapacidade') }}
            where natureza is not null and uf is null)
)
select cubo, no_cubo, na_origem
from checks
where no_cubo <> na_origem
