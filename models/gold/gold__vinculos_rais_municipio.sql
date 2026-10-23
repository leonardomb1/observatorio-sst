-- Estoque de vinculos formais por ano e municipio: o denominador de toda taxa
-- de incidencia do observatorio. A RAIS identifica a unidade federativa por
-- codigo numerico, entao o municipio e resolvido pelo dicionario do IBGE, que
-- devolve nome, sigla e regiao ja padronizados. A juncao cobre 99,96% das
-- linhas; o residuo sao codigos de municipio ignorado, que nao tem populacao
-- ocupada a atribuir e por isso ficam de fora do denominador.
--
-- A divisao 84 da CNAE, administracao publica, reune servidores estatutarios
-- que, em regra, nao emitem CAT; deixa-los no denominador dilui a taxa onde o
-- setor publico pesa mais. As colunas sem_* retiram as divisoes listadas em
-- dbt_project.yml, e a subclasse da RAIS tem sete digitos em todos os anos.
SELECT
    CAST(r.ano AS INT) AS ano,
    r.municipio_codigo,
    max(m.nome) AS municipio,
    max(m.uf_sigla) AS uf_sigla,
    max(m.uf_nome) AS uf,
    max(m.regiao) AS regiao,
    SUM(r.vinculos_ativos) AS vinculos_ativos,
    SUM(CASE WHEN {{ na_lista_de_divisoes('left(r.cnae_subclasse, 2)', var('divisoes_adm_publica')) }}
             THEN 0 ELSE r.vinculos_ativos END) AS vinculos_sem_adm_publica,
    SUM(CASE WHEN {{ na_lista_de_divisoes('left(r.cnae_subclasse, 2)', var('divisoes_84_88')) }}
             THEN 0 ELSE r.vinculos_ativos END) AS vinculos_sem_divisoes_84_88,
    SUM(r.estabelecimentos) AS estabelecimentos
FROM {{ source('bronze', 'rais_estoque') }} r
JOIN {{ source('bronze', 'ibge_municipios') }} m
    ON r.municipio_codigo = m.codigo
GROUP BY CAST(r.ano AS INT), r.municipio_codigo
