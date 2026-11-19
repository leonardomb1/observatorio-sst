-- Condutores envolvidos em acidentes nas rodovias federais, por categoria de
-- veiculo, UF e ano, com obitos e feridos graves.
--
-- obitos_por_mil_condutores e a letalidade entre os condutores envolvidos:
-- mede quao grave e o acidente quando ele acontece, nao o risco por
-- quilometro rodado, que a fonte nao permite calcular. O condutor de caminhao
-- e o unico grupo da tabela que esta, por definicao, trabalhando.
SELECT
    ano,
    uf,
    categoria_veiculo,
    COUNT(*) AS condutores,
    SUM(CASE WHEN obito THEN 1 ELSE 0 END) AS obitos,
    SUM(CASE WHEN ferido_grave THEN 1 ELSE 0 END) AS feridos_graves,
    ROUND(SUM(CASE WHEN obito THEN 1 ELSE 0 END) * 1000.0 / COUNT(*), 1)
        AS obitos_por_mil_condutores
FROM {{ ref('silver__prf_envolvidos') }}
WHERE condutor
GROUP BY ano, uf, categoria_veiculo
