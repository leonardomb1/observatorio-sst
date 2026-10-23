SELECT ano, cid10_capitulo, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ ref('silver__acidentes') }} WHERE ano IS NOT NULL AND cid10_capitulo IS NOT NULL GROUP BY 1,2
