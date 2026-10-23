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
--
-- cat_total conta toda CAT do ano, com ou sem municipio ou UF; cat_descartadas
-- sao as que nao entram na taxa por falta de municipio casado com a RAIS.
WITH total AS (
    SELECT ano, COUNT(*) AS cat_total
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL
    GROUP BY ano
),
agregado AS (
    SELECT
        ano, ano_status, ano_completo,
        SUM(vinculos_ativos) AS vinculos_ativos,
        SUM(vinculos_sem_adm_publica) AS vinculos_sem_adm_publica,
        SUM(vinculos_sem_divisoes_84_88) AS vinculos_sem_divisoes_84_88,
        SUM(estabelecimentos) AS estabelecimentos,
        SUM(acidentes) AS acidentes,
        SUM(obitos) AS obitos,
        SUM(acidentes_sem_adm_publica) AS acidentes_sem_adm_publica,
        SUM(obitos_sem_adm_publica) AS obitos_sem_adm_publica,
        SUM(acidentes_sem_divisoes_84_88) AS acidentes_sem_divisoes_84_88,
        SUM(obitos_sem_divisoes_84_88) AS obitos_sem_divisoes_84_88,
        SUM(acidentes_sem_cnae) AS acidentes_sem_cnae,
        SUM(acidentes_evento) AS acidentes_evento,
        SUM(obitos_evento) AS obitos_evento,
        SUM(acidentes_covid) AS acidentes_covid,
        SUM(obitos_covid) AS obitos_covid
    FROM {{ ref('gold__taxa_incidencia_municipio') }}
    GROUP BY ano, ano_status, ano_completo
)
SELECT
    g.ano,
    g.ano_status,
    g.ano_completo,
    g.vinculos_ativos,
    g.vinculos_sem_adm_publica,
    g.vinculos_sem_divisoes_84_88,
    g.estabelecimentos,
    g.acidentes,
    g.obitos,
    g.acidentes_sem_adm_publica,
    g.obitos_sem_adm_publica,
    g.acidentes_sem_divisoes_84_88,
    g.obitos_sem_divisoes_84_88,
    g.acidentes_sem_cnae,
    g.acidentes_evento,
    g.obitos_evento,
    g.acidentes_covid,
    g.obitos_covid,
    ROUND(g.acidentes * 100000.0 / g.vinculos_ativos, 1) AS acidentes_por_100mil_vinculos,
    ROUND(g.obitos * 100000.0 / g.vinculos_ativos, 2) AS obitos_por_100mil_vinculos,
    ROUND(g.acidentes_sem_adm_publica * 100000.0 / nullif(g.vinculos_sem_adm_publica, 0), 1)
        AS acidentes_por_100mil_vinculos_sem_adm_publica,
    ROUND(g.obitos_sem_adm_publica * 100000.0 / nullif(g.vinculos_sem_adm_publica, 0), 2)
        AS obitos_por_100mil_vinculos_sem_adm_publica,
    ROUND(g.acidentes_sem_divisoes_84_88 * 100000.0 / nullif(g.vinculos_sem_divisoes_84_88, 0), 1)
        AS acidentes_por_100mil_vinculos_sem_divisoes_84_88,
    ROUND(g.obitos_sem_divisoes_84_88 * 100000.0 / nullif(g.vinculos_sem_divisoes_84_88, 0), 2)
        AS obitos_por_100mil_vinculos_sem_divisoes_84_88,
    t.cat_total,
    g.acidentes AS cat_alocadas,
    t.cat_total - g.acidentes AS cat_descartadas,
    ROUND(100.0 * (t.cat_total - g.acidentes) / nullif(t.cat_total, 0), 2) AS pct_nao_alocavel
FROM agregado g
LEFT JOIN total t ON t.ano = g.ano
