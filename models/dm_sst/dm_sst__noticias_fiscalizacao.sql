SELECT
    tipo_acao,
    data_publicacao,
    titulo,
    ufs,
    cita_obito
FROM {{ ref('gold__noticias_fiscalizacao') }}
