-- Falha se a rotatividade geral de algum ano sair da faixa de 20% a 70%, ou se
-- a agropecuaria (divisoes 01 a 03) sumir da juncao. A rotatividade do emprego
-- formal brasileiro fica em torno de 40% ao ano; fora da faixa, o mais
-- provavel e um mes de CAGED duplicado ou ausente. A agropecuaria e a que
-- perde o zero a esquerda da subclasse, e sem o lpad sairia sem erro.
with geral as (
    select ano,
           sum(least(admissoes, desligamentos)) * 100.0 / sum(vinculos_ativos) as rot,
           sum(case when cnae_codigo < '0400' then 1 else 0 end) as classes_agro
    from {{ ref('gold__rotatividade_cnae') }}
    group by ano
)
select ano, rot, classes_agro
from geral
where rot not between 20 and 70 or classes_agro = 0
