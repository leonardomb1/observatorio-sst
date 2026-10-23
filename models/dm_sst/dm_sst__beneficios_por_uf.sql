SELECT
    ano,
    uf,
    concessoes
FROM {{ ref('gold__beneficios_por_uf') }}
