SELECT
    ano,
    uf,
    grupo_causa,
    sexo,
    faixa_etaria,
    raca_cor,
    cbo_familia,
    obitos
FROM {{ ref('gold__sim_obitos_trabalho_perfil') }}
