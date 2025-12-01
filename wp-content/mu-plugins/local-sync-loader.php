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
        // Only validate the specific local-sync route (exact match or sub-paths)
        if ( 1 !== preg_match( '#^/local-sync/v1/sync(?:/.*)?$#', $route ) ) {
            return $result;
        }

        $error = null;
        $auth   = localSyncGetAuthHeader();

        // Optional debug flag (env or constant) to enable error logging for auth failures
        $debug = getenv( 'WP_LOCAL_SYNC_DEBUG' );
        if ( ! $debug && defined( 'WP_LOCAL_SYNC_DEBUG' ) ) {
            $debug = WP_LOCAL_SYNC_DEBUG;
        }

        if ( ! $auth || ! preg_match( '/Bearer\s+(.*)$/i', $auth, $m ) ) {
            $error = new WP_Error( 'rest_forbidden', 'Missing or invalid Authorization header', array( 'status' => 401 ) );
        } else {
            $token = trim( $m[1] );
            $expected = getenv( 'WP_LOCAL_SYNC_SECRET' );
            if ( ! $expected && defined( 'WP_LOCAL_SYNC_SECRET' ) ) {
                $expected = WP_LOCAL_SYNC_SECRET;
            }
            if ( ! $expected || ! hash_equals( $expected, $token ) ) {
                $error = new WP_Error( 'rest_forbidden', 'Invalid token', array( 'status' => 401 ) );
            }
        }

        if ( $error && $debug ) {
            $ip = isset( $_SERVER['REMOTE_ADDR'] ) ? $_SERVER['REMOTE_ADDR'] : 'unknown';
            error_log( sprintf( 'local-sync auth failed: route=%s, has_auth=%s, ip=%s', $route, $auth ? 'yes' : 'no', $ip ) );
        }

        return $error ? $error : $result;
    }
}

add_filter( 'rest_pre_dispatch', 'localSyncVerifyToken', 10, 2 );
