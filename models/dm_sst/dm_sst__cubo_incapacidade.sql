SELECT
    ano,
    ano_completo,
    cid_confiavel,
    uf_sigla,
    sexo,
    especie_codigo,
    natureza,
    tipo_incapacidade,
    grupo_cid,
    cid10_categoria,
    cnae_secao,
    concessoes,
    soma_qt_sm_rmi
FROM {{ ref('gold__cubo_incapacidade') }}
