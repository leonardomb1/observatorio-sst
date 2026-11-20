SELECT
    ano,
    ano_completo,
    uf_sigla,
    sexo,
    faixa_etaria,
    categoria_veiculo,
    condutor,
    hora,
    envolvidos,
    obitos,
    feridos_graves
FROM {{ ref('gold__cubo_prf') }}
