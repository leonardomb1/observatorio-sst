-- Obitos por acidente de trabalho no SIM frente aos obitos com CAT, por UF.
--
-- E o confronto entre o registro da saude e o da Previdencia que a
-- literatura recomenda (Correa e Assuncao, 2003): nenhum dos dois capta todos
-- os casos. O SIM alcanca o trabalhador sem CAT, mas depende do campo
-- acidtrab, que fica em branco na maior parte das causas externas;
-- pct_campo_preenchido mostra, por UF e ano, sobre que base se apoia a
-- contagem. A UF do SIM e a de ocorrencia; a da CAT, a do empregador, a unica
-- confiavel na fonte, o que desloca casos de fronteira entre UFs vizinhas.
-- O lado da CAT so e comparavel nos anos consolidados, e o do SIM nao no
-- ultimo ano publicado, que o Ministerio da Saude divulga como preliminar e
-- completa ao longo do ano seguinte.
WITH ultimo AS (
    SELECT max(ano_arquivo) AS ano FROM {{ ref('silver__sim_causas_externas') }}
),
sim AS (
    SELECT ano, uf_ocorrencia AS uf,
           COUNT(*) AS obitos_causas_externas,
           SUM(CASE WHEN acidente_trabalho THEN 1 ELSE 0 END) AS obitos_trabalho_sim,
           SUM(CASE WHEN situacao_acidtrab IN ('sim', 'nao') THEN 1 ELSE 0 END)
               AS obitos_campo_preenchido
    FROM {{ ref('silver__sim_causas_externas') }}
    WHERE uf_ocorrencia IS NOT NULL AND ano IS NOT NULL
    GROUP BY ano, uf_ocorrencia
)
SELECT
    s.ano,
    s.uf,
    s.obitos_causas_externas,
    s.obitos_trabalho_sim,
    ROUND(s.obitos_campo_preenchido * 100.0 / s.obitos_causas_externas, 1)
        AS pct_campo_preenchido,
    c.obitos AS obitos_cat,
    ROUND(s.obitos_trabalho_sim * 1.0 / nullif(c.obitos, 0), 2) AS razao_sim_cat,
    c.vinculos_ativos,
    c.ano_status AS ano_status_cat,
    coalesce(c.ano_completo, false) AS ano_completo_cat,
    s.ano >= u.ano AS sim_preliminar
FROM sim s
CROSS JOIN ultimo u
LEFT JOIN {{ ref('gold__taxa_incidencia_uf') }} c
    ON c.ano = s.ano AND c.uf = s.uf
