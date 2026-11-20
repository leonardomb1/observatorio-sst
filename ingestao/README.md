# Ingestão

Código que materializa a camada `bronze`: descoberta, download, normalização de layout e carga de cada fonte pública. Roda no [Windmill](https://www.windmill.dev), na pasta `f/sst`, e é exportado para cá para que a cadeia inteira, da fonte ao datamart, possa ser lida e reproduzida.

- `scripts/`: um script Python por etapa ou fonte. Credenciais e endereços não ficam no código: os scripts leem o recurso `f/infra/starrocks` e as variáveis `f/infra/*` e `f/sst/inss_proxy` do próprio Windmill.
- `fluxos/`: fluxos que encadeiam descoberta e carga dos períodos ainda ausentes (CAT, benefícios e Novo CAGED).
- `agendamentos.json`: agendamentos mensais e semanais, com expressão cron no fuso de São Paulo.

## Cadeia por fonte

| Fonte | Script ou fluxo | Tabela bronze | Agendamento |
|---|---|---|---|
| CAT, INSS (dados abertos) | `fluxos/cat_refresh` → `list_cat_files`, `load_cat_file` | `cat` | dia 12 |
| CAGED, PDET/MTE | `fluxos/caged_refresh` → `list_caged_months`, `load_caged_month` | `caged_saldo` | dia 13 |
| Benefícios concedidos, INSS | `fluxos/beneficios_refresh` → `list_beneficios_files`, `load_beneficios_file` | `inss_beneficios`, `inss_incapacidade` | dia 14 |
| RAIS, PDET/MTE | `load_rais_ano` | `rais_estoque` | anual, sob demanda |
| Anuário (AEAT), Previdência | `load_aeat_anuario` | `aeat_*` | dia 17 |
| PNAD Contínua, IBGE (SIDRA) | `load_pnad_trabalho` | `pnad_trabalho` | dia 15 |
| Eurostat (ESAW) | `load_eurostat_esaw` | `eurostat_esaw` | dia 15 |
| SIM, Ministério da Saúde | `load_sim_causas_externas` | `sim_causas_externas` | dia 15 |
| SINAN, Ministério da Saúde | `load_sinan_trabalho` | `sinan_trabalho` | dia 15 |
| Acidentes nas rodovias federais, PRF | `load_prf_envolvidos` | `prf_envolvidos` | dia 15 |
| Cadastro de Empregadores, MTE | `load_cadastro_empregadores` | `mte_cadastro_empregadores` | dia 15 |
| ILOSTAT, OIT | `load_ilo_rates` | `ilo_sst_taxas` | dia 15 |
| OSHA (formulário 300A) | `load_osha_ita` | `osha_ita` | anual, sob demanda |
| Normas Regulamentadoras | `load_nrs` | `nr_norma`, `nr_texto` | sob demanda |
| Notícias de fiscalização, MTE | `scrape_mte_noticias` | `mte_noticias` | semanal |
| CID-10, CBO, municípios e CNAE | `load_dominios`, `load_dicionarios_ibge` | `cid10`, `cbo`, `ibge_*`, `cnae_*` | sob demanda |

Depois das cargas, `dbt_sync_repo` traz os modelos deste repositório e `dbt_observatorio` executa `dbt build` (dia 16), materializando `silver`, `gold`, `dm_sst` e `ops` com os testes. Qualquer falha de carga passa pelo `error_handler`, que a registra em `bronze.sst_falhas`.

## Relé no Brasil

O FTP do DATASUS, de onde vem o SINAN, e a API do portal de dados abertos do INSS, usada na descoberta dos arquivos de CAT e de benefícios, recusam conexões de fora do país. Esses passos (`load_sinan_trabalho`, `list_cat_files` e `list_beneficios_files`) passam por um proxy HTTP hospedado no Brasil, cujo endereço fica na variável `f/sst/inss_proxy`; o FTP é atravessado por túneis `CONNECT`, um para o canal de controle e um para cada conexão de dados. O proxy só encaminha para os domínios dessas fontes.

## Privacidade

Nenhum script carrega nome, CPF ou endereço. O cadastro de empregadores entra só com UF, atividade, ano da ação fiscal e número de trabalhadores; a CAT entra como publicada pelo INSS, que não identifica o trabalhador, e as camadas expostas ao site omitem o CNPJ e a data de nascimento.
