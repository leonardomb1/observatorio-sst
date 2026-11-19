SELECT
    ano,
    uf,
    grupo_cid,
    tipo_incapacidade,
    concessoes,
    acidentarias,
    previdenciarias,
    pct_acidentaria,
    rmi_media_salarios_minimos,
    ano_completo,
    pct_cid_informado_ano,
    cid_confiavel
FROM {{ ref('gold__incapacidade_grupo_uf') }}
