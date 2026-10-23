SELECT
    ano,
    familia,
    detalhe,
    parte_corpo,
    acidentes,
    obitos,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_parte_corpo') }}
