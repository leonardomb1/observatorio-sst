SELECT ano, parte_corpo_familia AS parte_corpo, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ ref('silver__acidentes') }} WHERE ano IS NOT NULL AND parte_corpo_familia IS NOT NULL GROUP BY 1,2
