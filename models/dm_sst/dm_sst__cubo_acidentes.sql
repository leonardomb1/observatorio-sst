SELECT
    ano,
    ano_status,
    ano_completo,
    uf_sigla,
    sexo,
    faixa_etaria,
    cnae_secao,
    cbo_grande_grupo,
    tipo_acidente,
    acidentes,
    obitos
FROM {{ ref('gold__cubo_acidentes') }}
