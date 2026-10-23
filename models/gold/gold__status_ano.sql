{{ config(materialized='table', table_type='DUPLICATE', keys=['ano'], distributed_by=['ano']) }}
-- Situacao de cada ano da serie de CAT, vocabulario comum a todo o datamart:
--   consolidado: todos os meses com ao menos metade do esperado e o arquivo de
--                dezembro publicado; comparavel entre anos
--   provisorio:  o arquivo de dezembro ainda nao foi publicado
--   parcial:     ano fechado com mes ausente ou abaixo de metade do esperado
-- ano_completo continua como booleano porque os paineis do Grafana o filtram.
WITH ultimo AS (
    SELECT max(periodo) AS periodo FROM {{ source('bronze', 'cat') }}
),
anos AS (
    SELECT ano,
           sum(cats) AS cats,
           sum(CASE WHEN status_mes IN ('ausente', 'lacuna') THEN 1 ELSE 0 END) AS meses_lacuna,
           sum(CASE WHEN status_mes = 'baixo' THEN 1 ELSE 0 END) AS meses_baixos,
           concat(ano, '12') > (SELECT periodo FROM ultimo) AS dezembro_pendente
    FROM {{ ref('gold__cobertura_cat_mensal') }}
    GROUP BY ano
),
aeat AS (
    SELECT CAST(ano AS INT) AS ano, com_cat
    FROM {{ ref('gold__aeat_subnotificacao') }}
    WHERE escopo_tipo = 'pais' AND cnae_codigo = 'TOTAL'
)
SELECT
    a.ano,
    a.cats,
    a.meses_lacuna,
    a.meses_baixos,
    CASE WHEN a.dezembro_pendente THEN 'provisorio'
         WHEN a.meses_lacuna > 0 THEN 'parcial'
         ELSE 'consolidado' END AS ano_status,
    (NOT a.dezembro_pendente AND a.meses_lacuna = 0) AS ano_completo,
    x.com_cat AS aeat_com_cat,
    round(100.0 * a.cats / nullif(x.com_cat, 0), 1) AS cobertura_aeat_pct
FROM anos a
LEFT JOIN aeat x ON x.ano = a.ano
