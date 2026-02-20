# Racional Arquitetural — SetupOrion v2.8.0

> **Fonte:** `https://s3.setuporion.com.br/setuporion/SetupOrion`
> **Tamanho:** ~44.726 linhas de bash
> **Licença:** MIT — OrionDesign (contato@oriondesign.art.br)
> **Análise:** 2026-02-19 | **Propósito:** Extrair patterns para replicar no OpenClaw Deployer

---

## 1. Visão Geral

SetupOrion é um instalador monolítico em bash que transforma uma VPS vazia em um servidor com 80+ aplicações SaaS (Chatwoot, Evolution API, N8N, Typebot, Flowise, etc.) via Docker Swarm.

### Arquitetura em 2 camadas

```
Camada 1: Bootstrap (Setup)
  bash <(curl -sSL setup.oriondesign.art.br)
  └── Prepara servidor (apt, docker, jq, git, python3)
  └── Baixa e executa SetupOrion

Camada 2: SetupOrion (principal)
  └── Menu interativo com 80+ "ferramentas" (apps)
  └── Cada ferramenta = função bash autocontida
  └── Deploy via Docker Swarm + Portainer API
```

### Stack base obrigatória

| Componente | Versão | Função |
|------------|--------|--------|
| Docker Swarm | latest | Orquestração de containers |
| Traefik | v3.5.3 | Reverse proxy + Let's Encrypt automático |
| Portainer CE | latest | Dashboard de containers + API de deploy |

---

## 2. O Bootstrap (Setup)

O primeiro script (`Setup`) é um preparador de ambiente com 15 passos sequenciais:

```
Passo  1: Verifica/configura Docker (DOCKER_MIN_API_VERSION=1.24)
Passo  2: apt upgrade
Passo  3: Instala sudo
Passo  4: Instala apt-utils
Passo  5: Instala dialog
Passo  6-7: Instala jq (2 métodos: apt-get e apt)
Passo  8-9: Instala apache2-utils (2 métodos)
Passo 10: Instala git
Passo 11: Instala python3
Passo 12: apt update
Passo 13: apt upgrade
Passo 14: Instala neofetch
Passo 15: Baixa e executa SetupOrion
```

### Patterns do Bootstrap

**Verificação de OS (soft gate):**
```bash
if ! grep -q 'PRETTY_NAME="Debian GNU/Linux 11' /etc/os-release; then
    # Avisa mas NÃO bloqueia
    sleep 5
fi
```

**Verificação de root:**
```bash
if [ "$(id -u)" -ne 0 ]; then
    sudo su
fi
```

**Feedback por passo:**
```bash
comando > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "N/15 - [ OK ] - Descrição"
else
    echo "N/15 - [ OFF ] - Descrição"
fi
```

---

## 3. Estado Global = Filesystem

O Orion não usa banco de dados, JSON complexo ou state machine. Todo estado é armazenado em arquivos plaintext no disco.

### Estrutura de dados

```
~/dados_vps/
├── dados_vps              # Config global do servidor
│   ├── Nome do Servidor: meuserver
│   └── Rede interna: minha_rede
├── dados_portainer        # Credenciais do Portainer
│   ├── Dominio do portainer: painel.exemplo.com
│   ├── Usuario: admin
│   ├── Senha: MinhaS3nha@
│   └── Token: eyJhbGciOi...
├── dados_evolution        # Credenciais da Evolution
│   ├── Manager Evolution: https://evo.exemplo.com/manager
│   ├── BaseUrl: https://evo.exemplo.com
│   └── Global API Key: abc123
├── dados_n8n              # Credenciais do N8N
│   ├── Dominio Editor: https://n8n.exemplo.com
│   └── Dominio Webhook: https://webhook.exemplo.com
├── dados_chatwoot         # Credenciais do Chatwoot
└── dados_*                # Um arquivo por app instalada
```

### Stacks YAML geradas

```
~/
├── traefik.yaml           # Stack do Traefik (editável pelo user)
├── portainer.yaml         # Stack do Portainer
├── evolution.yaml         # Stack da Evolution API
├── n8n.yaml               # Stack do N8N
├── chatwoot.yaml          # Stack do Chatwoot
└── *.yaml                 # Uma stack por app instalada
```

