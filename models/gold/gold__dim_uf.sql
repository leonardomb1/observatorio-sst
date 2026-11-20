-- Unidades federativas com os tres jeitos em que as fontes as escrevem.
--
-- A CAT e o INSS trazem o nome, o SIM e o SINAN o codigo do municipio, a RAIS
-- e o CAGED o codigo IBGE de dois digitos, a PRF a sigla. O site filtra pela
-- sigla, e todo cubo passa por esta tabela para chegar nela.
SELECT DISTINCT
    left(codigo, 2) AS uf_codigo,
    uf_sigla,
    uf_nome,
    regiao
FROM {{ source('bronze', 'ibge_municipios') }}
WHERE uf_sigla IS NOT NULL
