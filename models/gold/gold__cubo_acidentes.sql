{{ config(materialized='table', table_type='DUPLICATE', keys=['ano'], distributed_by=['ano']) }}
-- Acidentes com CAT no grao de todos os filtros do site.
--
-- Uma linha por combinacao de ano, UF do empregador, sexo, faixa etaria,
-- secao de atividade, grande grupo de ocupacao e tipo de acidente. O site soma
-- as linhas que passam pelos filtros escolhidos, de modo que qualquer
-- combinacao de filtros da o mesmo numero que a soma das partes. A CAT nao
-- traz raca/cor. ano_status vem do controle de cobertura: os anos parciais
-- continuam no cubo e sao marcados, nunca somados em silencio aos fechados.
WITH base AS (
    SELECT
        a.ano,
        u.uf_sigla,
        a.sexo,
        {{ faixa_etaria('a.idade') }} AS faixa_etaria,
        {{ cnae_secao_da_divisao("left(lpad(a.cnae_codigo, 4, '0'), 2)") }} AS cnae_secao,
        {{ cbo_grande_grupo('a.cbo_codigo') }} AS cbo_grande_grupo,
        a.tipo_acidente,
        a.obito
    FROM {{ ref('silver__acidentes') }} a
    LEFT JOIN {{ ref('gold__dim_uf') }} u ON u.uf_nome = a.uf_empregador
    WHERE a.ano IS NOT NULL
)
SELECT
    b.ano,
    s.ano_status,
    coalesce(s.ano_completo, false) AS ano_completo,
    b.uf_sigla,
    b.sexo,
    b.faixa_etaria,
    b.cnae_secao,
    b.cbo_grande_grupo,
    b.tipo_acidente,
    COUNT(*) AS acidentes,
    SUM(CASE WHEN b.obito THEN 1 ELSE 0 END) AS obitos
FROM base b
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = b.ano
GROUP BY b.ano, s.ano_status, s.ano_completo, b.uf_sigla, b.sexo, b.faixa_etaria,
         b.cnae_secao, b.cbo_grande_grupo, b.tipo_acidente
