#!/bin/bash

BOLD="\033[1m"
UNDERLINE="\033[4m"
DARK_YELLOW="\033[0;33m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
RESET="\033[0m"

execute_with_prompt() {
    echo -e "${BOLD}Выполняется: $1${RESET}"
    if eval "$1"; then
        echo "Команда выполнена успешно."
    else
        echo -e "${BOLD}${DARK_YELLOW}Ошибка при выполнении команды: $1${RESET}"
        exit 1
    fi
}

echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Требования для запуска allora-worker-node${RESET}"
echo
echo -e "${BOLD}${DARK_YELLOW}Операционная система: Ubuntu 22.04${RESET}"
echo -e "${BOLD}${DARK_YELLOW}Процессор: Минимум 1/2 ядра.${RESET}"
echo -e "${BOLD}${DARK_YELLOW}ОЗУ: 2-4 ГБ.${RESET}"
echo -e "${BOLD}${DARK_YELLOW}Хранилище: SSD или NVMe с минимум 5 ГБ свободного места.${RESET}"
echo

echo -e "${CYAN}Сервер соответствует этим требованиям? (Y/N):${RESET}"
read -p "" response
echo

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${BOLD}${DARK_YELLOW}Выход...${RESET}"
    echo
    exit 1
fi

echo -e "${BOLD}${DARK_YELLOW}Обновление системных пакетов...${RESET}"
execute_with_prompt "sudo apt update -y && sudo apt upgrade -y"
echo

echo -e "${BOLD}${DARK_YELLOW}Установка пакетов jq...${RESET}"
execute_with_prompt "sudo apt install jq"
echo

echo -e "${BOLD}${DARK_YELLOW}Установка Docker...${RESET}"
execute_with_prompt 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg'
echo
execute_with_prompt 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
echo
execute_with_prompt 'sudo apt-get update'
echo
execute_with_prompt 'sudo apt-get install docker-ce docker-ce-cli containerd.io -y'
echo
sleep 2
echo -e "${BOLD}${DARK_YELLOW}Проверка версии Docker...${RESET}"
execute_with_prompt 'docker version'
echo

echo -e "${BOLD}${DARK_YELLOW}Установка Docker Compose...${RESET}"
VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
echo
execute_with_prompt 'sudo curl -L "https://github.com/docker/compose/releases/download/'"$VER"'/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
echo
execute_with_prompt 'sudo chmod +x /usr/local/bin/docker-compose'
echo

echo -e "${BOLD}${DARK_YELLOW}Проверка версии Docker Compose...${RESET}"
execute_with_prompt 'docker-compose --version'
echo

if ! grep -q '^docker:' /etc/group; then
    execute_with_prompt 'sudo groupadd docker'
    echo
fi

execute_with_prompt 'sudo usermod -aG docker $USER'
echo
echo -e "${GREEN}${BOLD}Запросите тестовые токены для своего кошелька по этой ссылке:${RESET} https://faucet.testnet-1.testnet.allora.network/"
echo

echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Установка ноды worker...${RESET}"
git clone https://github.com/allora-network/basic-coin-prediction-node
cd basic-coin-prediction-node
echo
read -p "Введите WALLET_SEED_PHRASE: " WALLET_SEED_PHRASE
echo
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Генерация файла config.json...${RESET}"
cat <<EOF > config.json
{
  "wallet": {
    "addressKeyName": "test",
    "addressRestoreMnemonic": "$WALLET_SEED_PHRASE",
    "alloraHomeDir": "",
    "gas": "1000000",
    "gasAdjustment": 1.0,
    "nodeRpc": "https://sentries-rpc.testnet-1.testnet.allora.network/",
    "maxRetries": 1,
    "delay": 1,
    "submitTx": true
  },
  "worker": [
    {
      "topicId": 1,
      "inferenceEntrypointName": "api-worker-reputer",
      "loopSeconds": 5,
      "parameters": {
        "InferenceEndpoint": "http://localhost:8000/inference/{Token}",
        "Token": "ETH"
      }
    },
    {
      "topicId": 1,
      "inferenceEntrypointName": "api-worker-reputer",
      "loopSeconds": 5,
      "parameters": {
        "InferenceEndpoint": "http://localhost:8000/inference/{Token}",
        "Token": "ETH"
      }
    }
  ]
}
EOF

echo -e "${BOLD}${DARK_YELLOW}Файл config.json успешно сгенерирован!${RESET}"
echo
mkdir worker-data
chmod +x init.config
sleep 2
./init.config

echo
echo -e "${BOLD}${UNDERLINE}${DARK_YELLOW}Сборка и запуск Docker контейнеров...${RESET}"
docker compose build
docker-compose up -d
echo
sleep 2
echo -e "${BOLD}${DARK_YELLOW}Проверка запущенных Docker контейнеров...${RESET}"
docker ps
echo
execute_with_prompt 'docker logs -f worker'
echo
