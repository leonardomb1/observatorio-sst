SELECT
    ano,
    ano_status,
    ano_completo,
    acidentes_com_cat_observatorio,
    acidentes_totais_oficial,
    acidentes_sem_cat_oficial,
    pct_sem_cat,
    cobertura_cat_pct,
    taxa_observatorio,
    taxa_oficial,
    razao_taxa,
    mortalidade_observatorio,
    mortalidade_oficial
FROM {{ ref('gold__comparacao_taxa_oficial') }}
