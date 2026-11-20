SELECT
    grande_grupo,
    nome
FROM {{ ref('cbo_grande_grupo') }}
