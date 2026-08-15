-- Estoque de vinculos formais por ano e municipio: o denominador de toda taxa
-- de incidencia do observatorio. A RAIS identifica a unidade federativa por
-- codigo numerico, entao o municipio e resolvido pelo dicionario do IBGE, que
-- devolve nome, sigla e regiao ja padronizados. A juncao cobre 99,96% das
-- linhas; o residuo sao codigos de municipio ignorado, que nao tem populacao
-- ocupada a atribuir e por isso ficam de fora do denominador.
SELECT
    r.ano,
    r.municipio_codigo,
    max(m.nome) AS municipio,
    max(m.uf_sigla) AS uf_sigla,
    max(m.uf_nome) AS uf,
    max(m.regiao) AS regiao,
    SUM(r.vinculos_ativos) AS vinculos_ativos,
    SUM(r.estabelecimentos) AS estabelecimentos
FROM {{ source('bronze', 'rais_estoque') }} r
JOIN {{ source('bronze', 'ibge_municipios') }} m
    ON r.municipio_codigo = m.codigo
GROUP BY r.ano, r.municipio_codigo
