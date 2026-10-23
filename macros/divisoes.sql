{#
  Testa se a divisao CNAE (dois digitos) esta numa lista de dbt_project.yml.
  Numerador e denominador das taxas sem administracao publica usam a mesma
  lista, e a lista vive em um so lugar para que os dois lados nao divirjam.
#}
{% macro na_lista_de_divisoes(divisao, lista) -%}
    {{ divisao }} IN ('{{ lista | join("', '") }}')
{%- endmacro %}
