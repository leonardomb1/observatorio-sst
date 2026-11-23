-- Contagens desta visao sao alocadas: so entram as CAT cujo municipio do empregador casa com o estoque
-- da RAIS, numerador das taxas. O total de CAT do ano esta em status_ano e nas visoes acidentes_*;
-- por isso as colunas se chamam *_alocados, para nao serem lidas como total.
SELECT
    ano,
    ano_status,
    ano_completo,
    vinculos_ativos,
    vinculos_sem_adm_publica,
    vinculos_sem_divisoes_84_88,
    estabelecimentos,
    acidentes AS acidentes_alocados,
    obitos AS obitos_alocados,
    acidentes_sem_adm_publica,
    obitos_sem_adm_publica,
    acidentes_sem_divisoes_84_88,
    obitos_sem_divisoes_84_88,
    acidentes_sem_cnae,
    acidentes_evento,
    obitos_evento,
    acidentes_covid,
    obitos_covid,
    acidentes_por_100mil_vinculos,
    obitos_por_100mil_vinculos,
    acidentes_por_100mil_vinculos_sem_adm_publica,
    obitos_por_100mil_vinculos_sem_adm_publica,
    acidentes_por_100mil_vinculos_sem_divisoes_84_88,
    obitos_por_100mil_vinculos_sem_divisoes_84_88,
    cat_total,
    cat_alocadas,
    cat_descartadas,
    pct_nao_alocavel
FROM {{ ref('gold__taxa_incidencia_brasil') }}