### Leitura de estado

```bash
dados() {
    nome_servidor=$(grep "Nome do Servidor:" "$dados_vps" | awk -F': ' '{print $2}')
    nome_rede_interna=$(grep "Rede interna:" "$dados_vps" | awk -F': ' '{print $2}')
}
```

### Leitura de credenciais de outras apps

```bash
pegar_senha_postgres() {
    senha_postgres=$(grep "POSTGRES_PASSWORD" /root/postgres.yaml | awk -F '=' '{print $2}')
}

pegar_senha_minio() {
    user_minio=$(grep -i "MINIO_ROOT_USER" /root/minio.yaml | head -1 | sed 's/.*=//; s/^[[:space:]]*//')
    senha_minio=$(grep -i "MINIO_ROOT_PASSWORD" /root/minio.yaml | head -1 | sed 's/.*=//; s/^[[:space:]]*//')
}
```

**Princípio:** O YAML gerado é a fonte de verdade das credenciais. Não existe duplicação — se precisar da senha do Postgres, lê do `postgres.yaml`.

---

## 4. A Unidade Atômica: "Ferramenta"

Cada app instalável é uma função bash chamada `ferramenta_xxx()`. Todas seguem o mesmo ciclo de vida de 8 etapas:

```
┌─────────────────────────────────────────────────┐
│ 1. GATE DE RECURSOS                              │
│    recursos vCPU RAM                             │
│    → Verifica se máquina aguenta                 │
│    → Se não: avisa, pergunta se quer continuar   │
├─────────────────────────────────────────────────┤
│ 2. CARREGAR ESTADO                               │
│    dados                                         │
│    → Lê nome_servidor e nome_rede_interna        │
├─────────────────────────────────────────────────┤
│ 3. COLETA DE INPUTS (loop confirmado)            │
│    while true; do                                │
│      read → domínio                              │
│      read → email                                │
│      read → senha                                │
│      read → api_key                              │
│      ...                                         │
│      conferindo_as_info (mostra tudo)            │
│      read confirmação → Y: break / N: restart    │
│    done                                          │
├─────────────────────────────────────────────────┤
│ 4. RESOLVER DEPENDÊNCIAS                         │
│    verificar_container_postgres/redis/pgvector    │
│    → Se existe: pegar_senha + criar_banco        │
│    → Se não: ferramenta_postgres() recursivo     │
├─────────────────────────────────────────────────┤
│ 5. GERAR YAML                                    │
│    cat > app.yaml << EOL                         │
│    ...docker-compose com variáveis interpoladas  │
│    EOL                                           │
├─────────────────────────────────────────────────┤
│ 6. DEPLOY                                        │
│    STACK_NAME="app"                              │
│    stack_editavel                                │
│    → Autentica no Portainer via API              │
│    → Deploy via API do Portainer (não CLI)       │
├─────────────────────────────────────────────────┤
│ 7. VERIFICAR                                     │
│    pull imagem1 imagem2                          │
│    wait_stack "service1" "service2"              │
│    → Polling até todos os serviços 1/1           │
├─────────────────────────────────────────────────┤
│ 8. FINALIZAR                                     │
│    telemetria "App" "finalizado"                 │
│    cat > dados_vps/dados_app (salvar credenciais)│
│    instalado_msg                                 │
│    guarde_os_dados_msg (exibir credenciais)      │
│    creditos_msg                                  │
│    requisitar_outra_instalacao                   │
└─────────────────────────────────────────────────┘
```

---

## 5. Funções Utilitárias (o "framework")

### 5.1 Gate de Recursos

