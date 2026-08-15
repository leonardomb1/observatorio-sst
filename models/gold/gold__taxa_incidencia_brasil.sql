-- Serie anual do Brasil: acidentes e obitos por 100 mil vinculos formais.
--
-- Esta e a unica metrica do observatorio diretamente comparavel com a base da
-- OIT, cujo indicador 8.8.1 tambem se expressa por 100 mil trabalhadores. A
-- OIT nao publica taxa de acidentes fatais do Brasil desde 2011, entao a serie
-- calculada aqui preenche a lacuna a partir dos microdados nacionais.
--
-- A comparacao com outros paises exige duas ressalvas, que devem acompanhar
-- qualquer uso do numero. A cobertura e do emprego formal: trabalhador
-- informal, autonomo e servidor estatutario sem CAT ficam de fora dos dois
-- lados da divisao. E o registro depende da emissao da CAT, o que subestima o
-- numerador em grau desconhecido, tema tratado nas limitacoes metodologicas.
SELECT
    ano,
    ano_completo,
    SUM(vinculos_ativos) AS vinculos_ativos,
    SUM(estabelecimentos) AS estabelecimentos,
    SUM(acidentes) AS acidentes,
    SUM(obitos) AS obitos,
    ROUND(SUM(acidentes) * 100000.0 / SUM(vinculos_ativos), 1)
        AS acidentes_por_100mil_vinculos,
    ROUND(SUM(obitos) * 100000.0 / SUM(vinculos_ativos), 2)
        AS obitos_por_100mil_vinculos
FROM {{ ref('gold__taxa_incidencia_municipio') }}
GROUP BY ano, ano_completo
