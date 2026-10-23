SELECT
    ano,
    familia,
    detalhe,
    agente_causador,
    acidentes,
    obitos,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_agente') }}
