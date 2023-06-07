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
    - wget -c https://wordpress.org/latest.tar.gz -P /tmp
    - tar -xvzf /tmp/latest.tar.gz -C /var/www/html/
    - cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
    - sed -i "s/database_name_here/wordpress/g" /var/www/html/wordpress/wp-config.php
    - sed -i "s/username_here/wp-admin/g" /var/www/html/wordpress/wp-config.php
    - sed -i "s/password_here/Pa$$w0rd/g" /var/www/html/wordpress/wp-config.php
    - chown -R www-data:www-data /var/www/html/wordpress
    - chmod -R 755 /var/www/html/wordpress
    - systemctl enable apache2 --now
    - systemctl enable mysql --now