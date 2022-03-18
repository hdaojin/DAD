#!/bin/bash
# Author: hdaojin
# Description: Setup script for the project
# usage: bash script/setup.sh

# set running environment
# unset LANG
# export LANG=en_US.UTF-8

red_front="\033[31m"
green_front="\033[32m"
yellow_front="\033[33m"
blue_front="\033[34m"
behind="\033[0m"
echo_success="${green_front}[successfully]${behind}"
echo_failure="${red_front}[failed]${behind}"
echo_warning="${yellow_front}[warning]${behind}"
echo_notice="${blue_front}[notice]${behind}"

# set variables
django_auto="django-auto" #  DON'T CHANGE THIS
current_user=$(whoami)
web_user="www-data" # DON'T CHANGE THIS

django_config_dir="/etc/django"
sql_config_file="my.cnf"
secret_key_file="secret_key.txt"
django_config_file="django.conf"

# Install system packages
install_system_packages() {
    echo -e "$green_front Installing system packages...$behind"
    sudo apt update
    sudo apt install -y git
    sudo apt install -y python3-pip python3-venv
    sudo apt install -y mariadb-server mariadb-client
    sudo apt install -y python3-dev default-libmysqlclient-dev build-essential
    sudo apt install -y nginx
    sudo apt install -y uwsgi uwsgi-plugin-python3
    sudo apt install -y snapd
    sudo snap install core
    sudo snap refresh core
    sudo apt remove -y certbot
    sudo snap install --classic certbot
    [ -L /usr/bin/certbot ] || sudo ln -s /snap/bin/certbot /usr/bin/certbot
    echo -e "$echo_success Installing system packages successfully"
}

# Install python packages
install_python_packages() {
    echo -e "$green_front Installing python packages...$behind"
    cd $(dirname $project_path) && python3 -m venv .venv && source .venv/bin/activate && find . -iname "requirements.txt" -exec pip install -r {} \; && deactivate || exit 1
    echo -e "$echo_success Installing python packages successfully"
}

# secret_key
genarate_secret_key() {
    echo -e "$green_front Generating secret_key...$behind"
    python3 -c "import secrets; print(secrets.token_urlsafe())" | sudo tee $django_config_dir/$secret_key_file >/dev/null
    echo -e "$echo_success Generating secret_key successfully"
}

# mysql
configure_mysql() {
    echo -e "$green_front Configuring mysql...$behind"
    read -p "DATABASE_NAME: " dbname
    read -p "DATABASE_USER: " dbuser
    until [ -n "$dbpass" ] && [ $dbpass == $dbpass2 ]; do
        read -sp "DATABASE_PASSWORD: " dbpass
        echo
        read -sp "DATABASE_PASSWORD(confirm): " dbpass2
        echo
        if [ $dbpass != $dbpass2 ]; then
            echo -e "$echo_failure The two passwords are different"
        fi
    done

    sudo systemctl status mariadb.service >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        sudo systemctl start mariadb.service || exit 1
        sudo systemctl enable mariadb.service
    fi

    sudo mariadb -e "SHOW DATABASES;" | grep -q -w $dbname
    if [ $? -ne 0 ]; then
        sudo mariadb -e "CREATE DATABASE $dbname;"
    fi
    sudo mariadb -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
    sudo mariadb -e "FLUSH PRIVILEGES;"

    sudo cp -f $django_auto_dir/deploy/django/$sql_config_file $django_config_dir/$sql_config_file

    sudo sed -i "s/dbname/$dbname/g" $django_config_dir/$sql_config_file
    sudo sed -i "s/dbuser/$dbuser/g" $django_config_dir/$sql_config_file
    sudo sed -i "s/dbpass/$dbpass/g" $django_config_dir/$sql_config_file
    echo -e "$echo_success Configuring mysql successfully"
}

