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

{#
  O lower() do StarRocks so rebaixa ASCII: em "EXTRAÇÃO DE PEDRA" as letras
  acentuadas sobrevivem em caixa alta e o rotulo sai como "ExtraÇÃo". Como a
  CAT publica as descricoes de CNAE inteiramente em maiusculas, a correcao
  precisa vir daqui. A lista cobre as vogais acentuadas e o cedilha, que e o
  conjunto que de fato ocorre nas descricoes.
#}
{% macro minusculas(coluna) -%}
    {%- set pares = [('Á','á'), ('À','à'), ('Â','â'), ('Ã','ã'), ('É','é'),
                     ('Ê','ê'), ('Í','í'), ('Ó','ó'), ('Ô','ô'), ('Õ','õ'),
                     ('Ú','ú'), ('Ü','ü'), ('Ç','ç')] -%}
    {%- set ns = namespace(expr = 'lower(' ~ coluna ~ ')') -%}
    {%- for de, para in pares -%}
        {%- set ns.expr = "replace(" ~ ns.expr ~ ", '" ~ de ~ "', '" ~ para ~ "')" -%}
    {%- endfor -%}
    {{ ns.expr }}
{%- endmacro %}
