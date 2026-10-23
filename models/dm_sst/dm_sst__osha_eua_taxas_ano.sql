SELECT
    ano,
    mortes,
    casos_registraveis,
    horas_trabalhadas,
    trir,
    dart
FROM {{ ref('gold__osha_eua_taxas_ano') }}
