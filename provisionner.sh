#!/bin/bash

export PATH="$PATH:/home/$(whoami)/.local/"

username="YOUR_USERNAME_HERE"
default_password="YOUR_PASSWORD_HERE" # can also use envvars

dns_name="tp-dns-mac-fb"
web_name="tp-nginx-mac-fb"

dns_ip="192.168.10.201"
web_ip="192.168.10.202"


capenssl_path="./capen-ssl"


### Génératio de la PKI
echo "--- Génération de la PKI---"

cd $capenssl_path

echo "Purge de ce qui existe déjà"
./scripts/clean-database
./scripts/clean-files
./scripts/clean-values

echo "Génération de l'autorité racine"
./build-certs --country FR --province 'Ile-de-France' --locality Paris --organization 'IPSSI' --unit 'TP Hardening' --domain 'TP Hardening ROOT CA' --days 3650 --root

echo "Génération de l'autorité intermédiaire et signature par l'autorité racine"
./build-certs --country FR --province 'Ile-de-France' --locality Paris --organization 'IPSSI' --unit 'TP Hardening' --domain 'TP Hardening INTERMEDIAITE CA' --days 1825 --intermediate

echo "Génération des certificats serveurs et signature par l'autorité intermédiaire"
./build-certs --country FR --province 'Ile-de-France' --locality Paris --organization 'IPSSI' --unit 'TP Hardening' --domain 'website1.hardening.lan' --days 365 --server
./build-certs --country FR --province 'Ile-de-France' --locality Paris --organization 'IPSSI' --unit 'TP Hardening' --domain 'website2.hardening.lan' --days 365 --server
./build-certs --country FR --province 'Ile-de-France' --locality Paris --organization 'IPSSI' --unit 'TP Hardening' --domain 'website3.hardening.lan' --days 365 --server

echo "Concaténation des autorités"
cat ./out/ca/certs/rootca.crt ./out/ca/certs/intca.crt > ./out/ca/certs/hardening_fullchain.pem

echo "--- PKI générée ! ---"
cd ../

echo "Génération de la clé SSH"
ssh-keygen -N '' -q -t ed25519 -f ./id_ed25519


echo "Il faut maintenant déployer la VM DNS depuis le template, et lui attribuer l'IP $dns_ip"
read -p "Appuyer sur 'entrée' lorsque c'est fait"

echo "Copie de la clé SSH sur le serveur DNS"
ssh-copy-id -i "$(pwd)/id_ed25519.pub" $dns_name 

echo "Exécution du playbook ansible de configuration DNS"
ansible-playbook "./2-dns.yml" -i inventory.ini --extra-vars "ansible_sudo_pass=$default_password"

echo "Il faut maintenant déployer la VM WEB depuis le template, et lui attribuer l'IP $web_ip"
read -p "Appuyer sur 'entrée' lorsque c'est fait"

echo "Copie de la clé SSH sur le serveur web"
ssh-copy-id -i "$(pwd)/id_ed25519.pub" $web_name 

echo "Exécution du playbook ansible de configuration Nginx"
ansible-playbook "./3-web.yml" -i inventory.ini --extra-vars "ansible_sudo_pass=$default_password"
