SELECT a.*, s.ano_status
FROM (
    SELECT ano, sexo, COUNT(*) AS acidentes, SUM(obito) AS obitos
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL AND sexo IS NOT NULL
    GROUP BY 1, 2
) a
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
