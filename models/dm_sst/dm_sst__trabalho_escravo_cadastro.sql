SELECT
    atualizado_em,
    ano_acao_fiscal,
    uf,
    cnae_classe,
    cnae_divisao,
    cnae_secao,
    tipo_documento,
    inclusao_judicial,
    empregadores,
    trabalhadores
FROM {{ ref('gold__trabalho_escravo_cadastro') }}
