SELECT
    ano,
    cnae_codigo,
    cnae_descricao,
    vinculos_ativos,
    admissoes,
    desligamentos,
    rotatividade_pct,
    acidentes,
    obitos,
    acidentes_por_100mil_vinculos,
    obitos_por_100mil_vinculos,
    base_suficiente,
    ano_status,
    ano_completo
FROM {{ ref('gold__rotatividade_cnae') }}
