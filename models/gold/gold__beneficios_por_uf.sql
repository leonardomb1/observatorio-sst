SELECT LEFT(periodo,4) AS ano, uf, COUNT(*) AS concessoes FROM {{ source('silver', 'beneficios_acidentarios') }} WHERE acidente_trabalho AND uf IS NOT NULL GROUP BY 1,2