```bash
recursos() {
    vcpu_requerido=$1
    ram_requerido=$2

    # Detecta hardware via neofetch ou fastfetch
    vcpu_disponivel=$(neofetch --stdout | grep "CPU" | grep -oP '\(\d+\)' | tr -d '()')
    ram_disponivel=$(neofetch --stdout | grep "Memory" | awk '{print $4}' | tr -d 'MiB' | awk '{print int($1/1024 + 0.5)}')

    if [[ $vcpu_disponivel -ge $vcpu_requerido && $ram_disponivel -ge $ram_requerido ]]; then
        return 0  # OK
    else
        # Mostra erro mas PERMITE continuar
        echo "Servidor não atende requisitos: precisa $vcpu_requerido vCPU e $ram_requerido GB RAM"
        echo "Você possui: $vcpu_disponivel vCPU e $ram_disponivel GB RAM"
        read -p "Deseja continuar mesmo assim? (y/n): " escolha
        if [[ "$escolha" =~ ^[Yy]$ ]]; then
            return 0
        else
            return 1
        fi
    fi
}
```

**Uso:** `recursos 1 1` (1 vCPU, 1GB RAM) ou `recursos 2 4` (2 vCPU, 4GB RAM)

### 5.2 Verificação de Stack Existente

```bash
verificar_stack() {
    local nome_stack="$1"
    if docker stack ls --format "{{.Name}}" | grep -q "^${nome_stack}$"; then
        echo "A stack '$nome_stack' já existe."
        echo "Remova do Portainer e tente novamente."
        return 0   # Existe → NÃO instalar
    else
        return 1   # Não existe → pode instalar
    fi
}
```

### 5.3 Verificação de Dependências (Docker + Portainer + Traefik)

```bash
verificar_docker_e_portainer_traefik() {
    if ! command -v docker &> /dev/null; then
        echo "Docker não instalado. Instale [1] Traefik e Portainer primeiro."
        return 1
    fi
    if ! docker ps -a --format "{{.Names}}" | grep -q "portainer"; then
        echo "Portainer não instalado. Instale [1] Traefik e Portainer primeiro."
        return 1
    fi
    if ! docker ps -a --format "{{.Names}}" | grep -q "traefik"; then
        echo "Traefik não instalado. Instale [1] Traefik e Portainer primeiro."
        return 1
    fi
}
```

### 5.4 Deploy via Portainer API (stack_editavel)

Este é o pattern mais sofisticado. Em vez de usar `docker stack deploy` direto, o Orion autentica na API do Portainer e faz deploy por lá. Isso permite que o user edite a stack pelo GUI do Portainer depois.

```bash
stack_editavel() {
    # 1. Instala jq (necessário para parsing JSON)
    apt install jq -y > /dev/null 2>&1

    # 2. Lê credenciais do Portainer do arquivo de estado
    USUARIO=$(grep "Usuario: " /root/dados_vps/dados_portainer | awk -F "Usuario: " '{print $2}')
    SENHA=$(grep "Senha: " /root/dados_vps/dados_portainer | awk -F "Senha: " '{print $2}')
    PORTAINER_URL=$(grep "Dominio do portainer: " /root/dados_vps/dados_portainer | awk -F ": " '{print $2}')

    # 3. Autentica e obtém JWT (com retry até 6x)
    TOKEN=""
    Tentativa_atual=0
    Maximo_de_tentativas=6
    while [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; do
        TOKEN=$(curl -k -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$USUARIO\",\"password\":\"$SENHA\"}" \
            https://$PORTAINER_URL/api/auth | jq -r .jwt)
        Tentativa_atual=$((Tentativa_atual + 1))
        if [ "$Tentativa_atual" -ge "$Maximo_de_tentativas" ]; then
            echo "Falha ao obter token após $Maximo_de_tentativas tentativas."
            return
        fi
        sleep 5
    done

    # 4. Obtém endpoint ID do Portainer
    ENDPOINT_ID=$(curl -k -s -X GET \
        -H "Authorization: Bearer $TOKEN" \
        https://$PORTAINER_URL/api/endpoints | jq -r '.[0].Id')

    # 5. Lê o conteúdo do YAML gerado
    STACK_CONTENT=$(cat /root/$STACK_NAME.yaml)

    # 6. Cria a stack via API do Portainer
    curl -k -s -X POST \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$STACK_NAME\",
            \"stackFileContent\": $(echo "$STACK_CONTENT" | jq -Rsa .),
            \"swarmID\": \"$SWARM_ID\",
            \"env\": []
        }" \
        "https://$PORTAINER_URL/api/stacks?type=1&method=string&endpointId=$ENDPOINT_ID"
}
```

