SELECT
    ano,
    mortes,
    casos_registraveis,
    horas_trabalhadas,
    trir,
    dart,
    estabelecimentos,
    estabelecimentos_excluidos
FROM {{ ref('gold__osha_eua_taxas_ano') }}
