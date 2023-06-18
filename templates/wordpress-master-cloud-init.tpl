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
    - mysql -e "create database wordpress;"
    - mysql -e "create user '${wpadmin_username}'@'localhost' identified by '${wpadmin_password}';"
    - echo "Granting database privileges on wordpress..."
    - mysql -e "grant all privileges on wordpress.* to ${wpadmin_username}@'localhost';"
    - mysql -e "create user '${db_replica_user}'@'${slave_ip}' identified by '${db_replica_pass}';"
    - echo "Granting replication privileges..."
    - mysql -e "grant replication slave on *.* to ${db_replica_user}@'${slave_ip}';"
    - mysql -e "flush privileges; use wordpress; flush tables with read lock;"

    - rm -f /var/www/html/index.html
    - wget -P /tmp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    - chmod +x /tmp/wp-cli.phar 
    - cd /var/www/html && /tmp/wp-cli.phar core download --allow-root
    - /tmp/wp-cli.phar config create --dbname=wordpress --dbuser=${wpadmin_username} --dbpass=${wpadmin_password} --locale=en_DB --allow-root
    - /tmp/wp-cli.phar core install --url=lukagalic.studenti.itedu.hr --title=IRUO-Azure --admin_user=test --admin_password=test --admin_email=soc@soc.com --allow-root
    - systemctl enable mysql --now
    - systemctl restart mysql

    - mysqldump wordpress > /tmp/wordpress.sql

    - sed -i -e 's/# server-id/server-id/g' -e 's/^bind-address.*/bind-address = ${server_ip}/g' /etc/mysql/mysql.conf.d/mysqld.cnf
    - sed -i '/bind-address = ${server_ip}/i binlog_do_db=wordpress' /etc/mysql/mysql.conf.d/mysqld.cnf

    - chown -R www-data:www-data /var/www/html/
    - a2enmod rewrite
    - systemctl enable apache2 --now
    - systemctl restart apache2
    - systemctl restart mysql

    - mysql -e "show master status;" | awk '{print $1" "$2}' > /tmp/master-mysql.txt
    - rsync -avzh --rsh="sshpass -p ${admin_password} ssh -l ${admin_username} -o StrictHostKeyChecking=no" /tmp/master-mysql.txt ${slave_ip}:/tmp/
    - rsync -avzh --rsh="sshpass -p ${admin_password} ssh -l ${admin_username} -o StrictHostKeyChecking=no" /tmp/wordpress.sql ${slave_ip}:/tmp/
    - |
        cat >> /etc/apache2/apache2.cfg << EOF
        <Directory /var/www/html>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
        EOF

