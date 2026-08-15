SELECT ano, parte_corpo, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ source('silver', 'acidentes') }} WHERE ano IS NOT NULL AND parte_corpo IS NOT NULL GROUP BY 1,2