**Por que via Portainer e não direto?**
- O user pode editar a stack depois pelo GUI
- Portainer mantém estado e versioning
- Centraliza o gerenciamento visual

### 5.5 Wait com Feedback (polling de serviços)

```bash
wait_stack() {
    echo "Este processo pode demorar. Se levar mais de 10 minutos, cancele."
    declare -A services_status

    # Inicializa todos como pendente
    for service in "$@"; do
        services_status["$service"]="pendente"
    done

    while true; do
        all_active=true
        for service in "${!services_status[@]}"; do
            if docker service ls --filter "name=$service" | grep -q "1/1"; then
                if [ "${services_status["$service"]}" != "ativo" ]; then
                    echo "🟢 O serviço $service está online."
                    services_status["$service"]="ativo"
                fi
            else
                all_active=false
            fi
        done

        if $all_active; then
            break
        fi
        sleep 30
    done
}
```

**Aceita múltiplos serviços:** `wait_stack "n8n_redis" "n8n_editor" "n8n_webhook" "n8n_worker"`

### 5.6 Pull com Retry e Rate Limit Handling

```bash
pull() {
    for image in "$@"; do
        while true; do
            if docker pull "$image" > /dev/null 2>&1; then
                break
            else
                if docker pull "$image" 2>&1 | grep -q "toomanyrequests"; then
                    echo "Rate limit do Docker Hub. Faça login."
                    docker login
                else
                    echo "Erro ao baixar $image. Tentando novamente em 5s..."
                    sleep 5
                fi
            fi
        done
    done
}
```

### 5.7 Telemetria

```bash
telemetria() {
    read -r ip _ <<< "$(hostname -I)"
    curl --max-time 30 -X POST 'https://telemetria.oriondesign.art.br/api/telemetria' \
        -H "Content-Type: application/json" \
        -d "{
            \"ip\": \"$ip\",
            \"ferramenta\": \"$1\",
            \"status\": \"$2\"
        }" > /dev/null 2>&1
}
```

**Uso:** `telemetria "Evolution API" "iniciado"` e `telemetria "Evolution API" "finalizado"`

### 5.8 Validação de Senha

```bash
validar_senha() {
    senha=$1
    tamanho_minimo=$2
    # Checa: comprimento, maiúscula, minúscula, número, caractere especial (@_)
    # Rejeita caracteres fora de A-Za-z0-9@_
    # Retorna 1 com mensagens de erro detalhadas se inválida
}
```

### 5.9 Criação de Banco de Dados (dependência cascata)

```bash
criar_banco_postgres_da_stack() {
    # 1. Espera container postgres estar rodando
    while :; do
        if docker ps -q --filter "name=^postgres_postgres" | grep -q .; then
            CONTAINER_ID=$(docker ps -q --filter "name=^postgres_postgres")

            # 2. Verifica se banco já existe
            docker exec "$CONTAINER_ID" psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "$1"

            if [ $? -eq 0 ]; then
                # 3. Banco existe → pergunta se quer recriar
                read -p "Banco $1 já existe. Apagar e recriar? (Y/N): " resposta
                if [ "$resposta" == "Y" ]; then
                    docker exec "$CONTAINER_ID" psql -U postgres -c "DROP DATABASE IF EXISTS $1(force);"
                    docker exec "$CONTAINER_ID" psql -U postgres -c "CREATE DATABASE $1;"
                fi
            else
                # 4. Banco não existe → cria
                docker exec "$CONTAINER_ID" psql -U postgres -c "CREATE DATABASE $1;"
            fi
            break
        else
            sleep 5  # Container ainda não subiu, espera
        fi
    done
}
```

### 5.10 Multi-instância

