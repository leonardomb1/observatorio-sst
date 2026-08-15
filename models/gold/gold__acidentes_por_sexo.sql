SELECT ano, sexo, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ source('silver', 'acidentes') }} WHERE ano IS NOT NULL AND sexo IS NOT NULL GROUP BY 1,2
