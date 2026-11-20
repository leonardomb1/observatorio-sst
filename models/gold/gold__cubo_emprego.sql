{{ config(materialized='table', table_type='DUPLICATE', keys=['ano'], distributed_by=['ano']) }}
-- Emprego formal por ano, UF e secao de atividade: estoque da RAIS em 31 de
-- dezembro e fluxos do CAGED no ano.
--
-- E o denominador das taxas quando o leitor filtra por UF ou atividade, e a
-- base da rotatividade filtrada. A RAIS publica nao traz sexo, idade, raca nem
-- ocupacao do vinculo, entao taxas com esses filtros nao existem: o site mostra
-- contagens nesses casos. Ano e chave sao agrupados como texto, porque agrupar
-- por CAST de coluna-chave devolve chaves erradas no StarRocks.
WITH rais AS (
    SELECT
        CAST(ano AS VARCHAR) AS ano_txt,
        uf AS uf_codigo,
        {{ cnae_secao_da_divisao("left(lpad(cnae_subclasse, 7, '0'), 2)") }} AS cnae_secao,
        SUM(vinculos_ativos) AS vinculos_ativos
    FROM {{ source('bronze', 'rais_estoque') }}
    WHERE length(cnae_subclasse) IN (6, 7)
    GROUP BY CAST(ano AS VARCHAR), uf,
             {{ cnae_secao_da_divisao("left(lpad(cnae_subclasse, 7, '0'), 2)") }}
),
caged AS (
    SELECT
        left(competencia, 4) AS ano_txt,
        uf AS uf_codigo,
        {{ cnae_secao_da_divisao("left(lpad(cnae_subclasse, 7, '0'), 2)") }} AS cnae_secao,
        SUM(admissoes) AS admissoes,
        SUM(desligamentos) AS desligamentos,
        COUNT(DISTINCT right(competencia, 2)) AS meses
    FROM {{ source('bronze', 'caged_saldo') }}
    WHERE length(cnae_subclasse) IN (6, 7)
    GROUP BY left(competencia, 4), uf,
             {{ cnae_secao_da_divisao("left(lpad(cnae_subclasse, 7, '0'), 2)") }}
)
SELECT
    CAST(r.ano_txt AS INT) AS ano,
    u.uf_sigla,
    r.cnae_secao,
    r.vinculos_ativos,
    c.admissoes,
    c.desligamentos,
    c.meses AS meses_caged
FROM rais r
JOIN {{ ref('gold__dim_uf') }} u ON u.uf_codigo = r.uf_codigo
LEFT JOIN caged c
    ON c.ano_txt = r.ano_txt AND c.uf_codigo = r.uf_codigo AND c.cnae_secao <=> r.cnae_secao
