-- Perfil dos obitos por acidente de trabalho registrados no SIM.
--
-- Mesmo grao para todas as dimensoes que o SIM traz e a CAT nao, ou traz
-- mal: grupo de causa externa, raca/cor e a ocupacao de quem morreu, que no
-- SIM existe tambem para o informal. Conta so os obitos com acidtrab = sim;
-- o tamanho da base nao informada esta em gold__sim_obitos_trabalho_uf.
SELECT
    ano,
    uf_ocorrencia AS uf,
    grupo_causa,
    sexo,
    CASE WHEN idade < 18 THEN 'Até 17' WHEN idade < 25 THEN '18 a 24'
         WHEN idade < 35 THEN '25 a 34' WHEN idade < 45 THEN '35 a 44'
         WHEN idade < 55 THEN '45 a 54' WHEN idade < 65 THEN '55 a 64'
         WHEN idade IS NOT NULL THEN '65 ou mais' END AS faixa_etaria,
    raca_cor,
    cbo_familia,
    COUNT(*) AS obitos
FROM {{ ref('silver__sim_causas_externas') }}
WHERE acidente_trabalho AND ano IS NOT NULL
GROUP BY ano, uf_ocorrencia, grupo_causa, sexo,
         CASE WHEN idade < 18 THEN 'Até 17' WHEN idade < 25 THEN '18 a 24'
              WHEN idade < 35 THEN '25 a 34' WHEN idade < 45 THEN '35 a 44'
              WHEN idade < 55 THEN '45 a 54' WHEN idade < 65 THEN '55 a 64'
              WHEN idade IS NOT NULL THEN '65 ou mais' END,
         raca_cor, cbo_familia
