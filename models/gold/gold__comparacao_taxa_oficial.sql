-- Confronto entre a taxa que o observatorio calcula e a taxa oficial do anuario.
--
-- As duas divergem por construcao, e a distancia entre elas e o resultado, nao
-- um defeito. O numerador do observatorio conta apenas acidentes com CAT, ao
-- passo que o oficial soma tambem os reconhecidos sem CAT; e o denominador do
-- observatorio e o estoque de vinculos da RAIS em 31 de dezembro, ao passo que
-- o anuario usa a media anual de vinculos, base menor. A coluna razao mostra
-- quantas vezes a taxa oficial supera a calculada.
--
-- A razao tem duas causas, e confundi-las levaria a atribuir a subnotificacao o
-- que e defasagem da propria serie. A coluna pct_sem_cat mede a primeira causa.
-- A coluna cobertura_cat_pct mede a segunda: quanto do total oficial de CAT o
-- observatorio de fato reproduz. Em 2023 essa cobertura passa de 87%, ao passo
-- que no ano mais recente cai para perto de 68%, porque o acidente ocorrido em
-- um ano continua sendo comunicado nos anos seguintes e os arquivos mensais so
-- o registram quando a CAT e emitida. Ano recente e portanto subestimado duas
-- vezes, e a leitura correta e a do par de colunas, nunca a da razao isolada.
WITH proprio AS (
    SELECT ano, acidentes, obitos, vinculos_ativos,
           acidentes_por_100mil_vinculos, obitos_por_100mil_vinculos
    FROM {{ ref('gold__taxa_incidencia_brasil') }}
    WHERE ano_completo = true
),
oficial AS (
    SELECT ano, incidencia_por_100mil, mortalidade_por_100mil, letalidade_por_mil_acidentes
    FROM {{ ref('gold__aeat_indicadores_cnae') }}
    WHERE cnae_codigo = 'TOTAL' AND escopo_tipo = 'pais'
),
registro AS (
    SELECT ano, total, com_cat, sem_cat, pct_sem_cat
    FROM {{ ref('gold__aeat_subnotificacao') }}
    WHERE cnae_codigo = 'TOTAL' AND escopo_tipo = 'pais'
)
SELECT
    p.ano,
    p.acidentes AS acidentes_com_cat_observatorio,
    r.total AS acidentes_totais_oficial,
    r.sem_cat AS acidentes_sem_cat_oficial,
    r.pct_sem_cat,
    ROUND(p.acidentes * 100.0 / nullif(r.com_cat, 0), 1) AS cobertura_cat_pct,
    p.acidentes_por_100mil_vinculos AS taxa_observatorio,
    o.incidencia_por_100mil AS taxa_oficial,
    ROUND(o.incidencia_por_100mil / nullif(p.acidentes_por_100mil_vinculos, 0), 2)
        AS razao_taxa,
    p.obitos_por_100mil_vinculos AS mortalidade_observatorio,
    o.mortalidade_por_100mil AS mortalidade_oficial
FROM proprio p
JOIN oficial o ON o.ano = p.ano
JOIN registro r ON r.ano = p.ano
