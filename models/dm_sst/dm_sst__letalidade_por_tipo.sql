SELECT
    tipo_acidente,
    acidentes,
    obitos,
    obitos_por_100mil_acidentes,
    anos_incluidos
FROM {{ ref('gold__letalidade_por_tipo') }}
