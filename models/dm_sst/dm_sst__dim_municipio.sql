SELECT
    municipio_codigo,
    municipio,
    uf_sigla
FROM {{ ref('gold__dim_municipio') }}
