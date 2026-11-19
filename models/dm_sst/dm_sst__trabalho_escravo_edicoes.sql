SELECT
    atualizado_em,
    empregadores,
    trabalhadores,
    empregadores_pessoa_fisica,
    inclusoes_judiciais,
    ufs
FROM {{ ref('gold__trabalho_escravo_edicoes') }}
