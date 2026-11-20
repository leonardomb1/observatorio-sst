SELECT
    trimestre,
    ano,
    trimestre_do_ano,
    nivel,
    territorio_codigo,
    territorio,
    uf_sigla,
    sexo,
    ocupados_mil,
    informais_mil,
    taxa_informalidade_pct,
    cv_ocupados_pct,
    cv_taxa_informalidade_pct,
    precisao_baixa
FROM {{ ref('gold__pnad_informalidade') }}
