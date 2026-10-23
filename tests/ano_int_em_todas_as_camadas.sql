-- Falha se alguma coluna ano ou mes de silver, gold, dm_sst ou ops nao for
-- INT. Ano como smallint, varchar ou bigint em camadas diferentes faz juncao
-- entre modelos voltar vazia sem erro, e o app trataria o ano como texto.
-- O teste le o catalogo, entao depende de todo modelo final para rodar depois deles.
-- depends_on: {{ ref('dm_sst__acidentes_mensal_uf') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_agente') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_capitulo_cid') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_cbo') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_cnae') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_dia_semana') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_diagnostico') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_faixa_etaria') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_municipio') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_natureza_lesao') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_parte_corpo') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_sexo') }}
-- depends_on: {{ ref('dm_sst__acidentes_por_tipo_mensal') }}
-- depends_on: {{ ref('dm_sst__aeat_indicadores_cnae') }}
-- depends_on: {{ ref('dm_sst__aeat_subnotificacao') }}
-- depends_on: {{ ref('dm_sst__arquivos_cat') }}
-- depends_on: {{ ref('dm_sst__beneficios_mensal') }}
-- depends_on: {{ ref('dm_sst__beneficios_por_diagnostico') }}
-- depends_on: {{ ref('dm_sst__beneficios_por_uf') }}
-- depends_on: {{ ref('dm_sst__cobertura_cat_mensal') }}
-- depends_on: {{ ref('dm_sst__comparacao_taxa_oficial') }}
-- depends_on: {{ ref('dm_sst__emprego_caged_mensal_uf') }}
-- depends_on: {{ ref('dm_sst__eventos_catastroficos') }}
-- depends_on: {{ ref('dm_sst__idade_dos_acidentados') }}
-- depends_on: {{ ref('dm_sst__letalidade_por_tipo') }}
-- depends_on: {{ ref('dm_sst__noticias_fiscalizacao') }}
-- depends_on: {{ ref('dm_sst__osha_eua_taxas_ano') }}
-- depends_on: {{ ref('dm_sst__status_ano') }}
-- depends_on: {{ ref('dm_sst__taxa_fatal_paises') }}
-- depends_on: {{ ref('dm_sst__taxa_incidencia_brasil') }}
-- depends_on: {{ ref('dm_sst__taxa_incidencia_cnae') }}
-- depends_on: {{ ref('dm_sst__taxa_incidencia_municipio') }}
-- depends_on: {{ ref('dm_sst__taxa_incidencia_uf') }}
-- depends_on: {{ ref('dm_sst__tempestividade_cat') }}
-- depends_on: {{ ref('dm_sst__vinculos_rais_municipio') }}
-- depends_on: {{ ref('ops__cobertura_cat_mensal') }}
-- depends_on: {{ ref('ops__saude_das_cargas') }}
-- depends_on: {{ ref('ops__status_ano') }}
-- depends_on: {{ ref('gold__vinculos_rais_municipio') }}
{%- set prefixo = env_var('SR_SCHEMA_PREFIX', '') %}
select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema in ('{{ prefixo }}silver', '{{ prefixo }}gold', '{{ prefixo }}dm_sst', '{{ prefixo }}ops')
  and column_name in ('ano', 'mes')
  and lower(data_type) <> 'int'
