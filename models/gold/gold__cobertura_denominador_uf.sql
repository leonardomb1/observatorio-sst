-- Quanto do trabalho o denominador formal alcanca, por UF e ano.
--
-- As taxas do observatorio dividem acidentes por vinculos ativos da RAIS em
-- 31 de dezembro. A PNAD do quarto trimestre estima, para o mesmo momento,
-- quantas pessoas estavam ocupadas e quantas em situacao de informalidade.
-- vinculos_por_100_ocupados e a razao entre as duas: nao e uma proporcao de
-- pessoas, porque a RAIS conta vinculos (uma pessoa pode ter mais de um) e
-- inclui estatutarios, mas e a melhor aproximacao publica do alcance das
-- taxas, e e nas UFs em que ela e baixa que a taxa sobre vinculos formais diz
-- menos sobre o risco de quem trabalha.
WITH pnad AS (
    SELECT ano, territorio AS uf, ocupados_mil, informais_mil,
           taxa_informalidade_pct, precisao_baixa
    FROM {{ ref('gold__pnad_informalidade') }}
    WHERE nivel = 'uf' AND sexo = 'Total' AND trimestre_do_ano = 4
),
rais AS (
    SELECT ano, uf, vinculos_ativos
    FROM {{ ref('gold__taxa_incidencia_uf') }}
)
SELECT
    p.ano,
    p.uf,
    p.ocupados_mil,
    p.informais_mil,
    p.taxa_informalidade_pct,
    r.vinculos_ativos,
    ROUND(r.vinculos_ativos / (p.ocupados_mil * 10.0), 1) AS vinculos_por_100_ocupados,
    p.precisao_baixa
FROM pnad p
JOIN rais r ON r.ano = p.ano AND r.uf = p.uf
