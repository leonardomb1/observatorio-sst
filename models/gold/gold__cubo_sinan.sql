{{ config(materialized='table', table_type='DUPLICATE', keys=['agravo', 'ano'], distributed_by=['agravo']) }}
-- Notificacoes de agravos de saude do trabalhador no grao dos filtros do site.
--
-- O SINAN traz UF, sexo, idade, raca/cor, ocupacao e a situacao no mercado de
-- trabalho, mas a atividade vem majoritariamente na CNAE 1.0, cujas divisoes
-- nao equivalem as da CNAE 2.0; por isso o cubo nao tem secao de atividade e
-- o site avisa que esse filtro nao se aplica. cat_informada separa o campo
-- preenchido, denominador da parcela com CAT.
SELECT
    s.agravo,
    s.agravo_nome,
    s.ano,
    s.preliminar,
    u.uf_sigla,
    s.sexo,
    {{ faixa_etaria('s.idade') }} AS faixa_etaria,
    s.raca_cor,
    {{ cbo_grande_grupo('s.cbo_codigo') }} AS cbo_grande_grupo,
    s.situacao_trabalho,
    s.vinculo,
    COUNT(*) AS notificacoes,
    SUM(CASE WHEN s.cat_emitida THEN 1 ELSE 0 END) AS com_cat,
    SUM(CASE WHEN s.cat_emitida IS NOT NULL THEN 1 ELSE 0 END) AS cat_informada,
    SUM(CASE WHEN s.obito_trabalho THEN 1 ELSE 0 END) AS obitos
FROM {{ ref('silver__sinan_trabalho') }} s
LEFT JOIN {{ ref('gold__dim_uf') }} u ON u.uf_nome = s.uf
GROUP BY s.agravo, s.agravo_nome, s.ano, s.preliminar, u.uf_sigla, s.sexo,
         {{ faixa_etaria('s.idade') }}, s.raca_cor, {{ cbo_grande_grupo('s.cbo_codigo') }},
         s.situacao_trabalho, s.vinculo
