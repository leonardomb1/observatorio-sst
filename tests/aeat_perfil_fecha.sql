-- Falha se, em alguma dimensao do perfil, as categorias nao somarem o total do
-- escopo, se com CAT e sem CAT nao fecharem com o total da categoria, ou se o
-- total nacional divergir da tabela de situacao do registro do mesmo anuario.
-- As planilhas de raca/cor e de instrucao sao lidas direto do XML, por outro
-- caminho que o das demais; esta e a rede contra uma coluna deslocada.
with partes as (
    select ano, escopo, dimensao, max(total_escopo) as total_escopo,
           sum(acidentes) as soma
    from {{ ref('gold__aeat_perfil') }}
    group by ano, escopo, dimensao
),
categorias as (
    select ano, escopo, dimensao, categoria, acidentes, com_cat, sem_cat
    from {{ ref('gold__aeat_perfil') }}
    where abs(coalesce(com_cat, 0) + coalesce(sem_cat, 0) - acidentes) > acidentes * 0.01
),
nacional as (
    select p.ano, p.dimensao, p.total_escopo, r.total
    from partes p
    join {{ ref('gold__aeat_subnotificacao') }} r
      on r.ano = p.ano and r.escopo = 'Brasil' and r.cnae_codigo = 'TOTAL'
    where p.escopo = 'Brasil' and p.total_escopo <> r.total
)
select ano, escopo, dimensao, 'soma' as falha from partes
where abs(soma - total_escopo) > total_escopo * 0.01
union all
select ano, escopo, dimensao, concat('com+sem ', categoria) from categorias
union all
select ano, 'Brasil', dimensao, 'difere do registro' from nacional
