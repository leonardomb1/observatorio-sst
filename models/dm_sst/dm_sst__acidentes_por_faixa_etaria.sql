SELECT
    ano,
    faixa_etaria,
    ordem,
    acidentes,
    obitos,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_faixa_etaria') }}
