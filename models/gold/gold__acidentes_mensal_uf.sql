SELECT a.*, s.ano_status, coalesce(s.ano_completo, false) AS ano_completo
FROM (
    SELECT
        ano, mes, uf_empregador AS uf,
        COUNT(*) AS acidentes,
        SUM(obito) AS obitos,
        SUM(CASE WHEN evento_catastrofico IS NOT NULL THEN 1 ELSE 0 END) AS acidentes_evento,
        SUM(CASE WHEN evento_catastrofico IS NOT NULL AND obito THEN 1 ELSE 0 END) AS obitos_evento,
        SUM(CASE WHEN covid THEN 1 ELSE 0 END) AS acidentes_covid,
        SUM(CASE WHEN covid AND obito THEN 1 ELSE 0 END) AS obitos_covid
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL
    GROUP BY ano, mes, uf_empregador
) a
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
