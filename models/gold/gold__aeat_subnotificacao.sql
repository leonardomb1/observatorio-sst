-- Acidentes reconhecidos SEM CAT registrada, pela contagem oficial do anuario.
--
-- Esta e a unica medida oficial da subnotificacao, e o observatorio nao teria
-- como produzi-la a partir dos microdados: os arquivos publicos da CAT contem,
-- por definicao, apenas os acidentes que geraram CAT. O acidente sem CAT chega
-- ao anuario pelo nexo tecnico previdenciario, isto e, pelo beneficio concedido
-- sem que o empregador tenha comunicado o evento.
--
-- Cada edicao do anuario republica os anos anteriores com numeros revistos, por
-- isso mantem-se apenas a edicao mais recente de cada combinacao.
WITH ordenado AS (
    SELECT ano, escopo, escopo_tipo, cnae_codigo, total, com_cat, sem_cat,
           tipico, trajeto, doenca, anuario,
           row_number() OVER (PARTITION BY ano, escopo, cnae_codigo
                              ORDER BY anuario DESC) AS recencia
    FROM {{ source('bronze', 'aeat_registro') }}
)
SELECT ano, escopo, escopo_tipo, cnae_codigo, anuario,
       total, com_cat, sem_cat, tipico, trajeto, doenca,
       ROUND(sem_cat * 100.0 / nullif(total, 0), 1) AS pct_sem_cat
FROM ordenado
WHERE recencia = 1
