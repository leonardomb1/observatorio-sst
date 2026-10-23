-- Acidentes por 100 mil vinculos formais, por ano e municipio.
--
-- A leitura por volume absoluto responde onde ha mais trabalhadores, nao onde
-- ha mais risco: Sao Paulo lidera qualquer contagem simplesmente por concentrar
-- o emprego. Dividir pelo estoque de vinculos da RAIS separa as duas coisas.
--
-- O ponto de partida e o denominador, nao o numerador: municipio com emprego
-- formal e sem acidente registrado tem taxa zero, que e informacao, e nao
-- ausencia de linha. A coluna base_suficiente marca os municipios pequenos, em
-- que um unico acidente move a taxa em centenas de pontos; eles permanecem na
-- tabela em vez de sumirem sem aviso, e cabe a quem consome decidir o corte.
--
-- A coluna ano_status vem de gold.status_ano: so o ano consolidado pode ser
-- comparado com outro. ano_completo e o mesmo criterio em booleano, mantido
-- para os paineis que ja o filtram.
WITH vinculos AS (
    SELECT ano, municipio_codigo, municipio, uf_sigla, uf, regiao,
           vinculos_ativos, estabelecimentos
    FROM {{ ref('gold__vinculos_rais_municipio') }}
    WHERE vinculos_ativos > 0
),
acidentes AS (
    SELECT ano, municipio_codigo, acidentes, obitos
    FROM {{ ref('gold__acidentes_por_municipio') }}
)
SELECT
    v.ano,
    v.municipio_codigo,
    v.municipio,
    v.uf_sigla,
    v.uf,
    v.regiao,
    v.vinculos_ativos,
    v.estabelecimentos,
    COALESCE(a.acidentes, 0) AS acidentes,
    COALESCE(a.obitos, 0) AS obitos,
    ROUND(COALESCE(a.acidentes, 0) * 100000.0 / v.vinculos_ativos, 1)
        AS acidentes_por_100mil_vinculos,
    ROUND(COALESCE(a.obitos, 0) * 100000.0 / v.vinculos_ativos, 2)
        AS obitos_por_100mil_vinculos,
    CASE WHEN v.vinculos_ativos >= 5000 THEN true ELSE false END AS base_suficiente,
    s.ano_status,
    coalesce(s.ano_completo, false) AS ano_completo
FROM vinculos v
LEFT JOIN {{ ref('gold__status_ano') }} s
    ON s.ano = v.ano
LEFT JOIN acidentes a
    ON a.ano = v.ano AND a.municipio_codigo = v.municipio_codigo
