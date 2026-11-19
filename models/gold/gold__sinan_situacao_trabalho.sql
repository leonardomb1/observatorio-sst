-- Notificacoes de agravos de saude do trabalhador por situacao no mercado de
-- trabalho, no pais, por agravo e ano, com a parcela que teve CAT.
--
-- E a leitura direta de quem adoece ou se acidenta fora do emprego formal:
-- para cada situacao, quantas notificacoes e quantas chegaram a Previdencia.
-- situacao_trabalho nula reune o campo ignorado ou em branco.
SELECT
    agravo,
    agravo_nome,
    ano,
    preliminar,
    situacao_trabalho,
    vinculo,
    COUNT(*) AS notificacoes,
    SUM(CASE WHEN cat_emitida THEN 1 ELSE 0 END) AS com_cat,
    ROUND(SUM(CASE WHEN cat_emitida THEN 1 ELSE 0 END) * 100.0
          / nullif(SUM(CASE WHEN cat_emitida IS NOT NULL THEN 1 ELSE 0 END), 0), 1)
        AS pct_com_cat,
    SUM(CASE WHEN obito_trabalho THEN 1 ELSE 0 END) AS obitos
FROM {{ ref('silver__sinan_trabalho') }}
GROUP BY agravo, agravo_nome, ano, preliminar, situacao_trabalho, vinculo
