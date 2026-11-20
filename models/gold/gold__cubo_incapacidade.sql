{{ config(materialized='table', table_type='DUPLICATE', keys=['ano'], distributed_by=['ano']) }}
-- Concessoes de beneficios por incapacidade no grao dos filtros do site.
--
-- Serve as duas leituras: os beneficios acidentarios (natureza acidentaria) e
-- o adoecimento por diagnostico, em que a parte acidentaria e o reconhecimento
-- do nexo. O INSS nao publica idade, raca nem ocupacao do beneficiario, e a
-- atividade (CNAE) so vem nos arquivos de jun/2023 em diante e, mesmo neles,
-- zerada na maior parte das concessoes. ano_completo e cid_confiavel repetem
-- as marcas do ano para que o site nunca compare um ano sem diagnostico com
-- os demais.
WITH ano_info AS (
    SELECT ano,
           COUNT(DISTINCT mes) = 12 AS ano_completo,
           SUM(CASE WHEN cid10_codigo IS NOT NULL THEN concessoes ELSE 0 END) * 100.0
               / SUM(concessoes) >= 80 AS cid_confiavel
    FROM {{ ref('silver__inss_incapacidade') }}
    GROUP BY ano
)
SELECT
    i.ano,
    a.ano_completo,
    a.cid_confiavel,
    u.uf_sigla,
    i.sexo,
    i.especie_codigo,
    i.natureza,
    i.tipo_incapacidade,
    i.grupo_cid,
    i.cid10_categoria,
    {{ cnae_secao_da_divisao('left(i.cnae_classe, 2)') }} AS cnae_secao,
    SUM(i.concessoes) AS concessoes,
    SUM(i.soma_qt_sm_rmi) AS soma_qt_sm_rmi
FROM {{ ref('silver__inss_incapacidade') }} i
JOIN ano_info a ON a.ano = i.ano
LEFT JOIN {{ ref('gold__dim_uf') }} u ON u.uf_nome = i.uf
WHERE i.natureza IS NOT NULL
GROUP BY i.ano, a.ano_completo, a.cid_confiavel, u.uf_sigla, i.sexo, i.especie_codigo,
         i.natureza, i.tipo_incapacidade, i.grupo_cid, i.cid10_categoria,
         {{ cnae_secao_da_divisao('left(i.cnae_classe, 2)') }}