```bash
# O pattern ${1:+_$1} permite múltiplas instâncias da mesma app
ferramenta_evolution() {
    # Se chamada com argumento: ferramenta_evolution "2"
    # Gera: evolution_2.yaml, evolution_2_redis, evolution_2_instances
    # Se sem argumento: evolution.yaml, evolution_redis, evolution_instances

    cat > evolution${1:+_$1}.yaml << EOL
    services:
      evolution${1:+_$1}_api:
        ...
      evolution${1:+_$1}_redis:
        ...
    volumes:
      evolution${1:+_$1}_instances:
        name: evolution${1:+_$1}_instances
    EOL

    STACK_NAME="evolution${1:+_$1}"
    stack_editavel
    wait_stack evolution${1:+_$1}_evolution${1:+_$1}_redis evolution${1:+_$1}_evolution${1:+_$1}_api
}
```

---

## 6. Coleta de Dados: O Loop Confirmado

Toda ferramenta coleta inputs do user com o mesmo pattern:

```bash
# 1. Exibe nome da app (ASCII art)
nome_chatwoot

# 2. Label visual
preencha_as_info

# 3. Loop até confirmação
while true; do

    # Coleta passo a passo
    echo -e "Passo 1/6"
    echo -en "Digite o domínio do Chatwoot: " && read -r url_chatwoot

    echo -e "Passo 2/6"
    echo -en "Digite o nome da empresa: " && read -r nome_empresa_chatwoot

    echo -e "Passo 3/6"
    echo -en "Digite o email SMTP: " && read -r email_admin_chatwoot

    # ... mais reads ...

    # 4. Mostra tudo que foi digitado para revisão
    clear
    nome_chatwoot
    conferindo_as_info

    echo "Dominio do Chatwoot: $url_chatwoot"
    echo "Nome da Empresa: $nome_empresa_chatwoot"
    echo "Email SMTP: $email_admin_chatwoot"
    # ... mostra todos ...

    # 5. Confirmação
    read -p "As respostas estão corretas? (Y/N): " confirmacao
    if [ "$confirmacao" = "Y" ] || [ "$confirmacao" = "y" ]; then
        clear
        instalando_msg
        break
    else
        # Volta pro início do loop
        clear
        nome_chatwoot
        preencha_as_info
    fi
done
```

**Características:**
- Numera os passos (Passo 1/6, 2/6...)
- Mostra exemplos no placeholder (ex: smtp.hostinger.com)
- Limpa tela entre etapas
- Apresenta ALL inputs para revisão antes de confirmar
- Se N → volta ao início sem perder nada (loop infinito)

---

## 7. Geração de YAML (Stack Docker Swarm)

Cada app gera um YAML completo via heredoc com variáveis bash interpoladas:

```bash
cat > evolution.yaml << EOL
version: "3.7"
services:
  evolution_api:
    image: evoapicloud/evolution-api:latest
    networks:
      - $nome_rede_interna
    environment:
      - SERVER_URL=https://$url_evolution
      - AUTHENTICATION_API_KEY=$apikeyglobal
      - DATABASE_PROVIDER=postgresql
      - DATABASE_CONNECTION_URI=postgresql://postgres:$senha_pgvector@pgvector:5432/evolution
      - CACHE_REDIS_URI=redis://evolution_redis:6379/1
      # ... 50+ variáveis de ambiente ...
    deploy:
      labels:
        - traefik.enable=1
        - traefik.http.routers.evolution.rule=Host(\`$url_evolution\`)
        - traefik.http.routers.evolution.entrypoints=websecure
        - traefik.http.routers.evolution.tls.certresolver=letsencryptresolver
        - traefik.http.services.evolution.loadbalancer.server.port=8080

  evolution_redis:
    image: redis:latest
    command: ["redis-server", "--appendonly", "yes", "--port", "6379"]
    volumes:
      - evolution_redis:/data
    networks:
      - $nome_rede_interna
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 1024M

volumes:
  evolution_instances:
    external: true
    name: evolution_instances
  evolution_redis:
    external: true
    name: evolution_redis

networks:
  $nome_rede_interna:
    external: true
    name: $nome_rede_interna
EOL
```

### Patterns do YAML

| Pattern | Descrição |
|---------|-----------|
| `external: true` em volumes e networks | Reutiliza recursos já criados |
| Cada app tem **Redis próprio** | Isolamento total entre apps |
| Todas conectam à mesma **overlay network** | Comunicação interna via nome de serviço |
| Traefik labels em toda app | HTTPS automático + routing por domínio |
| `deploy.resources.limits` | CPU e memória limitados por serviço |
| `deploy.constraints: node.role == manager` | Tudo roda no nó manager (single-node) |

