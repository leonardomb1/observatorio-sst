-- Falha se a taxa de informalidade publicada divergir da razao entre informais
-- e ocupados em mais de um ponto, ou se a soma das UFs se afastar do total do
-- pais em mais de 1%. O carregador transpoe a tabela do SIDRA por codigo de
-- variavel; uma troca de codigo produziria numeros plausiveis e errados.
with taxa as (
    select trimestre, territorio, sexo, 'taxa' as falha
    from {{ ref('gold__pnad_informalidade') }}
    where informais_mil is not null and ocupados_mil > 0
      and abs(informais_mil * 100.0 / ocupados_mil - taxa_informalidade_pct) > 1
),
soma as (
    select trimestre, sexo,
           sum(case when nivel = 'uf' then ocupados_mil end) as soma_ufs,
           max(case when nivel = 'pais' then ocupados_mil end) as pais
    from {{ ref('gold__pnad_informalidade') }}
    group by trimestre, sexo
)
select trimestre, territorio, sexo, falha from taxa
union all
select trimestre, 'Brasil', sexo, 'soma das UFs' from soma
where abs(soma_ufs - pais) > pais * 0.01
