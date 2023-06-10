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
    - wget -P /tmp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    - chmod +x /tmp/wp-cli.phar 
    - cd /var/www/html && sudo -u www-data -i -- /tmp/wp-cli.phar core download
    - sudo -u www-data -i -- /tmp/wp-cli.phar config create --dbname=wordpress --dbuser=${wpadmin_username} --dbpass=${wpadmin_password} --locale=en_DB
    - sudo -u www-data -i -- wp-cli core install --url=lukagalic.studenti.itedu.hr --title=Test1 --admin_user=test --admin-password=test --admin_email=soc@soc.com
    - systemctl enable mysql --now
    - systemctl restart mysql

    - mysql -e "create database wordpress;"
    - mysql -e "create user '${wpadmin_username}'@'localhost' identified by '${wpadmin_password}';"
    - echo "Granting database privileges on wordpress..."
    - mysql -e "grant all privileges on wordpress.* to ${wpadmin_username}@'localhost';"
    - mysql -e "create user '${db_replica_user}'@'${slave_ip}' identified by '${db_replica_pass}';"
    - echo "Granting replication privileges..."
    - mysql -e "grant replication slave on *.* to ${db_replica_user}@'${slave_ip}';"
    - mysql -e "flush privileges; use wordpress; flush tables with read lock;"
    
    - sed -i -e 's/# server-id/server-id/g' -e 's/^bind-address.*/bind-address = ${server_ip}/g' /etc/mysql/mysql.conf.d/mysqld.cnf
    - sed -i '/bind-address = ${server_ip}/i binlog_do_db=wordpress' /etc/mysql/mysql.conf.d/mysqld.cnf

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