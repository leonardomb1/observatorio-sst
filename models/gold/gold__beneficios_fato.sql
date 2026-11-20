{{ config(materialized='table', table_type='DUPLICATE', keys=['ano', 'mes'], distributed_by=['ano', 'mes']) }}
-- Beneficios acidentarios concedidos pelo INSS, um registro por concessao,
-- com as dimensoes que o site recorta e a duracao prevista.
--
-- A duracao e a distancia entre o inicio (DIB) e a cessacao prevista (DCB),
-- que o INSS fixa na concessao do auxilio por incapacidade temporaria; so
-- existe nos arquivos de jun/2023 em diante e fica nula nos demais e quando
-- e negativa ou passa de dez anos. A despesa prevista multiplica a renda
-- mensal inicial, em salarios minimos, pelos meses previstos: e uma
-- estimativa em salarios minimos, sem reajustes nem prorrogacoes.
WITH meses AS (
    SELECT CAST(periodo AS INT) DIV 100 AS ano, COUNT(DISTINCT periodo) AS meses
    FROM {{ ref('silver__beneficios_acidentarios') }}
    GROUP BY CAST(periodo AS INT) DIV 100
),
nomes_uf AS (
    SELECT DISTINCT uf_sigla, uf_nome FROM {{ ref('gold__dim_uf') }}
),
base AS (
    SELECT
        CAST(b.periodo AS INT) DIV 100 AS ano,
        CAST(b.periodo AS INT) % 100 AS mes,
        b.especie_codigo,
        u.uf_sigla,
        CASE upper(trim(b.sexo)) WHEN 'MASCULINO' THEN 'Masculino' WHEN 'FEMININO' THEN 'Feminino' END AS sexo,
        years_diff(b.data_inicio, b.data_nascimento) AS idade,
        left(b.cid10_codigo, 3) AS cid10_categoria,
        b.cid10_codigo,
        left(lpad(b.cnae_codigo, 5, '0'), 2) AS cnae_divisao,
        CASE
            WHEN b.data_inicio IS NOT NULL AND b.data_cessacao IS NOT NULL
                 AND datediff(b.data_cessacao, b.data_inicio) BETWEEN 0 AND 3650
                THEN datediff(b.data_cessacao, b.data_inicio)
        END AS dias_previstos,
        b.rmi_salarios_minimos
    FROM {{ ref('silver__beneficios_acidentarios') }} b
    LEFT JOIN nomes_uf u ON {{ sem_acento('u.uf_nome') }} = {{ sem_acento('b.uf') }}
    WHERE b.acidente_trabalho AND b.especie_codigo IS NOT NULL
)
SELECT
    b.ano,
    b.mes,
    m.meses = 12 AS ano_completo,
    b.especie_codigo,
    b.uf_sigla,
    b.sexo,
    {{ faixa_etaria('b.idade') }} AS faixa_etaria,
    {{ cnae_secao_da_divisao('b.cnae_divisao') }} AS cnae_secao,
    b.cid10_categoria,
    CASE
        WHEN b.cid10_codigo LIKE 'F%' THEN 'Transtornos mentais e comportamentais'
        WHEN b.cid10_codigo LIKE 'M%' THEN 'Doenças osteomusculares'
        WHEN b.cid10_codigo LIKE 'S%' OR b.cid10_codigo LIKE 'T%' THEN 'Lesões e envenenamentos'
        WHEN b.cid10_codigo IS NULL THEN NULL
        ELSE 'Demais diagnósticos'
    END AS grupo_cid,
    b.dias_previstos,
    b.rmi_salarios_minimos,
    b.rmi_salarios_minimos * b.dias_previstos / 30.0 AS despesa_prevista_sm
FROM base b
LEFT JOIN meses m ON m.ano = b.ano
