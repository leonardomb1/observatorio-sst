-- Ocupacao e informalidade pela PNAD Continua, por trimestre, UF e sexo.
--
-- E a unica medida oficial do trabalho que a RAIS e o CAGED nao alcancam: os
-- informais, os autonomos sem registro e os trabalhadores domesticos sem
-- carteira. As pessoas sao contadas em milhares, como o IBGE publica, e cada
-- estimativa traz o seu coeficiente de variacao, que cresce nas UFs menores e
-- no recorte por sexo; acima de 15% o proprio IBGE considera a estimativa de
-- baixa precisao, sinalizada em precisao_baixa. uf_sigla e a chave do filtro
-- de localidade do site; e nula na linha do pais.
SELECT
    p.trimestre,
    CAST(p.trimestre DIV 100 AS INT) AS ano,
    CAST(p.trimestre % 100 AS INT) AS trimestre_do_ano,
    p.nivel,
    p.territorio_codigo,
    p.territorio,
    u.uf_sigla,
    p.sexo,
    max(CASE WHEN p.variavel_codigo = 4090 THEN p.valor END) AS ocupados_mil,
    max(CASE WHEN p.variavel_codigo = 4723 THEN p.valor END) AS informais_mil,
    max(CASE WHEN p.variavel_codigo = 12466 THEN p.valor END) AS taxa_informalidade_pct,
    max(CASE WHEN p.variavel_codigo = 4091 THEN p.valor END) AS cv_ocupados_pct,
    max(CASE WHEN p.variavel_codigo = 12467 THEN p.valor END) AS cv_taxa_informalidade_pct,
    coalesce(max(CASE WHEN p.variavel_codigo IN (4091, 12467) THEN p.valor END) > 15,
             false) AS precisao_baixa
FROM {{ source('bronze', 'pnad_trabalho') }} p
LEFT JOIN {{ ref('gold__dim_uf') }} u
    ON p.nivel = 'uf' AND u.uf_codigo = p.territorio_codigo
WHERE p.tabela = 4093
GROUP BY p.trimestre, p.nivel, p.territorio_codigo, p.territorio, u.uf_sigla, p.sexo
