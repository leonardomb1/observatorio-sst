-- Afastamentos temporarios por categoria de CID-10, no pais, por ano.
--
-- Permite descer do grupo ao diagnostico: episodios depressivos (F32),
-- outros transtornos ansiosos (F41) e reacoes ao estresse grave (F43) entre os
-- mentais; dorsalgias (M54) e lesoes do ombro (M75) entre os osteomusculares.
-- So os afastamentos temporarios, B31 frente a B91, que e onde o
-- reconhecimento do nexo se decide.
WITH meses AS (
    SELECT ano,
           COUNT(DISTINCT mes) = 12 AS ano_completo,
           SUM(CASE WHEN cid10_codigo IS NOT NULL THEN concessoes ELSE 0 END) * 100.0
               / SUM(concessoes) >= 80 AS cid_confiavel
    FROM {{ ref('silver__inss_incapacidade') }}
    GROUP BY ano
),
cid AS (
    SELECT codigo AS categoria, max(descricao) AS descricao
    FROM {{ source('bronze', 'cid10') }}
    WHERE length(codigo) = 3
    GROUP BY codigo
)
SELECT
    i.ano,
    i.grupo_cid,
    i.cid10_categoria,
    c.descricao AS cid10_descricao,
    SUM(i.concessoes) AS concessoes,
    SUM(CASE WHEN i.natureza = 'acidentaria' THEN i.concessoes ELSE 0 END) AS acidentarias,
    ROUND(SUM(CASE WHEN i.natureza = 'acidentaria' THEN i.concessoes ELSE 0 END) * 100.0
          / SUM(i.concessoes), 1) AS pct_acidentaria,
    m.ano_completo,
    m.cid_confiavel
FROM {{ ref('silver__inss_incapacidade') }} i
JOIN meses m ON m.ano = i.ano
LEFT JOIN cid c ON c.categoria = i.cid10_categoria
WHERE i.tipo_incapacidade = 'temporaria' AND i.cid10_categoria IS NOT NULL
GROUP BY i.ano, i.grupo_cid, i.cid10_categoria, c.descricao, m.ano_completo,
         m.cid_confiavel
