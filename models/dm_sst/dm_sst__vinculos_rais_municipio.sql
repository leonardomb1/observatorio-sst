SELECT
    ano,
    municipio_codigo,
    municipio,
    uf_sigla,
    uf,
    regiao,
    vinculos_ativos,
    vinculos_sem_adm_publica,
    vinculos_sem_divisoes_84_88,
    estabelecimentos
FROM {{ ref('gold__vinculos_rais_municipio') }}
