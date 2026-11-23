-- Contagens desta visao sao alocadas: so entram as CAT cuja classe CNAE casa com o estoque
-- da RAIS, numerador das taxas. O total de CAT do ano esta em status_ano e nas visoes acidentes_*;
-- por isso as colunas se chamam *_alocados, para nao serem lidas como total.
SELECT
    ano,
    cnae_codigo,
    cnae_descricao,
    vinculos_ativos,
    estabelecimentos,
    acidentes AS acidentes_alocados,
    obitos AS obitos_alocados,
    acidentes_por_100mil_vinculos,
    obitos_por_100mil_vinculos,
    acidentes_evento,
    obitos_evento,
    base_minima,
    base_suficiente,
    ano_status,
    ano_completo
FROM {{ ref('gold__taxa_incidencia_cnae') }}
