SELECT
  c.periodo,
  str_to_date(nullif(nullif(trim(c.data_acidente),'0000/00'),'00/00/0000'), '%d/%m/%Y') AS data_acidente,
  year(str_to_date(nullif(nullif(trim(c.data_acidente),'0000/00'),'00/00/0000'), '%d/%m/%Y')) AS ano,
  month(str_to_date(nullif(nullif(trim(c.data_acidente),'0000/00'),'00/00/0000'), '%d/%m/%Y')) AS mes,
  str_to_date(nullif(nullif(trim(c.data_emissao_cat),'0000/00'),'00/00/0000'), '%d/%m/%Y') AS data_emissao_cat,
  datediff(str_to_date(nullif(nullif(trim(c.data_emissao_cat),'0000/00'),'00/00/0000'), '%d/%m/%Y'),
           str_to_date(nullif(nullif(trim(c.data_acidente),'0000/00'),'00/00/0000'), '%d/%m/%Y')) AS dias_ate_emissao,
  floor(datediff(str_to_date(nullif(nullif(trim(c.data_acidente),'0000/00'),'00/00/0000'), '%d/%m/%Y'),
                 str_to_date(nullif(trim(c.data_nascimento),'00/00/0000'), '%d/%m/%Y'))/365.25) AS idade,
  nullif(nullif(trim(c.uf_acidente),'Zerado'),'{ñ class}') AS uf_acidente,
  nullif(nullif(trim(c.uf_empregador),'Zerado'),'{ñ class}') AS uf_empregador,
  nullif(split_part(trim(c.municipio_empregador),'-',1),'000000') AS municipio_empregador_codigo,
  coalesce(mun.nome, nullif(split_part(trim(c.municipio_empregador),'-',2),'Ignorado')) AS municipio_empregador_nome,
  mun.uf_sigla AS municipio_uf,
  mun.regiao AS municipio_regiao,
  nullif(trim(c.cbo_codigo),'{ñ class}') AS cbo_codigo,
  coalesce(b.titulo, nullif(trim(c.cbo_descricao),'')) AS cbo_titulo,
  b.familia_titulo AS cbo_familia,
  replace(nullif(trim(c.cid10_codigo),'{ñ class}'),'.','') AS cid10_codigo,
  coalesce(d.descricao, nullif(trim(c.cid10_descricao),'')) AS cid10_descricao,
  d.grupo_descricao AS cid10_grupo,
  d.capitulo_descricao AS cid10_capitulo,
  nullif(trim(c.cnae_codigo),'0000') AS cnae_codigo,
  coalesce(cls.descricao, nullif(nullif(trim(c.cnae_descricao),'{ñ class}'),'')) AS cnae_descricao,
  cls.secao AS cnae_secao,
  nullif(trim(c.tipo_acidente),'Ignorado') AS tipo_acidente,
  (trim(c.indica_obito) = 'Sim') AS obito,
  nullif(nullif(trim(c.sexo),'Não Informado'),'Indeterminado') AS sexo,
  coalesce(rn.rotulo, nullif(trim(c.natureza_lesao),'{ñ class}')) AS natureza_lesao,
  coalesce(rp.rotulo, nullif(trim(c.parte_corpo),'{ñ class}')) AS parte_corpo,
  coalesce(ra.rotulo, nullif(trim(c.agente_causador),'{ñ class}')) AS agente_causador,
  trim(c.origem_cadastramento) AS origem_cadastramento,
  trim(c.emitente_cat) AS emitente_cat,
  str_to_date(nullif(trim(c.data_nascimento),'00/00/0000'), '%d/%m/%Y') AS data_nascimento,
  nullif(replace(replace(trim(c.cnpj_cei_empregador),'.',''),'/',''),'') AS cnpj_empregador,
  c.arquivo_origem
FROM {{ source('bronze', 'cat') }} c
LEFT JOIN {{ source('bronze', 'cid10') }} d ON d.codigo = replace(nullif(trim(c.cid10_codigo),'{ñ class}'),'.','') AND d.nivel='subcategoria'
LEFT JOIN {{ source('bronze', 'cbo') }} b ON b.codigo = trim(c.cbo_codigo) AND b.nivel='ocupacao'
LEFT JOIN {{ source('bronze', 'ibge_municipios') }} mun ON mun.codigo = split_part(trim(c.municipio_empregador),'-',1)
LEFT JOIN {{ source('bronze', 'cnae_classes') }} cls ON cls.codigo = trim(c.cnae_codigo)
LEFT JOIN {{ source('bronze', 'cat_rotulos') }} ra ON ra.campo='agente_causador' AND ra.prefixo = LEFT(trim(c.agente_causador),20)
LEFT JOIN {{ source('bronze', 'cat_rotulos') }} rp ON rp.campo='parte_corpo' AND rp.prefixo = LEFT(trim(c.parte_corpo),20)
LEFT JOIN {{ source('bronze', 'cat_rotulos') }} rn ON rn.campo='natureza_lesao' AND rn.prefixo = LEFT(trim(c.natureza_lesao),20)
