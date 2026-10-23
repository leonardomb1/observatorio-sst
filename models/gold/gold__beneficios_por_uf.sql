-- uf e a UF do beneficio (residencia ou agencia do INSS), nao a do empregador.
SELECT CAST(LEFT(periodo, 4) AS INT) AS ano, uf, COUNT(*) AS concessoes
FROM {{ ref('silver__beneficios_acidentarios') }}
WHERE acidente_trabalho AND uf IS NOT NULL
GROUP BY 1, 2
