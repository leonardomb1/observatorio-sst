SELECT
    ano,
    grupo_cid,
    cid10_categoria,
    cid10_descricao,
    concessoes,
    acidentarias,
    pct_acidentaria,
    ano_completo,
    cid_confiavel
FROM {{ ref('gold__incapacidade_cid') }}
