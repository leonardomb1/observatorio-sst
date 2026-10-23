-- Dias entre o acidente e a emissao da CAT. Os arquivos sem data de emissao
-- confiavel (emissao copiada do acidente, ou toda no mesmo dia) ficam de fora,
-- porque produziriam atraso zero ou arbitrario. Num mes em que esses arquivos
-- pesam, sobram so as CAT emitidas depois e o atraso sairia enviesado para
-- cima; abaixo de metade do mes com emissao confiavel, as medidas ficam nulas.
WITH mensal AS (
    SELECT ano, mes,
           ROUND(AVG(CASE WHEN valido THEN dias_ate_emissao END), 2) AS dias_medio_ate_emissao,
           percentile_approx(CASE WHEN valido THEN dias_ate_emissao END, 0.5) AS dias_mediana_ate_emissao,
           ROUND(100.0 * AVG(CASE WHEN valido THEN CASE WHEN dias_ate_emissao > 1 THEN 1 ELSE 0 END END), 1)
               AS pct_apos_1_dia,
           COUNT(CASE WHEN valido THEN 1 END) AS registros,
           ROUND(100.0 * COUNT(CASE WHEN emissao_confiavel THEN 1 END) / COUNT(*), 1) AS pct_emissao_confiavel
    FROM (
        SELECT ano, mes, dias_ate_emissao, emissao_confiavel,
               emissao_confiavel AND dias_ate_emissao BETWEEN 0 AND 365 AS valido
        FROM {{ ref('silver__acidentes') }}
        WHERE ano IS NOT NULL
    ) x
    GROUP BY ano, mes
)
SELECT
    m.ano,
    m.mes,
    CASE WHEN m.pct_emissao_confiavel >= 50 THEN m.dias_medio_ate_emissao END AS dias_medio_ate_emissao,
    CASE WHEN m.pct_emissao_confiavel >= 50 THEN m.dias_mediana_ate_emissao END AS dias_mediana_ate_emissao,
    CASE WHEN m.pct_emissao_confiavel >= 50 THEN m.pct_apos_1_dia END AS pct_apos_1_dia,
    m.registros,
    m.pct_emissao_confiavel,
    s.ano_status,
    coalesce(s.ano_completo, false) AS ano_completo
FROM mensal m
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = m.ano
