SELECT
    ano,
    escopo,
    escopo_tipo,
    uf_sigla,
    dimensao,
    categoria,
    ordem,
    anuario,
    acidentes,
    com_cat,
    sem_cat,
    total_escopo,
    pct_sem_cat,
    pct_do_total,
    pct_entre_informados
FROM {{ ref('gold__aeat_perfil') }}
