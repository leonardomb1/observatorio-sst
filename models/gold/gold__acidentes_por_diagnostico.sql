SELECT a.*, s.ano_status
FROM (
    SELECT ano, cid10_codigo, max(cid10_descricao) AS cid10_descricao,
           max(cid10_so_categoria) AS cid10_so_categoria,
           COUNT(*) AS acidentes, SUM(obito) AS obitos,
           SUM(CASE WHEN covid THEN 1 ELSE 0 END) AS acidentes_covid
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL AND cid10_descricao IS NOT NULL
    GROUP BY 1, 2
) a
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
