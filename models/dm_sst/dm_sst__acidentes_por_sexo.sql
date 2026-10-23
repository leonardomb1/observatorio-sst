SELECT
    ano,
    sexo,
    acidentes,
    obitos,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_sexo') }}
