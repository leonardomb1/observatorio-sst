SELECT
    ano,
    uf,
    obitos_causas_externas,
    obitos_trabalho_sim,
    pct_campo_preenchido,
    obitos_cat,
    razao_sim_cat,
    vinculos_ativos,
    ano_status_cat,
    ano_completo_cat,
    sim_preliminar
FROM {{ ref('gold__sim_obitos_trabalho_uf') }}
