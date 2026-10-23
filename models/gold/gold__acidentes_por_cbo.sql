SELECT ano, cbo_codigo, max(cbo_titulo) AS ocupacao, COUNT(*) AS acidentes, SUM(obito) AS obitos FROM {{ ref('silver__acidentes') }} WHERE ano IS NOT NULL GROUP BY ano, cbo_codigo
