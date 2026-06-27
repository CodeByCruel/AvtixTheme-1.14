
This directory contains the necessary files and instructions to enable auto-login for phpMyAdmin with the Hyper Theme.



Copy the included `pma-login.php` file to your phpMyAdmin installation directory (typically `/var/www/phpmyadmin`).

```bash
cp pma-login.php /var/www/phpmyadmin/
chown www-data:www-data /var/www/phpmyadmin/pma-login.php
chmod 644 /var/www/phpmyadmin/pma-login.php
```

Edit your `/var/www/phpmyadmin/config.inc.php` file and update the authentication configuration for your server.

```php
$cfg['Servers'][$i]['auth_type'] = 'cookie';
```

```php
$cfg['Servers'][$i]['auth_type'] = 'signon';
$cfg['Servers'][$i]['SignonSession'] = 'PMA_signon_session';
$cfg['Servers'][$i]['SignonURL'] = 'pma-login.php';
```

In your Pterodactyl Panel:
1.  Go to **Admin Panel** > **Theme Settings** > **Database Manager Configuration**.
2.  Set the **phpMyAdmin URL** to:
    ```
    https://<YOUR_DOMAIN>/pma-login.php?server={host}&port={port}&username={username}&password={password}&db={database}
    ```

