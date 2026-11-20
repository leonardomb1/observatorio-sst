{#
  Dimensoes comuns aos cubos que alimentam os filtros do site. Toda fonte que
  tem atividade, idade ou ocupacao precisa entregar o mesmo valor para o mesmo
  filtro, senao escolher "Construcao" ou "25 a 34" filtraria cada secao de um
  jeito; por isso as regras ficam aqui, e nao em cada cubo.
#}

{# Letra da secao CNAE 2.0 a partir da divisao de dois digitos (texto). #}
{% macro cnae_secao_da_divisao(divisao) -%}
    CASE
        WHEN {{ divisao }} BETWEEN '01' AND '03' THEN 'A'
        WHEN {{ divisao }} BETWEEN '05' AND '09' THEN 'B'
        WHEN {{ divisao }} BETWEEN '10' AND '33' THEN 'C'
        WHEN {{ divisao }} = '35' THEN 'D'
        WHEN {{ divisao }} BETWEEN '36' AND '39' THEN 'E'
        WHEN {{ divisao }} BETWEEN '41' AND '43' THEN 'F'
        WHEN {{ divisao }} BETWEEN '45' AND '47' THEN 'G'
        WHEN {{ divisao }} BETWEEN '49' AND '53' THEN 'H'
        WHEN {{ divisao }} BETWEEN '55' AND '56' THEN 'I'
        WHEN {{ divisao }} BETWEEN '58' AND '63' THEN 'J'
        WHEN {{ divisao }} BETWEEN '64' AND '66' THEN 'K'
        WHEN {{ divisao }} = '68' THEN 'L'
        WHEN {{ divisao }} BETWEEN '69' AND '75' THEN 'M'
        WHEN {{ divisao }} BETWEEN '77' AND '82' THEN 'N'
        WHEN {{ divisao }} = '84' THEN 'O'
        WHEN {{ divisao }} = '85' THEN 'P'
        WHEN {{ divisao }} BETWEEN '86' AND '88' THEN 'Q'
        WHEN {{ divisao }} BETWEEN '90' AND '93' THEN 'R'
        WHEN {{ divisao }} BETWEEN '94' AND '96' THEN 'S'
        WHEN {{ divisao }} = '97' THEN 'T'
        WHEN {{ divisao }} = '99' THEN 'U'
    END
{%- endmacro %}

{# Faixa etaria em anos, nos cortes que o site ja usava; nula sem idade. #}
{% macro faixa_etaria(idade) -%}
    CASE
        WHEN {{ idade }} IS NULL THEN NULL
        WHEN {{ idade }} < 18 THEN 'Até 17'
        WHEN {{ idade }} < 25 THEN '18 a 24'
        WHEN {{ idade }} < 35 THEN '25 a 34'
        WHEN {{ idade }} < 45 THEN '35 a 44'
        WHEN {{ idade }} < 55 THEN '45 a 54'
        WHEN {{ idade }} < 65 THEN '55 a 64'
        ELSE '65 ou mais'
    END
{%- endmacro %}

{# Grande grupo da CBO 2002: o primeiro digito de um codigo de seis. #}
{% macro cbo_grande_grupo(codigo) -%}
    CASE WHEN {{ codigo }} REGEXP '^[0-9]{6}$' THEN left({{ codigo }}, 1) END
{%- endmacro %}
