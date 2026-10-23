SELECT a.*, s.ano_status, coalesce(s.ano_completo, false) AS ano_completo
FROM (
    SELECT ano,
           CASE pmod(dayofweek(data_acidente)+5,7) WHEN 0 THEN 'Segunda' WHEN 1 THEN 'Terça'
                WHEN 2 THEN 'Quarta' WHEN 3 THEN 'Quinta' WHEN 4 THEN 'Sexta'
                WHEN 5 THEN 'Sábado' ELSE 'Domingo' END AS dia_semana,
           MIN(pmod(dayofweek(data_acidente)+5,7)) AS ordem,
           COUNT(*) AS acidentes, SUM(obito) AS obitos
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL AND data_acidente IS NOT NULL
    GROUP BY 1, 2
) a
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
