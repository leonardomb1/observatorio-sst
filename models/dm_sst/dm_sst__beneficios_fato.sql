SELECT
    ano,
    mes,
    ano_completo,
    especie_codigo,
    uf_sigla,
    sexo,
    faixa_etaria,
    cnae_secao,
    cid10_categoria,
    grupo_cid,
    dias_previstos,
    rmi_salarios_minimos,
    despesa_prevista_sm
FROM {{ ref('gold__beneficios_fato') }}
