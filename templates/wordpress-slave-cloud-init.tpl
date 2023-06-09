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

runcmd:
    - rm -f /var/www/html/index.html
    - wget -c https://wordpress.org/latest.tar.gz -P /tmp
    - tar --strip-components=1 -xvzf /tmp/latest.tar.gz -C /var/www/html/
    - cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

    - systemctl enable mysql --now
    - systemctl restart mysql
    - mysql -e "create database wordpress;"
    - mysql -e "create user '${wpadmin_username}'@'localhost' identified by '${wpadmin_password}';"
    - echo "Granting database privileges on wordpress..."
    - mysql -e "grant all privileges on wordpress.* to ${wpadmin_username}@'localhost';"
    - mysql -e "create user '${db_replica_user}'@'localhost' identified by '${db_replica_pass}';"
    - echo "Granting replication privileges..."
    - mysql -e "grant all privileges on wordpress.* to '${db_replica_user}'@'localhost';"
    - mysql -e "change master to master_host = '${master_ip}', master_user = '${db_replica_user}', master_password = '${db_replica_pass}', master_port = 3306;"

    
    - sed -i -e 's/# server-id.*/server-id = 2/g' -e 's/^bind-address.*/bind-address = ${server_ip}/g' /etc/mysql/mysql.conf.d/mysqld.cnf
    - sed -i -e '/bind-address = ${server_ip}/i binlog_do_db=wordpress' /etc/mysql/mysql.conf.d/mysqld.cnf

    - sed -i "s/database_name_here/wordpress/g" /var/www/html/wp-config.php
    - sed -i "s/username_here/${db_replica_user}/g" /var/www/html/wp-config.php
    - sed -i "s/password_here/${db_replica_pass}/g" /var/www/html/wp-config.php
    - chown -R www-data:www-data /var/www/html/
    - a2enmod rewrite
    - systemctl enable apache2 --now
    - systemctl restart apache2
    - systemctl restart mysql
    - |
        cat >> /var/www/html/wp-config.php << EOF
        /** Make sure WordPress understands it's behind an SSL terminator */
        define('FORCE_SSL_ADMIN', true);
        define('FORCE_SSL_LOGIN', true);
        if (\$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')
        \$_SERVER['HTTPS']='on';
        EOF
        cat >> /etc/apache2/apache2.cfg << EOF
        <Directory /var/www/html>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
        EOF

