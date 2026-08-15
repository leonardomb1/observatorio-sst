{#
  O warehouse usa nomes de esquema literais (gold, dm_sst, ops), sem o prefixo
  que o dbt adiciona por padrao. E os arquivos de modelo carregam o esquema no
  nome (gold__acidentes_mensal_uf) apenas para evitar colisao entre camadas,
  entao o objeto criado no banco recupera o nome limpo.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

{% macro generate_alias_name(custom_alias_name=none, node=none) -%}
    {%- if custom_alias_name -%}
        {{ custom_alias_name | trim }}
    {%- else -%}
        {{ node.name | replace('gold__', '') | replace('dm_sst__', '') | replace('ops__', '') }}
    {%- endif -%}
{%- endmacro %}