# ssl cert
genarate_ssl_cert() {
    echo -e "$green_front Generating ssl cert...$behind"
    if [ $deploy_env -eq 1 ]; then
        if [ -z $subdomain ]; then
            sudo certbot certonly --cert-name $domain -d $domain --email hdaojin@hotmail.com --agree-tos --nginx -n --force-renewal || exit 1
        else
            sudo certbot certonly --cert-name $domain -d $domain -d $subdomain --email hdaojin@hotmail.com --agree-tos --nginx -n --force-renewal || exit 1
        fi
    else
        if [ -e /etc/nginx/ssl ]; then
            sudo rm -rf /etc/nginx/ssl/*
        else
            sudo mkdir /etc/nginx/ssl
        fi
        sudo openssl req -new -x509 -nodes -days 365 -keyout /etc/nginx/ssl/$domain.key -out /etc/nginx/ssl/$domain.crt -subj "/C=CN/ST=Guangdong/L=Guangzhou/O=ITNSA/OU=ITNSA/CN=$domain"
    fi
    echo -e "$echo_success Generating ssl cert successfully"
}

# nginx config
configure_nginx() {
    echo -e "$green_front Configuring nginx...$behind"
    sudo tar -czf /etc/nginx/nginx_$(date +%F_%H-%M-%S).tar.gz /etc/nginx/nginx.conf /etc/nginx/sites-available/ /etc/nginx/sites-enabled/ /etc/nginx/conf.d/
    sudo rm -rf /etc/nginx/sites-available/*
    sudo rm -rf /etc/nginx/sites-enabled/*
    sudo rm -rf /etc/nginx/custom
    sudo cp -f $django_auto_dir/deploy/nginx/nginx.conf /etc/nginx/nginx.conf
    sudo cp -f $django_auto_dir/deploy/nginx/sites-available/default /etc/nginx/sites-available/default
    if [ ! -L /etc/nginx/sites-enabled/default ]; then
        sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    fi
    sudo cp -f $django_auto_dir/deploy/nginx/sites-available/mysite.conf /etc/nginx/sites-available/$domain.conf
    sudo sed -i "s/mysite/$domain/g" /etc/nginx/sites-available/$domain.conf
    if [ ! -L /etc/nginx/sites-enabled/$domain.conf ]; then
        sudo ln -s /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
    fi
    sudo cp -f -r $django_auto_dir/deploy/nginx/custom /etc/nginx/
    echo "set \$static_root $static_dir;" | sudo tee /etc/nginx/custom/set.conf >/dev/null
    echo "set \$media_root $media_dir;" | sudo tee -a /etc/nginx/custom/set.conf > /dev/null
    if [ $deploy_env -eq 1 ]; then
        sudo sed -i "s#ssl_certificate .*#ssl_certificate  /etc/letsencrypt/live/$domain/fullchain.pem;#g" /etc/nginx/custom/ssl.conf
        sudo sed -i "s#ssl_certificate_key .*#ssl_certificate_key  /etc/letsencrypt/live/$domain/privkey.pem;#g" /etc/nginx/custom/ssl.conf
    else
        sudo sed -i "s#ssl_certificate .*#ssl_certificate  /etc/nginx/ssl/$domain.crt;#g" /etc/nginx/custom/ssl.conf
        sudo sed -i "s#ssl_certificate_key .*#ssl_certificate_key  /etc/nginx/ssl/$domain.key;#g" /etc/nginx/custom/ssl.conf
    fi

    echo -e "$echo_success Configuring nginx successfully"
}

# uwsgi config
configure_uwsgi() {
    echo -e "$green_front Configuring uwsgi...$behind"
    sudo rm -rf /etc/uwsgi/apps-available/*
    sudo rm -rf /etc/uwsgi/apps-enabled/*
    sudo cp -f $django_auto_dir/deploy/uwsgi/mysite.ini /etc/uwsgi/apps-available/$domain.ini
    sudo sed -r -i "s;^basedir {1,}=.*;basedir = $(dirname $project_path);g" /etc/uwsgi/apps-available/$domain.ini
    sudo sed -r -i "s;^project {1,}=.*;project = $project;g" /etc/uwsgi/apps-available/$domain.ini
    if [ ! -L /etc/uwsgi/apps-enabled/$domain.ini ]; then
        sudo ln -s /etc/uwsgi/apps-available/$domain.ini /etc/uwsgi/apps-enabled/$domain.ini
    fi
    echo -e "$echo_success Configuring uwsgi successfully"
}

# django settings
set_django_settings() {
    echo -e "$green_front configure django settings...$behind"
    sudo cp -f $django_auto_dir/deploy/django/$django_config_file  $django_config_dir/$django_config_file
    sudo sed -i "s;StaticRoot.*;StaticRoot = $static_dir;g"  $django_config_dir/$django_config_file
    sudo sed -i "s;MediaRoot.*;MediaRoot = $media_dir;g"  $django_config_dir/$django_config_file
    echo -e "$echo_success configure django settings successfully"
}

# static files
collect_static_files() {
    echo -e "$green_front Collecting static files...$behind"
    [ -e $static_dir ] || sudo mkdir -p $static_dir 
    sudo chown $current_user:$web_user $static_dir
    [ -e $media_dir ] || sudo mkdir -p $media_dir 
    sudo chown $current_user:$web_user $media_dir
    
    source $(dirname $project_path)/.venv/bin/activate
    cd $project_path && python3 manage.py collectstatic --noinput && deactivate || exit 1
    echo -e "$echo_success Collecting static files successfully"
}

restart_service() {
    echo -e "$green_front Restarting services...$behind"
    for service in mariadb uwsgi nginx; do
        sudo systemctl restart $service || exit 1
        sudo systemctl enable $service || exit 1
    done
    echo -e "$echo_success Restarting services successfully"
}

usage() {
    cat <<EOF
    Usage: $0 [options]... [arguments]...
    Automatically deploy Django projects on the Linux server.

    Options:
        -h                  show this help message and exit
        -p  dir             absolute path of django project  
                            (manage.py is located, begin with "/")
        -s  static_root     absolute path of STATIC_ROOT for production
                            (default: /var/www/your_domain/static begin with "/")
        -m  media_root     absolute path of MEDIA_ROOT for production
                            (default: /var/www/your_domain/media begin with "/")

    Examples:
        $0 -p /home/demo/django_project/mysite
        $0 -p /home/demo/django_project/mysite -s /var/www/mysite/static -m /var/www/mysite/media
EOF
}

# main
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

while getopts "hp:s:m:" opt; do
    case $opt in
    h)
        usage
        exit 0
        ;;
    p)
        echo $OPTARG | grep -q '^/'
        if [ $? -eq 0 ]; then
            project_path=$OPTARG
        else
            echo -e "$red_front Please specify the absoute path of django-project $behind"
            exit 1
        fi
        ;;
    s)
        echo $OPTARG | grep -q '^/'
        if [ $? -eq 0 ]; then
            static_dir=$OPTARG
        else
            echo -e "$red_front Please specify the absoute path of static file directory $behind"
            exit 1
        fi
        ;;
    m)
        echo $OPTARG | grep -q '^/'
        if [ $? -eq 0 ]; then
            media_dir=$OPTARG
        else
            echo -e "$red_front Please specify the absoute path of media file directory $behind"
            exit 1
        fi
        ;;

    \?)
        usage
        exit 1
        ;;
    esac
done

if [ -z $project_path ]; then
    echo -e "$red_front Please specify the absoute path of django-project $behind"
    exit 1
else
    if [ -e $project_path/manage.py ]; then
        project=$(basename $project_path)
    else
        echo -e "$red_front The absoute path of django-project is wrong. Must manage.py is located $behind"
        exit 1
    fi
fi

django_auto_dir="$PWD"
if [ ! -f $django_auto_dir/script/setup.sh ]; then
    echo -e "$echo_warning Please change the directory to $django_auto"
    exit 1
fi

echo -e "The django project will be deployed on the $blue_front TEST $behind or $blue_front PRODUCT $behind environment?"
select envrionment in "TEST" "PRODUCT"; do
    case $envrionment in
    TEST)
        let deploy_env=0
        break
        ;;
    PRODUCT)
        let deploy_env=1
        break
        ;;
    *)
        echo "Please select the correct environment"
        ;;
    esac
done

read -p "Please enter the domain name(FQDN or IP): " domain
if [ -z $domain ]; then
    echo -e "$red_front Please enter the domain name $behind"
    exit 1
else
    echo "$domain" | grep -qE "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
    if [ $? -ne 0 ]; then
        echo "$domain" | grep -q '^www\.'
        if [ $? -ne 0 ]; then
            read -p "Please enter the subdomain name(Default: www.$domain): " subdomain
            [ -z $subdomain ] && subdomain=www.$domain
        fi
    fi
fi

[ -z $static_dir ] && static_dir="/var/www/$domain/static"
[ -z $media_dir ] && media_dir="/var/www/$domain/media"

if [ -d $django_config_dir ]; then
    for i in install_system_packages \
        install_python_packages \
        genarate_secret_key \
        configure_mysql \
        genarate_ssl_cert; do
        read -p "$(echo -e $echo_notice) Do you want to $i?(y/n): " choice
        case $choice in
        y | Y)
            $i
            ;;
        n | N)
            echo -e "$blue_front Skipping $i $behind"
            ;;
        *)
            echo -e "$red_front Please select the correct choice $behind"
            exit 1
            ;;
        esac
    done
    configure_nginx
    configure_uwsgi
    set_django_settings
    collect_static_files
    restart_service
else
    sudo mkdir $django_config_dir
    install_system_packages
    install_python_packages
    genarate_secret_key
    configure_mysql
    genarate_ssl_cert
    configure_nginx
    configure_uwsgi
    set_django_settings
    collect_static_files
    restart_service
fi
