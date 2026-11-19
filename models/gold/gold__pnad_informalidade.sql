-- Ocupacao e informalidade pela PNAD Continua, por trimestre, UF e sexo.
--
-- E a unica medida oficial do trabalho que a RAIS e o CAGED nao alcancam: os
-- informais, os autonomos sem registro e os trabalhadores domesticos sem
-- carteira. As pessoas sao contadas em milhares, como o IBGE publica, e cada
-- estimativa traz o seu coeficiente de variacao, que cresce nas UFs menores e
-- no recorte por sexo; acima de 15% o proprio IBGE considera a estimativa de
-- baixa precisao, sinalizada em precisao_baixa.
SELECT
    trimestre,
    CAST(trimestre DIV 100 AS INT) AS ano,
    CAST(trimestre % 100 AS INT) AS trimestre_do_ano,
    nivel,
    territorio_codigo,
    territorio,
    sexo,
    max(CASE WHEN variavel_codigo = 4090 THEN valor END) AS ocupados_mil,
    max(CASE WHEN variavel_codigo = 4723 THEN valor END) AS informais_mil,
    max(CASE WHEN variavel_codigo = 12466 THEN valor END) AS taxa_informalidade_pct,
    max(CASE WHEN variavel_codigo = 4091 THEN valor END) AS cv_ocupados_pct,
    max(CASE WHEN variavel_codigo = 12467 THEN valor END) AS cv_taxa_informalidade_pct,
    coalesce(max(CASE WHEN variavel_codigo IN (4091, 12467) THEN valor END) > 15,
             false) AS precisao_baixa
FROM {{ source('bronze', 'pnad_trabalho') }}
WHERE tabela = 4093
GROUP BY trimestre, nivel, territorio_codigo, territorio, sexo
