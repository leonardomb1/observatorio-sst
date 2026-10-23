SELECT
    ano,
    cnae_codigo,
    cnae_descricao,
    vinculos_ativos,
    estabelecimentos,
    acidentes,
    obitos,
    acidentes_por_100mil_vinculos,
    obitos_por_100mil_vinculos,
    acidentes_evento,
    obitos_evento,
    base_minima,
    base_suficiente,
    ano_status,
    ano_completo
FROM {{ ref('gold__taxa_incidencia_cnae') }}
