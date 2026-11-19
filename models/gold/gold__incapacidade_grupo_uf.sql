-- Afastamentos por incapacidade por grupo de diagnostico, UF e ano, com a
-- parcela reconhecida como acidentaria.
--
-- pct_acidentaria e a parte das concessoes do grupo que saiu com nexo com o
-- trabalho; nos transtornos mentais e nas doencas osteomusculares, que a
-- literatura associa fortemente ao trabalho, ela e o indicador do quanto esse
-- adoecimento chega a ser reconhecido. Os anos sem os doze meses publicados
-- (o primeiro, dez/2018, e o corrente) ficam marcados em ano_completo, e
-- pct_cid_informado_ano mostra quanto das concessoes do ano traz diagnostico:
-- onde ele e baixo (2022), a contagem por grupo nao mede o adoecimento, mede a
-- falta do dado. grupo_cid nulo reune as concessoes sem CID.
WITH ano_info AS (
    SELECT ano,
           COUNT(DISTINCT mes) = 12 AS ano_completo,
           ROUND(SUM(CASE WHEN cid10_codigo IS NOT NULL THEN concessoes ELSE 0 END) * 100.0
                 / SUM(concessoes), 1) AS pct_cid_informado_ano
    FROM {{ ref('silver__inss_incapacidade') }}
    GROUP BY ano
)
SELECT
    i.ano,
    i.uf,
    i.grupo_cid,
    i.tipo_incapacidade,
    SUM(i.concessoes) AS concessoes,
    SUM(CASE WHEN i.natureza = 'acidentaria' THEN i.concessoes ELSE 0 END) AS acidentarias,
    SUM(CASE WHEN i.natureza = 'previdenciaria' THEN i.concessoes ELSE 0 END) AS previdenciarias,
    ROUND(SUM(CASE WHEN i.natureza = 'acidentaria' THEN i.concessoes ELSE 0 END) * 100.0
          / SUM(i.concessoes), 1) AS pct_acidentaria,
    ROUND(SUM(i.soma_qt_sm_rmi) / SUM(i.concessoes), 2) AS rmi_media_salarios_minimos,
    a.ano_completo,
    a.pct_cid_informado_ano,
    a.pct_cid_informado_ano >= 80 AS cid_confiavel
FROM {{ ref('silver__inss_incapacidade') }} i
JOIN ano_info a ON a.ano = i.ano
WHERE i.tipo_incapacidade IN ('temporaria', 'permanente')
GROUP BY i.ano, i.uf, i.grupo_cid, i.tipo_incapacidade, a.ano_completo,
         a.pct_cid_informado_ano
