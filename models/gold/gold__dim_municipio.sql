-- Municipios pelo codigo IBGE de seis digitos, o que a CAT, a RAIS e as
-- malhas do site usam, com o nome e a UF para os filtros e mapas.
SELECT DISTINCT
    codigo AS municipio_codigo,
    nome AS municipio,
    uf_sigla
FROM {{ source('bronze', 'ibge_municipios') }}
WHERE codigo IS NOT NULL
