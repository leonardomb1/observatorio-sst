-- Taxa de incidencia por atividade economica, o recorte que responde quais
-- setores sao de fato mais perigosos, e nao apenas quais empregam mais gente.
--
-- A CAT identifica a atividade pela classe CNAE de quatro digitos e a RAIS pela
-- subclasse de sete, entao a subclasse e truncada nos quatro primeiros digitos.
-- A CAT tambem perde o zero a esquerda das atividades agropecuarias, gravadas
-- como numero em algum ponto do caminho; sem o lpad, justamente o setor de
-- maior letalidade cairia da juncao sem produzir erro. Com a correcao, a
-- juncao cobre 99,9% dos acidentes.
WITH limites AS (
    SELECT min(ano) AS primeiro, max(ano) AS ultimo
    FROM {{ source('silver', 'acidentes') }}
    WHERE ano IS NOT NULL
),
vinculos AS (
    SELECT ano,
           left(cnae_subclasse, 4) AS cnae_codigo,
           SUM(vinculos_ativos) AS vinculos_ativos,
           SUM(estabelecimentos) AS estabelecimentos
    FROM {{ source('bronze', 'rais_estoque') }}
    WHERE length(cnae_subclasse) = 7
    GROUP BY ano, left(cnae_subclasse, 4)
),
acidentes AS (
    SELECT ano,
           lpad(cnae_codigo, 4, '0') AS cnae_codigo,
           max(cnae_descricao) AS cnae_descricao,
           SUM(acidentes) AS acidentes,
           SUM(obitos) AS obitos
    FROM {{ ref('gold__acidentes_por_cnae') }}
    WHERE cnae_codigo IS NOT NULL
    GROUP BY ano, lpad(cnae_codigo, 4, '0')
)
SELECT
    v.ano,
    v.cnae_codigo,
    a.cnae_descricao,
    v.vinculos_ativos,
    v.estabelecimentos,
    COALESCE(a.acidentes, 0) AS acidentes,
    COALESCE(a.obitos, 0) AS obitos,
    ROUND(COALESCE(a.acidentes, 0) * 100000.0 / v.vinculos_ativos, 1)
        AS acidentes_por_100mil_vinculos,
    ROUND(COALESCE(a.obitos, 0) * 100000.0 / v.vinculos_ativos, 2)
        AS obitos_por_100mil_vinculos,
    CASE WHEN v.vinculos_ativos >= 5000 THEN true ELSE false END AS base_suficiente,
    CASE WHEN v.ano > l.primeiro AND v.ano < l.ultimo THEN true ELSE false END
        AS ano_completo
FROM vinculos v
CROSS JOIN limites l
LEFT JOIN acidentes a
    ON a.ano = v.ano AND a.cnae_codigo = v.cnae_codigo
WHERE v.vinculos_ativos > 0
