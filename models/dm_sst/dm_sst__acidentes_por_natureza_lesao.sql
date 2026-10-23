SELECT
    ano,
    familia,
    detalhe,
    natureza_lesao,
    acidentes,
    obitos,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_natureza_lesao') }}
