SELECT
    agravo,
    agravo_nome,
    ano,
    preliminar,
    situacao_trabalho,
    vinculo,
    notificacoes,
    com_cat,
    pct_com_cat,
    obitos
FROM {{ ref('gold__sinan_situacao_trabalho') }}
