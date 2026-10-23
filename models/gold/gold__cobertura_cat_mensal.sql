{{ config(materialized='table', table_type='DUPLICATE', keys=['ano', 'mes'], distributed_by=['ano']) }}
-- Cobertura mensal da serie de CAT, por ano do acidente e mes de emissao (ou
-- mes do arquivo, quando a emissao do arquivo nao e confiavel).
--
-- O esperado de cada mes e a mediana daquele mes do calendario nos anos
-- fechados, multiplicada pelo nivel do proprio ano. O nivel usa o quartil
-- superior das razoes, e nao a mediana, porque meses vazios puxariam a mediana
-- para baixo e esconderiam a propria lacuna. Como o nivel e medido dentro do
-- ano, a razao mede completude no ano, nao volume absoluto.
WITH ultimo AS (
    SELECT max(periodo) AS periodo FROM {{ source('bronze', 'cat') }}
),
base AS (
    SELECT ano,
           CAST(month(coalesce(CASE WHEN emissao_confiavel THEN data_emissao_cat END,
                               str_to_date(concat(periodo, '01'), '%Y%m%d'))) AS INT) AS mes,
           count(*) AS cats,
           sum(CASE WHEN obito THEN 1 ELSE 0 END) AS obitos,
           count(DISTINCT periodo) AS arquivos
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL
    GROUP BY 1, 2
),
grade AS (
    SELECT a.ano, CAST(g.generate_series AS INT) AS mes
    FROM (SELECT DISTINCT ano FROM base) a, TABLE(generate_series(1, 12)) g
),
m AS (
    SELECT g.ano, g.mes, coalesce(b.cats, 0) AS cats, b.obitos, b.arquivos,
           concat(g.ano, lpad(g.mes, 2, '0')) <= (SELECT periodo FROM ultimo) AS publicado
    FROM grade g
    LEFT JOIN base b ON b.ano = g.ano AND b.mes = g.mes
),
sazonal AS (
    SELECT mes, percentile_approx(cats, 0.5) AS ref_mes
    FROM m
    WHERE cats > 0 AND publicado AND ano < (SELECT max(ano) FROM m)
    GROUP BY mes
),
nivel AS (
    SELECT m.ano, percentile_approx(m.cats / s.ref_mes, 0.75) AS nivel_ano
    FROM m JOIN sazonal s ON s.mes = m.mes
    WHERE m.cats > 0 AND m.publicado
    GROUP BY m.ano
)
SELECT
    m.ano,
    m.mes,
    m.cats,
    m.obitos,
    m.arquivos,
    round(s.ref_mes, 0) AS ref_mes,
    round(n.nivel_ano, 2) AS nivel_ano,
    round(m.cats / (s.ref_mes * n.nivel_ano), 2) AS razao_esperado,
    CASE WHEN NOT m.publicado THEN 'nao_publicado'
         WHEN x.motivo IS NOT NULL THEN 'atipico'
         WHEN m.cats = 0 THEN 'ausente'
         WHEN m.cats / (s.ref_mes * n.nivel_ano) < {{ var('cobertura_lacuna') }} THEN 'lacuna'
         WHEN m.cats / (s.ref_mes * n.nivel_ano) < {{ var('cobertura_baixa') }} THEN 'baixo'
         ELSE 'ok' END AS status_mes,
    x.motivo AS nota
FROM m
JOIN sazonal s ON s.mes = m.mes
JOIN nivel n ON n.ano = m.ano
LEFT JOIN {{ ref('cobertura_excecoes') }} x ON x.ano = m.ano AND x.mes = m.mes
