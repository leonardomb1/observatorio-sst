{#
  O warehouse usa nomes de esquema literais (gold, dm_sst, ops), sem o prefixo
  que o dbt adiciona por padrao. E os arquivos de modelo carregam o esquema no
  nome (gold__acidentes_mensal_uf) apenas para evitar colisao entre camadas,
  entao o objeto criado no banco recupera o nome limpo.

  SR_SCHEMA_PREFIX antepoe um prefixo a todos os esquemas, o que constroi uma
  copia paralela do warehouse (val_gold, val_dm_sst, val_ops) para ensaiar
  mudanca sem tocar no que os paineis e o assistente estao lendo. Vazio em
  producao. O prefixo precisa morar aqui: aplicado no perfil, ele so alcancaria
  o esquema padrao, e nao os esquemas por camada.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set prefixo = env_var('SR_SCHEMA_PREFIX', '') -%}
    {%- if custom_schema_name is none -%}
        {{ prefixo }}{{ target.schema }}
    {%- else -%}
        {{ prefixo }}{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

{% macro generate_alias_name(custom_alias_name=none, node=none) -%}
    {%- if custom_alias_name -%}
        {{ custom_alias_name | trim }}
    {%- else -%}
        {{ node.name | replace('gold__', '') | replace('dm_sst__', '') | replace('ops__', '') }}
    {%- endif -%}
{%- endmacro %}
