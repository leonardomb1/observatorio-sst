SELECT ano, agente_causador, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ source('silver', 'acidentes') }} WHERE ano IS NOT NULL AND agente_causador IS NOT NULL GROUP BY 1,2
