-- Taxa de incidencia por unidade federativa, agregada a partir do municipio.
--
-- A agregacao parte do municipio, e nao da UF declarada na CAT, por dois
-- motivos: o campo de UF do acidente esta com rotulos trocados na origem, e
-- somar municipios garante que numerador e denominador cubram exatamente o
-- mesmo conjunto de localidades. O custo e desprezar os acidentes cujo codigo
-- de municipio nao existe no dicionario do IBGE, menos de 0,1% do total.
SELECT
    ano,
    ano_completo,
    uf,
    uf_sigla,
    regiao,
    SUM(vinculos_ativos) AS vinculos_ativos,
    SUM(estabelecimentos) AS estabelecimentos,
    SUM(acidentes) AS acidentes,
    SUM(obitos) AS obitos,
    ROUND(SUM(acidentes) * 100000.0 / SUM(vinculos_ativos), 1)
        AS acidentes_por_100mil_vinculos,
    ROUND(SUM(obitos) * 100000.0 / SUM(vinculos_ativos), 2)
        AS obitos_por_100mil_vinculos
FROM {{ ref('gold__taxa_incidencia_municipio') }}
GROUP BY ano, uf, uf_sigla, regiao, ano_completo
