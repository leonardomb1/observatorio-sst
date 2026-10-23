-- O capitulo vem da subcategoria ou, quando o codigo chega truncado em tres
-- caracteres, da categoria. CAT sem capitulo resolvido nao vira linha, mas
-- fica contada em acidentes_sem_capitulo_ano, repetida em cada linha do ano.
WITH sem AS (
    SELECT ano, SUM(CASE WHEN cid10_capitulo IS NULL THEN 1 ELSE 0 END) AS acidentes_sem_capitulo_ano
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL
    GROUP BY ano
)
SELECT a.*, x.acidentes_sem_capitulo_ano, s.ano_status, coalesce(s.ano_completo, false) AS ano_completo
FROM (
    SELECT ano, cid10_capitulo, COUNT(*) AS acidentes, SUM(obito) AS obitos,
           SUM(CASE WHEN covid THEN 1 ELSE 0 END) AS acidentes_covid
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL AND cid10_capitulo IS NOT NULL
    GROUP BY 1, 2
) a
JOIN sem x ON x.ano = a.ano
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
