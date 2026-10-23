SELECT
    ano,
    mes,
    dias_medio_ate_emissao,
    dias_mediana_ate_emissao,
    pct_apos_1_dia,
    registros,
    pct_emissao_confiavel,
    ano_status,
    ano_completo
FROM {{ ref('gold__tempestividade_cat') }}
