SELECT
    ano,
    hora,
    dia_semana,
    fase_dia,
    condutores,
    obitos,
    obitos_por_mil_condutores
FROM {{ ref('gold__prf_caminhoneiros_horario') }}
