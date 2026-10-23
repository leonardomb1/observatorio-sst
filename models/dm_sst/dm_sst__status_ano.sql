SELECT
    ano,
    cats,
    meses_lacuna,
    meses_baixos,
    ano_status,
    ano_completo,
    aeat_com_cat,
    cobertura_aeat_pct
FROM {{ ref('gold__status_ano') }}
