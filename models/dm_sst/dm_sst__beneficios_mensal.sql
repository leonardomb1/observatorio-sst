SELECT
    periodo,
    ano,
    especie_codigo,
    especie,
    concessoes,
    rmi_media,
    rmi_mediana,
    rmi_n
FROM {{ ref('gold__beneficios_mensal') }}
