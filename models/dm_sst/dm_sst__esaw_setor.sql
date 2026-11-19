SELECT
    ano,
    gravidade,
    geo,
    nace_r2,
    nivel,
    divisao,
    acidentes,
    taxa_por_100mil_ocupados,
    flag
FROM {{ ref('gold__esaw_setor') }}
