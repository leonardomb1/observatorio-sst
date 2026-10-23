SELECT
    e.evento_id,
    e.descricao,
    e.data_acidente,
    e.uf_empregador,
    COUNT(a.cat_chave) AS acidentes,
    SUM(CASE WHEN a.obito THEN 1 ELSE 0 END) AS obitos
FROM {{ ref('eventos_catastroficos') }} e
LEFT JOIN {{ ref('silver__acidentes') }} a
    ON a.evento_catastrofico = e.evento_id
GROUP BY e.evento_id, e.descricao, e.data_acidente, e.uf_empregador
