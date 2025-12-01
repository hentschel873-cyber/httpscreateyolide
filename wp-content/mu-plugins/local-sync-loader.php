<?php
/**
 * MU loader for Local Sync - ensures plugin is loaded in this local Studio environment
 */

if ( ! defined( 'ABSPATH' ) ) {
    return;
}

// Resolve plugin relative to this mu-plugins directory (works with Studio installs)
$plugin = dirname(__FILE__) . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . 'plugins' . DIRECTORY_SEPARATOR . 'local-sync' . DIRECTORY_SEPARATOR . 'local-sync.php';
if ( file_exists( $plugin ) ) {
    require_once $plugin;
}

// REST pre-dispatch verifier for local-sync endpoint.
// Implementation is factored into small helpers to reduce complexity for linters.
if ( ! function_exists( 'localSyncGetAuthHeader' ) ) {
    function localSyncGetAuthHeader() {
        $ret = '';
        if ( isset( $_SERVER['HTTP_AUTHORIZATION'] ) ) {
            $ret = $_SERVER['HTTP_AUTHORIZATION'];
        } elseif ( isset( $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ) ) {
            $ret = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        } else {
            if ( function_exists( 'getallheaders' ) ) {
                $h = getallheaders();
                if ( isset( $h['Authorization'] ) ) { $ret = $h['Authorization']; }
                elseif ( isset( $h['authorization'] ) ) { $ret = $h['authorization']; }
            }
        }
        return $ret;
    }
}

if ( ! function_exists( 'localSyncVerifyToken' ) ) {
    function localSyncVerifyToken( $result, $request ) {
        $route = $request->get_route();
        // Only validate the specific local-sync route
        if ( false === strpos( $route, '/local-sync/v1/sync' ) ) {
            return $result;
        }

        $error = null;
        $auth   = localSyncGetAuthHeader();
        if ( ! $auth || ! preg_match( '/Bearer\s+(.*)$/i', $auth, $m ) ) {
            $error = new WP_Error( 'rest_forbidden', 'Missing or invalid Authorization header', array( 'status' => 401 ) );
        } else {
            $token = $m[1];
            $expected = getenv( 'WP_LOCAL_SYNC_SECRET' );
            if ( ! $expected && defined( 'WP_LOCAL_SYNC_SECRET' ) ) {
                $expected = WP_LOCAL_SYNC_SECRET;
            }
            if ( ! $expected || ! hash_equals( $expected, $token ) ) {
                $error = new WP_Error( 'rest_forbidden', 'Invalid token', array( 'status' => 401 ) );
            }
        }

        return $error ? $error : $result;
    }
}

add_filter( 'rest_pre_dispatch', 'localSyncVerifyToken', 10, 2 );
