#cloud-config
package_upgrade: true
packages:
    - apache2
    - mysql-server
    - php
    - php-mysql
    - libapache2-mod-php
    - php-curl
    - php-gd
    - php-intl
    - php-mbstring
    - php-soap
    - php-xml
    - php-xmlrpc
    - php-zip
    - sshpass

runcmd:
    - sleep 120
    - export MASTER_BINLOG=$(cat /tmp/master-mysql.txt | grep binlog | awk '{print $1}')
    - export MASTER_POS=$(cat /tmp/master-mysql.txt | grep binlog | awk '{print $2}')
    - systemctl enable mysql --now
    - systemctl restart mysql
    - mysql -e "create database wordpress;"
    - mysql -e "create user '${wpadmin_username}'@'localhost' identified by '${wpadmin_password}';"
    - echo "Granting database privileges on wordpress..."
    - mysql -e "grant all privileges on wordpress.* to ${wpadmin_username}@'localhost';"
    - mysql -e "create user '${db_replica_user}'@'localhost' identified by '${db_replica_pass}';"
    - echo "Granting replication privileges..."
    - mysql -e "grant all privileges on wordpress.* to '${db_replica_user}'@'localhost';"
    - mysql wordpress < /tmp/wordpress.sql
    - mysql -e "change master to GET_MASTER_PUBLIC_KEY=1, master_log_file='$MASTER_BINLOG', master_log_pos=$MASTER_POS, master_host = '${master_ip}', master_user = '${db_replica_user}', master_password = '${db_replica_pass}', master_port = 3306;"
    - mysql -e "start slave;"

    - rm -f /var/www/html/index.html
    - wget -P /tmp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    - chmod +x /tmp/wp-cli.phar 
    - cd /var/www/html && /tmp/wp-cli.phar core download --allow-root
    - /tmp/wp-cli.phar config create --dbname=wordpress --dbuser=${db_replica_user} --dbpass=${db_replica_pass} --locale=en_DB --allow-root
    - systemctl restart mysql
    

    - sed -i -e 's/# server-id.*/server-id = 2/g' -e 's/^bind-address.*/bind-address = ${server_ip}/g' /etc/mysql/mysql.conf.d/mysqld.cnf
    - sed -i -e '/bind-address = ${server_ip}/i binlog_do_db=wordpress' /etc/mysql/mysql.conf.d/mysqld.cnf

    - chown -R www-data:www-data /var/www/html/
    - a2enmod rewrite
    - systemctl enable apache2 --now
    - systemctl restart apache2
    - systemctl restart mysql
    - |
        cat >> /etc/apache2/apache2.cfg << EOF
        <Directory /var/www/html>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
        EOF

    
