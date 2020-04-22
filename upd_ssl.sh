#!/bin/bash -eu

declare -r BASE_DIR=$(dirname $(realpath $0))
declare -r API_KEY_FILE=${BASE_DIR}'/api_key.txt'
declare -r TMP_DIR="$(mktemp -du)"
declare -r DOMAINS_FILE=${BASE_DIR}'/domains.txt'
declare -r ARCHIVE_DIR=$(echo $(date +%Y-%m-%d))
declare -r LOG_FILE=${BASE_DIR}/upd_ssl.log
STATUS=1

function logger()
{
    echo "["$(date "+%Y-%m-%d %H:%M:%S")"] $1" >> ${LOG_FILE}
}

if [[ -e $API_KEY_FILE ]]; then
    API_KEY=$(cat ${API_KEY_FILE} | grep -v "#")
else 
    logger "Файл ключа API не найден. Пропускаем."
    exit ${STATUS}
fi

TOKEN=$(curl -s -k -X POST -d "api_key=${API_KEY}" 'https://panel.netangels.ru/api/gateway/token/' | jq -r '.token')
if [[ "${TOKEN}" = $(echo "null") ]]; then
    logger "Ключ API не действующий. Пропускаем."
    exit ${STATUS}
fi

for STRING in $(cat ${DOMAINS_FILE} | grep -v "#"); do
    DOMAIN=$(echo ${STRING} | cut -d":" -f2)
    ID=$(echo ${STRING} | cut -d":" -f1)

    FULL_INFO=$(curl -s -k -H "Authorization: Bearer ${TOKEN}" -X GET "https://api-ms.netangels.ru/api/v1/certificates/${ID}/" | jq .)

    STATE=$(echo ${FULL_INFO} | jq '.state')
    [[ "${STATE}" = "\"Issued\""  ]] || {
        logger "Сертификат с id:${ID} для домена ${DOMAIN} не найден. Пропускаем."
        continue
    }

    mkdir -p ${TMP_DIR}/${ID}_${DOMAIN}
    mkdir -p ${BASE_DIR}/ssl/

    cd ${TMP_DIR}/${ID}_${DOMAIN}
    NAME=$(echo ${FULL_INFO} | jq .domains | jq .[0] | tr -d \" | sed -e 's|*|_|g' | sed -e 's|\.|_|g')
    curl -s -k -H "Authorization: Bearer ${TOKEN}" -X GET "https://api-ms.netangels.ru/api/v1/certificates/${ID}/download/?name=${NAME}&type=tar" > ${NAME}.tar

    [[ -f ${NAME}.tar ]] && {
        tar -xf ${NAME}.tar
        rm -f ${NAME}.tar;
    } || {
        logger "Не смогли получить ${name}.tar для домена ${DOMAIN}. Пропускаем."
        continue
    }

    CRT_OLD="${BASE_DIR}/ssl/${NAME}.crt"
    [[ -f ${CRT_OLD} ]] || touch ${CRT_OLD}
    CRT_NEW="${TMP_DIR}/${ID}_${DOMAIN}/${NAME}.crt"
    diff -q "${CRT_OLD}" "${CRT_NEW}" && {
        logger "Сертификат для домена ${DOMAIN} не требует обновлений. Пропускаем."
        continue
    } || logger "Обнаружен новый сертификат сертификат для домена ${DOMAIN}. Обновляем"

    [[ -s ${CRT_OLD} ]] && {
        mkdir -p ${BASE_DIR}/ssl/${ARCHIVE_DIR}
        mv ${BASE_DIR}/ssl/${NAME}.* ${BASE_DIR}/ssl/${ARCHIVE_DIR}/
    }

    mv ${TMP_DIR}/${ID}_${DOMAIN}/* ${BASE_DIR}/ssl/

    STATUS=0
done

rm -rf ${TMP_DIR}

exit ${STATUS}
