SELECT
    pais_iso3,
    ano,
    taxa_fatal_100k,
    fonte
FROM {{ ref('gold__taxa_fatal_paises') }}
