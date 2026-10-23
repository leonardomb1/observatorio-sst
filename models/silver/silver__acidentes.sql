-- Uma linha por CAT: a copia repetida por arquivo cumulativo fica so no silver.cat_registros.
SELECT
    periodo, data_acidente, ano, mes, data_emissao_cat, emissao_confiavel,
    dias_ate_emissao, idade, uf_acidente, uf_empregador,
    municipio_empregador_codigo, municipio_empregador_nome, municipio_uf, municipio_regiao,
    cbo_codigo, cbo_titulo, cbo_familia,
    cid10_codigo, cid10_categoria, cid10_so_categoria, cid10_descricao, cid10_grupo, cid10_capitulo,
    cnae_codigo, cnae_descricao, cnae_secao, tipo_acidente, obito, sexo,
    natureza_lesao, natureza_lesao_familia, parte_corpo, parte_corpo_familia,
    agente_causador, agente_causador_familia,
    origem_cadastramento, emitente_cat, data_nascimento, cnpj_empregador,
    covid, evento_catastrofico, geracao, arquivo_origem, cat_chave
FROM {{ ref('silver__cat_registros') }}
WHERE NOT is_duplicata
