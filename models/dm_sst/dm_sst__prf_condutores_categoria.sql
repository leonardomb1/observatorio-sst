SELECT
    ano,
    uf,
    categoria_veiculo,
    condutores,
    obitos,
    feridos_graves,
    obitos_por_mil_condutores
FROM {{ ref('gold__prf_condutores_categoria') }}
