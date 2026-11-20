{{ config(materialized='table', table_type='DUPLICATE', keys=['ano'], distributed_by=['ano']) }}
-- Obitos por causas externas do SIM no grao dos filtros do site.
--
-- Guarda todas as causas externas, e nao so os obitos de trabalho, com a
-- situacao do campo acidtrab como dimensao: assim o site calcula, para
-- qualquer combinacao de filtros, tanto os obitos de trabalho quanto o
-- preenchimento do campo sobre o qual eles se apoiam. O SIM nao traz a
-- atividade economica. O ultimo ano publicado e preliminar.
WITH ultimo AS (
    SELECT max(ano_arquivo) AS ano FROM {{ ref('silver__sim_causas_externas') }}
)
SELECT
    s.ano,
    s.ano >= u.ano AS preliminar,
    d.uf_sigla,
    s.sexo,
    {{ faixa_etaria('s.idade') }} AS faixa_etaria,
    s.raca_cor,
    {{ cbo_grande_grupo('s.cbo_codigo') }} AS cbo_grande_grupo,
    s.grupo_causa,
    s.situacao_acidtrab,
    COUNT(*) AS obitos
FROM {{ ref('silver__sim_causas_externas') }} s
CROSS JOIN ultimo u
LEFT JOIN {{ ref('gold__dim_uf') }} d ON d.uf_nome = s.uf_ocorrencia
WHERE s.ano IS NOT NULL
GROUP BY s.ano, s.ano >= u.ano, d.uf_sigla, s.sexo, {{ faixa_etaria('s.idade') }}, s.raca_cor,
         {{ cbo_grande_grupo('s.cbo_codigo') }}, s.grupo_causa, s.situacao_acidtrab
