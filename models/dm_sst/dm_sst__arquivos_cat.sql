SELECT
    periodo,
    arquivo_origem,
    geracao,
    linhas,
    linhas_mantidas,
    emissao_min,
    emissao_max,
    emissao_copia_acidente,
    emissao_dia_unico,
    cid_corrompido,
    cid_ausente,
    defeito_conhecido,
    nota
FROM {{ ref('gold__arquivos_cat') }}
