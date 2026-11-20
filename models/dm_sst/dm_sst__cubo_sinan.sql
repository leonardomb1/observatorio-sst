SELECT
    agravo,
    agravo_nome,
    ano,
    preliminar,
    uf_sigla,
    sexo,
    faixa_etaria,
    raca_cor,
    cbo_grande_grupo,
    situacao_trabalho,
    vinculo,
    notificacoes,
    com_cat,
    cat_informada,
    obitos
FROM {{ ref('gold__cubo_sinan') }}
