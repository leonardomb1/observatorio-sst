SELECT
    competencia,
    uf,
    admissoes,
    desligamentos,
    saldo
FROM {{ ref('gold__emprego_caged_mensal_uf') }}
