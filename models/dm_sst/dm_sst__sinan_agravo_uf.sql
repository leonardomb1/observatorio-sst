SELECT
    agravo,
    agravo_nome,
    ano,
    preliminar,
    uf,
    notificacoes,
    informais,
    formais,
    pct_informal,
    com_cat,
    pct_com_cat,
    obitos
FROM {{ ref('gold__sinan_agravo_uf') }}
