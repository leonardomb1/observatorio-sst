-- Empregadores e trabalhadores do Cadastro de Empregadores (trabalho analogo
-- a escravidao), na edicao mais recente, por UF, ano da acao fiscal e
-- atividade.
--
-- O cadastro e semestral e cada empregador permanece nele por dois anos; a
-- edicao mais recente e o retrato vigente, e o historico de edicoes esta em
-- gold__trabalho_escravo_edicoes. Os incluidos por sentenca judicial vem sem
-- UF, ano e CNAE na propria fonte e ficam com esses campos nulos. O bronze
-- nao guarda nome, documento nem endereco: o que se publica e agregado.
WITH ultima AS (
    SELECT max(atualizado_em) AS atualizado_em
    FROM {{ source('bronze', 'mte_cadastro_empregadores') }}
),
cnae AS (
    SELECT codigo, divisao, secao FROM {{ source('bronze', 'cnae_classes') }}
)
SELECT
    c.atualizado_em,
    c.ano_acao_fiscal,
    c.uf AS uf_sigla,
    left(replace(c.cnae, '-', ''), 4) AS cnae_classe,
    concat(upper(left(d.divisao, 1)), {{ minusculas('substr(d.divisao, 2)') }}) AS cnae_divisao,
    {{ cnae_secao_da_divisao("left(replace(c.cnae, '-', ''), 2)") }} AS cnae_secao,
    concat(upper(left(d.secao, 1)), {{ minusculas('substr(d.secao, 2)') }}) AS cnae_secao_nome,
    c.tipo_documento,
    c.inclusao_judicial,
    COUNT(*) AS empregadores,
    SUM(c.trabalhadores) AS trabalhadores
FROM {{ source('bronze', 'mte_cadastro_empregadores') }} c
JOIN ultima u ON u.atualizado_em = c.atualizado_em
LEFT JOIN cnae d ON d.codigo = left(replace(c.cnae, '-', ''), 4)
GROUP BY c.atualizado_em, c.ano_acao_fiscal, c.uf, left(replace(c.cnae, '-', ''), 4),
         d.divisao, d.secao, c.tipo_documento, c.inclusao_judicial
