SELECT ano, mes, uf_empregador AS uf, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ ref('silver__acidentes') }} WHERE ano IS NOT NULL GROUP BY ano, mes, uf_empregador
