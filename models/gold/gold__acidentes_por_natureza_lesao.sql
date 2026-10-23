SELECT ano, natureza_lesao, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ ref('silver__acidentes') }} WHERE ano IS NOT NULL AND natureza_lesao IS NOT NULL GROUP BY 1,2
