SELECT ano, mes, uf_empregador AS uf, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ source('silver', 'acidentes') }} WHERE ano IS NOT NULL GROUP BY ano, mes, uf_empregador
