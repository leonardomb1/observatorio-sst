SELECT
    secao,
    nome
FROM {{ ref('cnae_secao') }}
