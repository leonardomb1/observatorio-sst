SELECT
    ano,
    divisao,
    nace_r2,
    divisao_nome,
    vinculos_ativos,
    obitos_brasil,
    obitos_por_100mil_brasil,
    obitos_ue27,
    obitos_por_100mil_ue27,
    razao_brasil_ue27,
    base_suficiente,
    flag_ue27
FROM {{ ref('gold__comparacao_setorial_europa') }}
