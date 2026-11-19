-- Acidentes de trabalho por atividade economica nos paises europeus (ESAW).
--
-- O Eurostat publica, para cada pais e agregado da Uniao Europeia, o numero de
-- acidentes e a taxa de incidencia padronizada por 100 mil ocupados, por
-- secao e divisao da NACE Rev. 2. As divisoes da NACE coincidem com as da
-- CNAE 2.0 (dois digitos), o que permite a comparacao setorial com o Brasil.
-- Os acidentes nao fatais do ESAW contam apenas afastamentos de mais de tres
-- dias e nao se comparam com a CAT; os fatais, sim, com a ressalva de que o
-- denominador europeu e a populacao ocupada, e nao o emprego formal.
SELECT
    CAST(ano AS INT) AS ano,
    gravidade,
    geo,
    nace_r2,
    CASE
        WHEN nace_r2 = 'TOTAL' THEN 'total'
        WHEN nace_r2 REGEXP '^[A-U]$' THEN 'secao'
        WHEN nace_r2 REGEXP '^[A-U][0-9]{2}$' THEN 'divisao'
        ELSE 'agregado'
    END AS nivel,
    CASE WHEN nace_r2 REGEXP '^[A-U][0-9]{2}$' THEN substr(nace_r2, 2, 2) END AS divisao,
    max(CASE WHEN unidade = 'NR' THEN valor END) AS acidentes,
    max(CASE WHEN unidade = 'RT_INC' THEN valor END) AS taxa_por_100mil_ocupados,
    nullif(max(flag), '') AS flag
FROM {{ source('bronze', 'eurostat_esaw') }}
GROUP BY ano, gravidade, geo, nace_r2
