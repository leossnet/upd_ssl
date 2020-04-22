# upd_ssl
Скрипт обновления бесплатных SSL-сертификатов, таких как Let's Encrypt сроком действия 3 месяца, на облачных серверах [NetAngels.ru](https://www.netangels.ru/) под управлением [Ubuntu Server](https://ubuntu.com/download/server). Проект представляет собой доработку скрипта службы технической поддержки [NetAngels.ru](https://www.netangels.ru/).

Скрипт позволяет автоматизатировать процесс обновления SSL сертификатов, выпущенных через [панель управления NetAngels.ru](https://panel.netangels.ru/). Основную информацию скрипт пишет в свой лог `upd_ssl.log`. В скрипте используется [следующий API](https://api.netangels.ru/gateway/modules/gateway_api.api.certificates/#ssl). Скрипт проверен на `Ubuntu Server 14.04` и выше.

## Порядок установки и использования upd_ssl

1. Для работы необходимо установить пакет `jq`. Возможно, на Debian Wheezy этого пакета нет, тогда его нужно взять из бэкпортов (тогда нужно раскомментировать первую строку):
```
#sudo echo "deb http://ftp.de.debian.org/debian wheezy-backports main contrib non-free" >> /etc/apt/source.list
sudo apt-get update 
sudo apt-get install -y jq
```

2. Скачиваем архив в домашнюю директорию пользователя:
```
cd ~
git clone https://github.com/leossnet/upd_ssl.git
cd upd_ssl
```

3. В файле `api_key.txt` добавляем ключ доступа к API, который предварительно копируем в буфер обмена [отсюда](https://panel.netangels.ru/account/api/) (в следующей команде приведет условный ключ):
```
echo "Z9wHn3wVX7h6cUa9K8tGnJtkRUTeoqmBlqfHo8L1udZpwGfkHxbxM3ZW" >> api_key.txt
```

4. В файле `domains.txt` добавляем список доменов вида `id:domain`, которые будем чекать. id берем из url в разделе [SSL-сертификаты](https://panel.netangels.ru/certificates/#/) панели управления, например:
```
12345:mydomain.ru
23456:mydomain.com
```


5. К web-серверу прокидываем симлинк. При наличии удаляем имеющуюся папку с сертификатами `/etc/nginx/ssl` (нужно расскоментировать первую строку):
```
#sudo rm -R /etc/nginx/ssl
sudo ln -s ~/upd_ssl/ssl /etc/nginx 
```

6. Запускаем первый раз скрипт командой. Смотрим вывод на наличие каких-либо ошибок, проверяем директорию `/ssl` на наличие сертификатов (команда `bash -x` выводит на консоль подробный лог):
```
chmod 750 ./upd_ssl.sh
bash -x ./upd_ssl.sh
```

7. В crontab добавляем задание, где вместо `user1` подставляем реальное имя пользователя.
```
0 1 * * * /usr/bin/sudo -u user1 /home/user1/upd_ssl/upd_ssl.sh && nginx -s reload
```
### Примечания:
1. Задания `cron` прописываются в файле, который открывается командой `crontab -e`. Чтобы можно было редактировать этот файл в `Midnight Commander`, нужно выполнить комманду `select-editor` и выбрать из списка `/usr/bin/mcedit`.

2. На серверах [Ubuntu](https://ubuntu.com/download/server) логи `cron` выводятся в общий системный лог `/var/log/syslog`, что затрудняет поиск ошибок при отладке. Рекомендуется выделить для `cron` отдельных лог, для чего в файле /`etc/rsyslog.d/50-default.conf`, предварительно выполнив `sudo su`, нужно раскомментировать строку `#cron.*         /var/log/cron.log`, после  чего перезапустить службы:
```
sudo service rsyslog restart
sudo service cron restart
```