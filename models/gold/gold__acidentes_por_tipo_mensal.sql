SELECT a.*, s.ano_status, coalesce(s.ano_completo, false) AS ano_completo
FROM (
    SELECT ano, mes, tipo_acidente, COUNT(*) AS acidentes, SUM(obito) AS obitos
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL AND tipo_acidente IS NOT NULL AND tipo_acidente <> ''
    GROUP BY ano, mes, tipo_acidente
) a
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