---

## 8. O Menu Principal

O Orion opera via um loop infinito com `case` que recebe input numérico ou comandos textuais:

```bash
# Variável controla qual página do menu mostrar
menu_instalador="1"

while true; do
    # Exibe página do menu
    case $menu_instalador in
        1) menu_instalador_pg_1 ;;
        2) menu_instalador_pg_2 ;;
        3) menu_instalador_pg_3 ;;
        4) menu_comandos ;;
    esac

    # Lê input
    read -p "Opção: " opcao

    case $opcao in
        # Apps (números)
        01|1) ferramenta_traefik_e_portainer ;;
        02|2) ferramenta_chatwoot "setup" ;;
        03|3) ferramenta_evolution "setup" ;;
        04|4) ferramenta_minio "setup" ;;
        05|5) ferramenta_typebot "setup" ;;
        06|6) ferramenta_n8n "setup" ;;
        07|7) ferramenta_flowise ;;
        # ... até ~87 ...

        # Paginação
        p1|P1) menu_instalador="1" ;;
        p2|P2) menu_instalador="2" ;;
        p3|P3) menu_instalador="3" ;;
        comando|COMANDOS) menu_instalador="4" ;;

        # Comandos textuais (utilitários)
        portainer.restart) portainer.restart ;;
        portainer.reset) portainer.reset ;;
        portainer.update) portainer.update ;;
        traefik.update) traefik.update ;;
        traefik.dash) traefik.dash ;;
        chatwoot.mail) chatwoot.mail ;;
        limpar|clean) limpar ;;
        docker.fix) docker.fix ;;

        *) ;; # Input inválido = ignora
    esac
done
```

### Apps disponíveis (catálogo completo)

| # | App | Recursos | Dependências |
|---|-----|----------|--------------|
| 01 | Traefik + Portainer | 1 vCPU, 1GB | Nenhuma (base) |
| 02 | Chatwoot | 1 vCPU, 1GB | PgVector |
| 03 | Evolution API | 1 vCPU, 1GB | Redis (embutido) |
| 04 | MinIO | 1 vCPU, 1GB | Nenhuma |
| 05 | Typebot | 1 vCPU, 1GB | Postgres, MinIO |
| 06 | N8N | 1 vCPU, 1GB | Redis (embutido) |
| 07 | Flowise | 1 vCPU, 1GB | Nenhuma |
| 08 | PgAdmin | 1 vCPU, 1GB | Nenhuma |
| 09 | NocoBase | — | — |
| 10 | Botpress | — | — |
| 11 | WordPress | — | MySQL |
| 12 | MongoDB | — | Nenhuma |
| 13 | RabbitMQ | — | Nenhuma |
| 14 | PortaBilling (off) | — | — |
| 15 | Uptime Kuma | 1 vCPU, 1GB | Nenhuma |
| 16 | Cal.com | — | Postgres |
| 17 | Mautic | — | — |
| 18 | Appsmith | — | — |
| 19 | Qdrant | — | Nenhuma |
| 20 | WoofedCRM | — | — |
| 21 | Formbricks | — | — |
| 22 | NocoDB | 1 vCPU, 1GB | Nenhuma |
| 23 | Langfuse | — | Postgres |
| 24 | Metabase | 1 vCPU, 1GB | Postgres |
| 25 | Odoo | — | Postgres |
| 26 | Chatwoot Nestor | — | PgVector |
| 27 | Uno API | 1 vCPU, 1GB | — |
| 28 | Quepasa API | — | — |
| 29 | Grafana + Prometheus | — | — |
| 30 | Dify AI | — | — |
| 31 | Ollama | — | — |
| 32 | Affine | — | — |
| 33 | Directus | — | — |
| 34 | Vaultwarden | — | Nenhuma |
| 35 | Nextcloud | — | — |
| 36 | Strapi | — | — |
| 37 | PHPMyAdmin | — | MySQL |
| 38 | Supabase | — | — |
| 39 | Ntfy | — | Nenhuma |
| 40 | Lowcoder | — | — |
| 41 | Langflow | — | — |
| 42 | OpenProject | — | — |
| 43 | Zep | — | — |
| ... | +40 mais | — | — |

