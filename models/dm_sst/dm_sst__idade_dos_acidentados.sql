SELECT
    ano,
    idade_media_geral,
    idade_media_obitos,
    ano_status,
    ano_completo
FROM {{ ref('gold__idade_dos_acidentados') }}
