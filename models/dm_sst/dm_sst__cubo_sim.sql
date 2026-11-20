SELECT
    ano,
    preliminar,
    uf_sigla,
    sexo,
    faixa_etaria,
    raca_cor,
    cbo_grande_grupo,
    grupo_causa,
    situacao_acidtrab,
    obitos
FROM {{ ref('gold__cubo_sim') }}
