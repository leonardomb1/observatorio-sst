SELECT
    ano,
    uf_sigla,
    cnae_secao,
    vinculos_ativos,
    admissoes,
    desligamentos,
    meses_caged
FROM {{ ref('gold__cubo_emprego') }}
