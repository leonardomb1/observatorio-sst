SELECT
    uf_codigo,
    uf_sigla,
    uf_nome,
    regiao
FROM {{ ref('gold__dim_uf') }}
