-- Taxa de obitos por divisao de atividade: Brasil frente a Uniao Europeia.
--
-- Do lado brasileiro, obitos com CAT sobre vinculos ativos da RAIS, somados
-- das classes para a divisao CNAE; do europeu, a taxa padronizada do ESAW para
-- a UE-27 na mesma divisao NACE. Os dois lados medem coisas proximas, nao
-- iguais: o Brasil conta so o emprego formal e so o obito comunicado por CAT,
-- e por isso a sua taxa e um piso. Entram apenas os anos brasileiros
-- consolidados, porque nos parciais a lacuna de publicacao da CAT simularia
-- uma queda de risco.
WITH brasil AS (
    SELECT ano, left(cnae_codigo, 2) AS divisao,
           SUM(obitos) AS obitos, SUM(acidentes) AS acidentes,
           SUM(vinculos_ativos) AS vinculos_ativos
    FROM {{ ref('gold__taxa_incidencia_cnae') }}
    WHERE ano_completo
    GROUP BY ano, left(cnae_codigo, 2)
),
nomes AS (
    SELECT left(codigo, 2) AS divisao, max(divisao) AS nome
    FROM {{ source('bronze', 'cnae_classes') }}
    GROUP BY left(codigo, 2)
),
europa AS (
    SELECT ano, divisao, nace_r2, acidentes AS obitos,
           taxa_por_100mil_ocupados, flag
    FROM {{ ref('gold__esaw_setor') }}
    WHERE gravidade = 'fatal' AND geo = 'EU27_2020' AND nivel = 'divisao'
)
SELECT
    b.ano,
    b.divisao,
    e.nace_r2,
    concat(upper(left(n.nome, 1)), {{ minusculas('substr(n.nome, 2)') }}) AS divisao_nome,
    b.vinculos_ativos,
    b.obitos AS obitos_brasil,
    ROUND(b.obitos * 100000.0 / nullif(b.vinculos_ativos, 0), 2) AS obitos_por_100mil_brasil,
    e.obitos AS obitos_ue27,
    e.taxa_por_100mil_ocupados AS obitos_por_100mil_ue27,
    ROUND(b.obitos * 100000.0 / nullif(b.vinculos_ativos, 0)
          / nullif(e.taxa_por_100mil_ocupados, 0), 1) AS razao_brasil_ue27,
    b.vinculos_ativos >= {{ var('base_minima_vinculos')['cnae'] }} AS base_suficiente,
    e.flag AS flag_ue27
FROM brasil b
JOIN europa e ON e.ano = b.ano AND e.divisao = b.divisao
LEFT JOIN nomes n ON n.divisao = b.divisao
