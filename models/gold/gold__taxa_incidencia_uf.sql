-- Taxa de incidencia por unidade federativa, agregada a partir do municipio.
--
-- A agregacao parte do municipio, e nao da UF declarada na CAT, por dois
-- motivos: o campo de UF do acidente esta com rotulos trocados na origem, e
-- somar municipios garante que numerador e denominador cubram exatamente o
-- mesmo conjunto de localidades.
--
-- O custo dessa escolha fica medido, e nao escondido: cat_total conta toda CAT
-- do ano atribuida a UF (pela UF do municipio do empregador no IBGE ou, sem
-- municipio, pela UF do empregador declarada), cat_alocadas as que entraram no
-- numerador e cat_descartadas a diferenca. As duas contagens usam a mesma
-- chave de UF, de modo que cat_alocadas + cat_descartadas = cat_total.
WITH ufs AS (
    SELECT DISTINCT uf_sigla, uf_nome FROM {{ source('bronze', 'ibge_municipios') }}
),
total AS (
    SELECT a.ano, coalesce(a.municipio_uf, u.uf_sigla) AS uf_sigla, COUNT(*) AS cat_total
    FROM {{ ref('silver__acidentes') }} a
    LEFT JOIN ufs u ON u.uf_nome = a.uf_empregador
    WHERE a.ano IS NOT NULL
    GROUP BY 1, 2
),
agregado AS (
    SELECT
        ano, ano_status, ano_completo, uf, uf_sigla, regiao,
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
    GROUP BY ano, ano_status, ano_completo, uf, uf_sigla, regiao
)
SELECT
    g.ano,
    g.ano_status,
    g.ano_completo,
    g.uf,
    g.uf_sigla,
    g.regiao,
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
    {{ var('base_minima_vinculos')['uf'] }} AS base_minima,
    g.vinculos_ativos >= {{ var('base_minima_vinculos')['uf'] }} AS base_suficiente,
    coalesce(t.cat_total, 0) AS cat_total,
    g.acidentes AS cat_alocadas,
    coalesce(t.cat_total, 0) - g.acidentes AS cat_descartadas,
    ROUND(100.0 * (coalesce(t.cat_total, 0) - g.acidentes) / nullif(t.cat_total, 0), 2) AS pct_nao_alocavel
FROM agregado g
LEFT JOIN total t
    ON t.ano = g.ano AND t.uf_sigla = g.uf_sigla
