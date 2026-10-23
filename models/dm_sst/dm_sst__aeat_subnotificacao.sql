SELECT
    ano,
    escopo,
    escopo_tipo,
    cnae_codigo,
    anuario,
    total,
    com_cat,
    sem_cat,
    tipico,
    trajeto,
    doenca,
    pct_sem_cat
FROM {{ ref('gold__aeat_subnotificacao') }}
