-- Falha se alguma coluna ano ou mes de silver, gold, dm_sst ou ops nao for
-- INT. Ano como smallint, varchar ou bigint em camadas diferentes faz juncao
-- entre modelos voltar vazia sem erro, e o app trataria o ano como texto.
{%- set prefixo = env_var('SR_SCHEMA_PREFIX', '') %}
select table_schema, table_name, column_name, data_type
from information_schema.columns
where table_schema in ('{{ prefixo }}silver', '{{ prefixo }}gold', '{{ prefixo }}dm_sst', '{{ prefixo }}ops')
  and column_name in ('ano', 'mes')
  and lower(data_type) <> 'int'
