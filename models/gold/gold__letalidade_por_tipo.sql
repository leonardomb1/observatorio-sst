-- Somente anos consolidados: ano parcial ou provisorio puxaria a razao para o
-- perfil dos meses que chegaram. anos_incluidos diz quais anos entraram.
SELECT a.tipo_acidente, COUNT(*) AS acidentes, SUM(a.obito) AS obitos,
       ROUND(SUM(a.obito)*100000.0/COUNT(*)) AS obitos_por_100mil_acidentes,
       group_concat(DISTINCT CAST(a.ano AS STRING) ORDER BY CAST(a.ano AS STRING) SEPARATOR ',') AS anos_incluidos
FROM {{ ref('silver__acidentes') }} a
JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano AND s.ano_status = 'consolidado'
WHERE a.tipo_acidente IS NOT NULL
GROUP BY 1
