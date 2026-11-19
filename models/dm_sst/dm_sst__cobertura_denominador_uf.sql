SELECT
    ano,
    uf,
    ocupados_mil,
    informais_mil,
    taxa_informalidade_pct,
    vinculos_ativos,
    vinculos_por_100_ocupados,
    precisao_baixa
FROM {{ ref('gold__cobertura_denominador_uf') }}
