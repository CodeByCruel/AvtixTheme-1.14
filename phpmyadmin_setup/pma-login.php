<?php

$session_name = 'PMA_signon_session';

session_set_cookie_params(0, '/', '', false, true);
session_name($session_name);
session_start();


if (isset($_GET['username']) && isset($_GET['password'])) {
    
    $_SESSION['PMA_single_signon_user'] = $_GET['username'];
    $_SESSION['PMA_single_signon_password'] = $_GET['password'];
    
    if (isset($_GET['server'])) {
        $_SESSION['PMA_single_signon_host'] = $_GET['server'];
    }
    
    if (isset($_GET['port'])) {
        $_SESSION['PMA_single_signon_port'] = $_GET['port'];
    }
    
    $redirect_url = './index.php';
    if (isset($_GET['db'])) {
        $redirect_url .= '?db=' . urlencode($_GET['db']);
    }
    
    header('Location: ' . $redirect_url);
    exit;
} else {
    echo "No credentials provided for auto-login.";
}
