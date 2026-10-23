SELECT
    cid10_codigo,
    diagnostico,
    concessoes
FROM {{ ref('gold__beneficios_por_diagnostico') }}
