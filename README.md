# Observatório de Dados de Segurança e Saúde no Trabalho

Transformações versionadas do observatório de acidentes de trabalho construído sobre dados públicos brasileiros. Este repositório contém a camada analítica em dbt: os modelos que produzem as métricas certificadas e os testes que protegem contra regressão silenciosa quando as fontes mudam.

Trabalho de Graduação em Análise e Desenvolvimento de Sistemas, Faculdade de Tecnologia de Indaiatuba.

## O problema

O Brasil publica microdados de Comunicação de Acidente de Trabalho, benefícios previdenciários, emprego formal e o texto das Normas Regulamentadoras. Publicar, porém, não é o mesmo que tornar utilizável. Os arquivos da CAT têm quatro gerações de layout desde 2018, com codificações diferentes, rótulos truncados em vinte caracteres, cabeçalhos duplicados e, em pelo menos um caso, um cabeçalho corrompido na origem. Alguns defeitos são sutis o bastante para passar despercebidos e produzir análise errada com aparência de correta.

## Arquitetura

Quatro camadas, cada uma com uma promessa distinta. Se não for possível enunciar a promessa de uma camada em uma frase, ela não deveria existir.

| Camada | Promessa |
|---|---|
| `bronze` | fiel à origem, sem interpretação |
| `silver` | conformado: tipos corretos, dicionários resolvidos, defeitos tratados |
| `gold` | métrica certificada, ponto único de verdade para qualquer número |
| `dm_sst` | distribuição do tópico, recorte fino para consumo |
| `ops` | metadado operacional da plataforma |

Duas regras sustentam a divisão. Reuso desce, não anda de lado: se dois datamarts precisarem da mesma coisa, ela desce para o gold, nunca é copiada entre marts. E datamart é por tópico, nunca por público: exposição é política de acesso, não modelagem.

As camadas `bronze` e `silver` são materializadas por pipelines de ingestão em Python, orquestrados no Windmill, e entram aqui como *sources*. Este repositório governa `gold`, `dm_sst` e `ops`.

## Fontes integradas

| Fonte | Conteúdo | Período |
|---|---|---|
| INSS, dados abertos | Microdados de CAT | out/2018 a mai/2026 |
| INSS, dados abertos | Benefícios acidentários concedidos | dez/2018 a jul/2026 |
| PDET, Ministério do Trabalho | Novo CAGED, fluxo de emprego formal | 2020 em diante |
| PDET, Ministério do Trabalho | RAIS, estoque de vínculos por município e CNAE | 2018 a 2025 |
| OIT, ILOSTAT | Indicador ODS 8.8.1, taxas por país | 2000 em diante |
| OSHA, Estados Unidos | Form 300A por estabelecimento | 2016 a 2025 |
| DATASUS, IBGE, CBO | Dicionários CID-10, municípios, CNAE, ocupações | vigentes |
| Portal CTPP | Texto integral das 38 Normas Regulamentadoras | vigente |

## Por que os testes existem

Cada teste deste projeto nasceu de um defeito real encontrado nos dados, e não de um exercício de completude.

O teste de valores aceitos em `tipo_acidente` existe porque a fonte mudou de layout quatro vezes; se surgir categoria nova, a suíte falha em vez de o painel exibir uma fatia desconhecida. O teste de espécie em `beneficios_mensal` protege contra a reentrada do auxílio-acidente previdenciário, espécie 36, que apesar do nome não decorre de acidente do trabalho e cuja inclusão superestimaria as concessões de 2023 em 12,5%. O teste de cobertura do dicionário CID-10 falha se a junção cair abaixo de 90%, sinal de dicionário desatualizado ou mudança de codificação. O teste de volume anual protege contra carga interrompida, situação em que um ano aparece com metade do volume habitual sem qualquer erro visível. E o teste de duplicidade de período detecta carga repetida sem a exclusão prévia.

## Achados que a modelagem tornou visíveis

O campo de unidade federativa do acidente está com os rótulos deslocados na origem. Não se trata de imprecisão de preenchimento: as contagens do campo reproduzem exatamente a distribuição da UF do empregador, porém associadas a estados errados, atribuindo ao Maranhão em 2023 os 208.088 acidentes que pertencem a São Paulo. Por isso todos os recortes geográficos usam a UF do empregador.

Acidentes de trajeto são 2,6 vezes mais letais que os típicos, com 882 óbitos por 100 mil acidentes contra 333, apesar de os típicos serem mais de três vezes mais numerosos.

A base da OIT não possui taxa de acidentes fatais do Brasil desde 2011, enquanto países como Alemanha e Estados Unidos reportam anualmente. Com o estoque de vínculos da RAIS como denominador, o observatório recalcula a série a partir dos microdados nacionais: 4,46 óbitos por 100 mil vínculos formais em 2023.

Dividir pelo emprego formal também desfaz a leitura ingênua do mapa. São Paulo lidera qualquer contagem absoluta por concentrar o emprego, mas a maior taxa de acidentes de 2023 é de Santa Catarina, com 1.587,8 por 100 mil vínculos contra 1.359,5 de São Paulo. Em óbitos, a ordem muda outra vez, e quem lidera é Mato Grosso, com 8,94 contra 3,95.

## Como executar

O projeto não versiona credencial alguma. O perfil lê host, usuário e senha do ambiente, preenchidos em tempo de execução:

```bash
export SR_HOST=starrocks-fe SR_PORT=9030 SR_USER=... SR_PASSWORD=...
dbt build --profiles-dir profiles
```

A variável `SR_SCHEMA_PREFIX` constrói uma cópia paralela do warehouse, útil para validar mudanças sem tocar no que os painéis e o assistente estão lendo. O prefixo é aplicado na macro `generate_schema_name`, e não no perfil, porque no perfil ele alcançaria apenas o esquema padrão e deixaria de fora justamente os esquemas por camada:

```bash
SR_SCHEMA_PREFIX=val_ dbt build --profiles-dir profiles
```

Em produção a execução é agendada no Windmill, após as cargas mensais, com o mesmo tratador de falhas dos demais pipelines. O script de execução usa a linguagem `dbt` nativa do Windmill, cujo conteúdo é um descritor e cujo projeto vive como módulos do próprio script. Esses módulos não são editados à mão: o script `f/sst/dbt_sync_repo` baixa este repositório e os substitui por completo. A regra é que o repositório manda, porque duas cópias editáveis do mesmo projeto divergem sem avisar.

## Estrutura

```
models/gold/      métricas certificadas, com os testes em schema.yml
models/dm_sst/    distribuição do tópico, views finas sobre o gold
models/ops/       metadado operacional
models/sources.yml  declaração das camadas bronze e silver
tests/            testes singulares, que devem retornar zero linhas
macros/           nomes de esquema literais e prefixo de validação
```

## Licença

MIT, ver `LICENSE`. Os dados de origem são públicos e pertencem aos respectivos órgãos.
