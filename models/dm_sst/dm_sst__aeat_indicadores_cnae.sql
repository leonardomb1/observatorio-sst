SELECT
    ano,
    escopo,
    escopo_tipo,
    cnae_codigo,
    anuario,
    incidencia_por_mil,
    incidencia_por_100mil,
    incidencia_doencas_por_mil,
    incidencia_tipicos_por_mil,
    incidencia_incap_temp_por_mil,
    mortalidade_por_100mil,
    letalidade_por_mil_acidentes,
    acidentalidade_16_34_pct
FROM {{ ref('gold__aeat_indicadores_cnae') }}
