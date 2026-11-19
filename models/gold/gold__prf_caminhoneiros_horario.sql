-- Condutores de caminhao envolvidos em acidentes por hora do dia e dia da
-- semana, com obitos.
--
-- A distribuicao por hora e o indicio que a fonte oferece sobre jornada e
-- fadiga: a madrugada concentra menos trafego, e uma letalidade maior nela
-- e coerente com o que a literatura de saude do caminhoneiro aponta. E
-- descricao, nao demonstracao de causa.
SELECT
    ano,
    hora,
    dia_semana,
    fase_dia,
    COUNT(*) AS condutores,
    SUM(CASE WHEN obito THEN 1 ELSE 0 END) AS obitos,
    ROUND(SUM(CASE WHEN obito THEN 1 ELSE 0 END) * 1000.0 / COUNT(*), 1)
        AS obitos_por_mil_condutores
FROM {{ ref('silver__prf_envolvidos') }}
WHERE condutor AND categoria_veiculo = 'Caminhão'
GROUP BY ano, hora, dia_semana, fase_dia
