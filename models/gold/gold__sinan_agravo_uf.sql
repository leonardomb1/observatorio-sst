-- Notificacoes de agravos de saude do trabalhador por agravo, UF e ano.
--
-- pct_informal e a parte das notificacoes com situacao de trabalho informada
-- que veio de empregado sem carteira, autonomo, temporario ou avulso, isto
-- e, de quem a CAT nao alcanca. pct_com_cat, calculado so onde o campo foi
-- preenchido, mede quanto do caso notificado na saude tambem foi comunicado a
-- Previdencia. Os dois sao indicadores do tamanho da subnotificacao do
-- registro previdenciario vista a partir do registro sanitario.
SELECT
    agravo,
    agravo_nome,
    ano,
    preliminar,
    uf,
    COUNT(*) AS notificacoes,
    SUM(CASE WHEN vinculo = 'informal' THEN 1 ELSE 0 END) AS informais,
    SUM(CASE WHEN vinculo = 'formal' THEN 1 ELSE 0 END) AS formais,
    ROUND(SUM(CASE WHEN vinculo = 'informal' THEN 1 ELSE 0 END) * 100.0
          / nullif(SUM(CASE WHEN vinculo IN ('formal', 'informal') THEN 1 ELSE 0 END), 0), 1)
        AS pct_informal,
    SUM(CASE WHEN cat_emitida THEN 1 ELSE 0 END) AS com_cat,
    ROUND(SUM(CASE WHEN cat_emitida THEN 1 ELSE 0 END) * 100.0
          / nullif(SUM(CASE WHEN cat_emitida IS NOT NULL THEN 1 ELSE 0 END), 0), 1)
        AS pct_com_cat,
    SUM(CASE WHEN obito_trabalho THEN 1 ELSE 0 END) AS obitos
FROM {{ ref('silver__sinan_trabalho') }}
GROUP BY agravo, agravo_nome, ano, preliminar, uf
