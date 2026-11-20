-- Acidentes por raca/cor e por nivel de instrucao, segundo o anuario oficial.
--
-- Os microdados publicos da CAT nao trazem raca/cor nem escolaridade; o
-- anuario e a unica fonte oficial dessas dimensoes, e as publica com e sem CAT
-- registrada, o que permite medir a subnotificacao por grupo: pct_sem_cat e a
-- parcela dos acidentes daquele grupo que so chegou a Previdencia pelo nexo
-- tecnico, sem comunicacao do empregador.
--
-- Cada edicao republica os anos anteriores, por isso fica a mais recente. A
-- linha Total da fonte nao entra como categoria: ela vira total_escopo, o
-- denominador da participacao de cada grupo. A participacao entre informados
-- exclui a categoria Ignorada, cujo peso varia entre UFs e anos.
WITH recente AS (
    SELECT ano, escopo, escopo_tipo, situacao_registro, dimensao, categoria,
           acidentes, anuario,
           row_number() OVER (PARTITION BY ano, escopo, situacao_registro,
                                            dimensao, categoria
                              ORDER BY anuario DESC) AS recencia
    FROM {{ source('bronze', 'aeat_perfil') }}
),
largo AS (
    SELECT ano, escopo, escopo_tipo, dimensao, categoria, max(anuario) AS anuario,
           max(CASE WHEN situacao_registro = 'total' THEN acidentes END) AS acidentes,
           max(CASE WHEN situacao_registro = 'com_cat' THEN acidentes END) AS com_cat,
           max(CASE WHEN situacao_registro = 'sem_cat' THEN acidentes END) AS sem_cat
    FROM recente
    WHERE recencia = 1
    GROUP BY ano, escopo, escopo_tipo, dimensao, categoria
),
com_total AS (
    SELECT l.*,
           max(CASE WHEN categoria = 'Total' THEN acidentes END)
               OVER (PARTITION BY ano, escopo, dimensao) AS total_escopo,
           sum(CASE WHEN categoria NOT IN ('Total', 'Ignorada') THEN acidentes END)
               OVER (PARTITION BY ano, escopo, dimensao) AS total_informado
    FROM largo l
)
SELECT
    CAST(ano AS INT) AS ano,
    escopo,
    escopo_tipo,
    u.uf_sigla,
    dimensao,
    categoria,
    CASE dimensao
        WHEN 'raca_cor' THEN CASE categoria
            WHEN 'Branca' THEN 1 WHEN 'Preta' THEN 2 WHEN 'Parda' THEN 3
            WHEN 'Amarela' THEN 4 WHEN 'Indígena' THEN 5 ELSE 9 END
        ELSE CASE categoria
            WHEN 'Sem Instrução' THEN 1 WHEN 'Fundamental Incompleto' THEN 2
            WHEN 'Fundamental Completo' THEN 3 WHEN 'Médio Incompleto' THEN 4
            WHEN 'Médio Completo' THEN 5 WHEN 'Superior Incompleto' THEN 6
            WHEN 'Superior Completo' THEN 7 ELSE 9 END
    END AS ordem,
    anuario,
    acidentes,
    com_cat,
    sem_cat,
    total_escopo,
    ROUND(sem_cat * 100.0 / nullif(acidentes, 0), 1) AS pct_sem_cat,
    ROUND(acidentes * 100.0 / nullif(total_escopo, 0), 1) AS pct_do_total,
    CASE WHEN categoria <> 'Ignorada'
         THEN ROUND(acidentes * 100.0 / nullif(total_informado, 0), 1)
    END AS pct_entre_informados
FROM com_total
LEFT JOIN {{ ref('gold__dim_uf') }} u ON com_total.escopo_tipo = 'uf' AND u.uf_nome = com_total.escopo
WHERE categoria <> 'Total'
