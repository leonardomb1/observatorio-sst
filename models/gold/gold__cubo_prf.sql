{{ config(materialized='table', table_type='DUPLICATE', keys=['ano'], distributed_by=['ano']) }}
-- Pessoas envolvidas em acidentes nas rodovias federais no grao dos filtros.
--
-- A PRF traz UF, sexo, idade, veiculo, papel e hora, sem raca, atividade nem
-- ocupacao. ano_completo e falso no ano corrente, que a PRF ainda atualiza.
WITH ultimo AS (
    SELECT max(ano) AS ano FROM {{ ref('silver__prf_envolvidos') }}
)
SELECT
    p.ano,
    p.ano < u.ano AS ano_completo,
    p.uf AS uf_sigla,
    p.sexo,
    {{ faixa_etaria('p.idade') }} AS faixa_etaria,
    p.categoria_veiculo,
    p.condutor,
    p.hora,
    COUNT(*) AS envolvidos,
    SUM(CASE WHEN p.obito THEN 1 ELSE 0 END) AS obitos,
    SUM(CASE WHEN p.ferido_grave THEN 1 ELSE 0 END) AS feridos_graves
FROM {{ ref('silver__prf_envolvidos') }} p
CROSS JOIN ultimo u
GROUP BY p.ano, p.ano < u.ano, p.uf, p.sexo, {{ faixa_etaria('p.idade') }},
         p.categoria_veiculo, p.condutor, p.hora
