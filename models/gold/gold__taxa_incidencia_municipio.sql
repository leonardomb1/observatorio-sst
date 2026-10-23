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
-- Cada taxa nomeia o denominador. A taxa padrao para o app e a sem_adm_publica,
-- que retira a divisao 84 dos dois lados; a sem_divisoes_84_88 retira tambem
-- educacao, saude e servicos sociais, e a sem sufixo usa todos os vinculos.
--
-- A coluna ano_status vem de gold.status_ano: so o ano consolidado pode ser
-- comparado com outro. ano_completo e o mesmo criterio em booleano, mantido
-- para os paineis que ja o filtram.
WITH vinculos AS (
    SELECT ano, municipio_codigo, municipio, uf_sigla, uf, regiao,
           vinculos_ativos, vinculos_sem_adm_publica, vinculos_sem_divisoes_84_88,
           estabelecimentos
    FROM {{ ref('gold__vinculos_rais_municipio') }}
    WHERE vinculos_ativos > 0
),
acidentes AS (
    SELECT ano, municipio_codigo, acidentes, obitos,
           acidentes_sem_adm_publica, obitos_sem_adm_publica,
           acidentes_sem_divisoes_84_88, obitos_sem_divisoes_84_88,
           acidentes_sem_cnae, acidentes_evento, obitos_evento,
           acidentes_covid, obitos_covid
    FROM {{ ref('gold__acidentes_por_municipio') }}
),
juntos AS (
    SELECT
        v.ano, v.municipio_codigo, v.municipio, v.uf_sigla, v.uf, v.regiao,
        v.vinculos_ativos, v.vinculos_sem_adm_publica, v.vinculos_sem_divisoes_84_88,
        v.estabelecimentos,
        COALESCE(a.acidentes, 0) AS acidentes,
        COALESCE(a.obitos, 0) AS obitos,
        COALESCE(a.acidentes_sem_adm_publica, 0) AS acidentes_sem_adm_publica,
        COALESCE(a.obitos_sem_adm_publica, 0) AS obitos_sem_adm_publica,
        COALESCE(a.acidentes_sem_divisoes_84_88, 0) AS acidentes_sem_divisoes_84_88,
        COALESCE(a.obitos_sem_divisoes_84_88, 0) AS obitos_sem_divisoes_84_88,
        COALESCE(a.acidentes_sem_cnae, 0) AS acidentes_sem_cnae,
        COALESCE(a.acidentes_evento, 0) AS acidentes_evento,
        COALESCE(a.obitos_evento, 0) AS obitos_evento,
        COALESCE(a.acidentes_covid, 0) AS acidentes_covid,
        COALESCE(a.obitos_covid, 0) AS obitos_covid
    FROM vinculos v
    LEFT JOIN acidentes a
        ON a.ano = v.ano AND a.municipio_codigo = v.municipio_codigo
)
SELECT
    j.ano,
    j.municipio_codigo,
    j.municipio,
    j.uf_sigla,
    j.uf,
    j.regiao,
    j.vinculos_ativos,
    j.vinculos_sem_adm_publica,
    j.vinculos_sem_divisoes_84_88,
    j.estabelecimentos,
    j.acidentes,
    j.obitos,
    j.acidentes_sem_adm_publica,
    j.obitos_sem_adm_publica,
    j.acidentes_sem_divisoes_84_88,
    j.obitos_sem_divisoes_84_88,
    j.acidentes_sem_cnae,
    j.acidentes_evento,
    j.obitos_evento,
    j.acidentes_covid,
    j.obitos_covid,
    ROUND(j.acidentes * 100000.0 / j.vinculos_ativos, 1) AS acidentes_por_100mil_vinculos,
    ROUND(j.obitos * 100000.0 / j.vinculos_ativos, 2) AS obitos_por_100mil_vinculos,
    ROUND(j.acidentes_sem_adm_publica * 100000.0 / nullif(j.vinculos_sem_adm_publica, 0), 1)
        AS acidentes_por_100mil_vinculos_sem_adm_publica,
    ROUND(j.obitos_sem_adm_publica * 100000.0 / nullif(j.vinculos_sem_adm_publica, 0), 2)
        AS obitos_por_100mil_vinculos_sem_adm_publica,
    ROUND(j.acidentes_sem_divisoes_84_88 * 100000.0 / nullif(j.vinculos_sem_divisoes_84_88, 0), 1)
        AS acidentes_por_100mil_vinculos_sem_divisoes_84_88,
    ROUND(j.obitos_sem_divisoes_84_88 * 100000.0 / nullif(j.vinculos_sem_divisoes_84_88, 0), 2)
        AS obitos_por_100mil_vinculos_sem_divisoes_84_88,
    {{ var('base_minima_vinculos')['municipio'] }} AS base_minima,
    j.vinculos_ativos >= {{ var('base_minima_vinculos')['municipio'] }} AS base_suficiente,
    s.ano_status,
    coalesce(s.ano_completo, false) AS ano_completo
FROM juntos j
LEFT JOIN {{ ref('gold__status_ano') }} s
    ON s.ano = j.ano
