SELECT
    ano,
    cid10_codigo,
    cid10_descricao,
    cid10_so_categoria,
    acidentes,
    obitos,
    acidentes_covid,
    ano_status,
    ano_completo
FROM {{ ref('gold__acidentes_por_diagnostico') }}
