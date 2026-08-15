-- Indicadores oficiais do anuario por classe CNAE, para Brasil e unidades
-- federativas. Servem de referencia externa as taxas que o observatorio calcula
-- a partir da CAT e da RAIS, e trazem dois indicadores que nao derivam dos
-- microdados abertos: incidencia de incapacidade temporaria e acidentalidade da
-- faixa de 16 a 34 anos.
--
-- Atencao a unidade: aqui a incidencia vem por 1.000 vinculos e a mortalidade
-- por 100.000, enquanto os modelos proprios do observatorio usam 100.000 para
-- as duas. A coluna convertida existe para evitar comparacao entre escalas
-- diferentes, erro facil de cometer e dificil de perceber.
WITH ordenado AS (
    SELECT *, row_number() OVER (PARTITION BY ano, escopo, cnae_codigo
                                 ORDER BY anuario DESC) AS recencia
    FROM {{ source('bronze', 'aeat_indicadores') }}
)
SELECT ano, escopo, escopo_tipo, cnae_codigo, anuario,
       incidencia_por_mil,
       ROUND(incidencia_por_mil * 100, 1) AS incidencia_por_100mil,
       incidencia_doencas_por_mil,
       incidencia_tipicos_por_mil,
       incidencia_incap_temp_por_mil,
       mortalidade_por_100mil,
       letalidade_por_mil_acidentes,
       acidentalidade_16_34_pct
FROM ordenado
WHERE recencia = 1