---

## 9. Fluxo de Dependências

O Orion resolve dependências de forma cascata. Se uma app precisa de Postgres e ele não está instalado, o Orion instala automaticamente:

```
ferramenta_chatwoot()
│
├── verificar_container_pgvector()
│   ├── Se existe → pegar_senha_pgvector() + criar_banco_pgvector_da_stack("chatwoot")
│   └── Se NÃO existe → ferramenta_pgvector()  ← instala automaticamente
│                        └── depois: pegar_senha + criar_banco
│
├── cat > chatwoot.yaml << EOL (gera stack com $senha_pgvector)
├── stack_editavel (deploy via Portainer)
└── wait_stack "chatwoot_app" "chatwoot_sidekiq" "chatwoot_redis"
```

**Tipos de dependência:**

| App | Precisa de | Como resolve |
|-----|-----------|--------------|
| Chatwoot | PgVector | `verificar_container_pgvector → ferramenta_pgvector()` |
| Typebot | Postgres + MinIO | `verificar_container_postgres → ferramenta_postgres()` + `pegar_senha_minio()` |
| N8N | Redis | Redis embutido no próprio YAML do N8N |
| Evolution | Redis | Redis embutido no próprio YAML da Evolution |
| Metabase | Postgres | `verificar_container_postgres → ferramenta_postgres()` |

---

## 10. Setup Inicial (Traefik + Portainer + Docker Swarm)

A opção [01] é especial — instala a base completa em 9 passos:

```
Passo 1/9: Coletar dados (domínio Portainer, email SSL, user/senha)
Passo 2/9: Configurar hostname + /etc/hosts
Passo 3/9: Instalar Docker Swarm
            ├── curl -fsSL https://get.docker.com | bash
            ├── systemctl enable docker
            ├── docker swarm init --advertise-addr $ip
            └── Retry até 3x se falhar
Passo 4/9: Criar rede overlay
            └── docker network create --driver=overlay $nome_rede_interna
Passo 5/9: Gerar traefik.yaml (Traefik v3.5.3 + Let's Encrypt)
Passo 6/9: Esperar Traefik ficar online (wait_stack "traefik")
Passo 7/9: Gerar portainer.yaml (Agent + CE)
Passo 8/9: Esperar Portainer ficar online (wait_stack "portainer")
Passo 9/9: Criar conta admin no Portainer via API
            ├── POST /api/users/admin/init (retry 4x)
            └── POST /api/auth → salvar JWT
```

### Criação de conta Portainer via API

```bash
MAX_RETRIES=4
for i in $(seq 1 $MAX_RETRIES); do
    RESPONSE=$(curl -k -s -X POST "https://$url_portainer/api/users/admin/init" \
        -H "Content-Type: application/json" \
        -d "{\"Username\": \"$user_portainer\", \"Password\": \"$pass_portainer\"}")

    if echo "$RESPONSE" | grep -q "\"Username\":\"$user_portainer\""; then
        echo "Conta criada com sucesso!"
        CONTA_CRIADA=true
        break
    fi
    sleep 15
done

# Gera token JWT
token=$(curl -k -s -X POST "https://$url_portainer/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$user_portainer\",\"password\":\"$pass_portainer\"}" | jq -r .jwt)
```

---

## 11. Funções de UI (feedback visual)

| Função | O que faz |
|--------|-----------|
| `nome_xxx()` | ASCII art gigante do nome da app |
| `instalando_msg()` | Banner "Instalando..." |
| `instalado_msg()` | Banner "Instalado com sucesso!" |
| `erro_msg()` | Banner "Ops! Algo deu errado" |
| `preencha_as_info()` | Label "Preencha as informações abaixo" |
| `conferindo_as_info()` | Label "Confira as informações abaixo" |
| `guarde_os_dados_msg()` | "Guarde os dados abaixo!" |
| `creditos_msg()` | Créditos do Orion Design |
| `versao()` | Versão + links WhatsApp |
| `esconder_senha()` | Substitui senha por asteriscos para exibição |

