SELECT a.*, s.ano_status
FROM (
    SELECT ano, ROUND(AVG(idade),2) AS idade_media_geral,
           ROUND(AVG(CASE WHEN obito THEN idade END),2) AS idade_media_obitos
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL AND idade BETWEEN 14 AND 90
    GROUP BY 1
) a
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
