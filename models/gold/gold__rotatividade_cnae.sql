-- Rotatividade do emprego formal por atividade, ao lado da acidentalidade.
--
-- A rotatividade segue a definicao usual do DIEESE: o menor entre admissoes e
-- desligamentos do ano, que mede a substituicao de trabalhadores e nao o
-- crescimento do emprego, dividido pelo estoque de vinculos da RAIS em 31 de
-- dezembro. Atividades de alta rotatividade concentram trabalhadores recem
-- admitidos, e a literatura associa o tempo curto na funcao a maior risco de
-- acidente; a coluna de acidentes por 100 mil vinculos permite olhar essa
-- relacao, nao a demonstra.
--
-- O CAGED carregado e so o arquivo de movimentacoes do mes, sem as
-- declaracoes fora do prazo e exclusoes, o que subestima levemente os fluxos.
-- So entram anos com doze meses de CAGED. Como na CAT, as subclasses das
-- secoes A e B chegam sem o zero a esquerda e sao completadas com lpad; e o
-- ano e agrupado como texto, porque agrupar pelo CAST com contagem distinta
-- devolve zero no StarRocks.
WITH caged AS (
    SELECT left(competencia, 4) AS ano_txt,
           left(lpad(cnae_subclasse, 7, '0'), 4) AS cnae_codigo,
           SUM(admissoes) AS admissoes,
           SUM(desligamentos) AS desligamentos
    FROM {{ source('bronze', 'caged_saldo') }}
    WHERE length(cnae_subclasse) IN (6, 7)
    GROUP BY left(competencia, 4), left(lpad(cnae_subclasse, 7, '0'), 4)
),
meses_no_ano AS (
    SELECT left(competencia, 4) AS ano_txt,
           COUNT(DISTINCT right(competencia, 2)) AS meses
    FROM {{ source('bronze', 'caged_saldo') }}
    GROUP BY left(competencia, 4)
)
SELECT
    t.ano,
    t.cnae_codigo,
    t.cnae_descricao,
    t.vinculos_ativos,
    c.admissoes,
    c.desligamentos,
    ROUND(least(c.admissoes, c.desligamentos) * 100.0 / t.vinculos_ativos, 1)
        AS rotatividade_pct,
    t.acidentes,
    t.obitos,
    t.acidentes_por_100mil_vinculos,
    t.obitos_por_100mil_vinculos,
    t.base_suficiente,
    t.ano_status,
    t.ano_completo
FROM {{ ref('gold__taxa_incidencia_cnae') }} t
JOIN meses_no_ano m ON CAST(m.ano_txt AS INT) = t.ano AND m.meses = 12
JOIN caged c ON CAST(c.ano_txt AS INT) = t.ano AND c.cnae_codigo = t.cnae_codigo
