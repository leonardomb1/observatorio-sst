SELECT
    evento_id,
    descricao,
    data_acidente,
    uf_empregador,
    acidentes,
    obitos
FROM {{ ref('gold__eventos_catastroficos') }}