---

## 12. Patterns de Resiliência

| Pattern | Implementação |
|---------|---------------|
| **Retry em auth** | Token Portainer: retry 6x com sleep 5s |
| **Retry em create** | Conta Portainer: retry 4x com sleep 15s |
| **Retry em pull** | Pull de imagem: loop infinito até sucesso |
| **Rate limit handling** | Detecta "toomanyrequests" → pede `docker login` |
| **Swarm init retry** | 3 tentativas com sleep 5s |
| **Wait com timeout implícito** | "Se levar mais de 10 min, cancele" (manual) |
| **Fallback de instalação** | Docker: tenta `get.docker.com` → se falha, tenta manual via apt |

---

## 13. Decisões Arquiteturais

### Por que Docker Swarm e não Compose?

1. **Overlay network** — permite comunicação entre containers por nome de serviço
2. **Deploy declarativo** — `docker stack deploy` é idempotente
3. **Integração com Portainer** — API de stacks funciona nativamente com Swarm
4. **Scaling nativo** — `replicas: N` sem config adicional

### Por que Portainer API e não CLI direto?

1. **Editabilidade** — user pode ajustar stacks pelo GUI depois
2. **Versionamento** — Portainer mantém histórico de deploys
3. **Centralização** — um ponto de controle para todas as stacks
4. **Abstração** — não precisa saber Docker Swarm CLI

### Por que estado em plaintext e não JSON/YAML estruturado?

1. **Simplicidade** — `grep + awk` funciona sem dependências
2. **Legibilidade** — user pode ler/editar com `cat`/`nano`
3. **Robustez** — não quebra com parsing errors
4. **Zero dependências** — não precisa de jq para ler estado

### Por que monolito e não scripts separados?

1. **Distribuição** — um único `curl | bash` instala tudo
2. **Sem dependências de path** — tudo autocontido
3. **Compartilhamento de funções** — utilitários usados por todas as ferramentas
4. **Atualização atômica** — versão nova = arquivo novo

---

## 14. Mapeamento para OpenClaw Deployer

| Conceito Orion | Equivalente OpenClaw | Adaptação necessária |
|----------------|---------------------|---------------------|
| `ferramenta_xxx()` | Task do squad | Transformar em função bash |
| `recursos vCPU RAM` | `check-prerequisites` | Checar Node.js ≥22, pnpm, Git |
| `while read; confirmou?` | `elicit: true` no task | Implementar loop de coleta |
| `verificar_container_X` | Dependência cascata | Checar se OpenClaw já instalado |
| `cat > app.yaml << EOL` | Gerar .env / systemd unit | Heredoc com variáveis |
| `stack_editavel` (Portainer API) | `systemctl start` ou `docker compose up` | Mais simples (sem Portainer) |
| `wait_stack` | Health check com retry | `curl /health` com polling |
| `dados_vps/dados_*` | `~/.openclaw-setup/dados_*` | Mesmo pattern, diretório diferente |
| `telemetria` | Opcional | Pode pular ou adaptar |
| `pull` com retry | `npm install` / `pnpm install` | Retry em caso de network error |
| `menu_instalador` | Menu do script ou chamada direta | Pode ser menu ou args |
| `${1:+_$1}` multi-instância | Não necessário inicialmente | Futuro: múltiplos gateways |

---

## 15. Lições para o Script OpenClaw

1. **O script funciona porque é 100% determinístico** — zero LLM no runtime
2. **Loop de confirmação é obrigatório** — o user PRECISA ver e confirmar dados antes do deploy
3. **Dependências são resolvidas automaticamente** — se falta Node.js, instala; não pede pro user instalar
4. **Feedback visual constante** — o user nunca fica sem saber o que está acontecendo (N/M - [ OK ])
5. **Estado em arquivos simples** — grep funciona melhor que JSON parsing em bash
6. **Retry em tudo que pode falhar** — network, auth, pull, swarm init
7. **O YAML gerado fica no disco** — editável depois, não efêmero
8. **Uma função = uma app completa** — coleta, dependências, deploy, verificação, credenciais
