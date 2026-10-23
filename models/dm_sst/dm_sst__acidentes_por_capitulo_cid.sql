SELECT
    ano,
    cid10_capitulo,
    acidentes,
    obitos,
    acidentes_covid,
    acidentes_sem_capitulo_ano,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_capitulo_cid') }}
