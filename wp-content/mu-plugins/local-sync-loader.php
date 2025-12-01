<?php
/**
 * MU-Loader für Local Sync - stellt sicher, dass das Plugin in dieser lokalen Studio-Umgebung geladen wird
 */

if ( ! defined( 'ABSPATH' ) ) {
    return;
}

// Resolve plugin relative to this mu-plugins directory (works with Studio installs)
$plugin = dirname(__FILE__) . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . 'plugins' . DIRECTORY_SEPARATOR . 'local-sync' . DIRECTORY_SEPARATOR . 'local-sync.php';
if ( file_exists( $plugin ) ) {
    require_once $plugin;
}

// REST Pre-Dispatch-Prüfer für den Local-Sync-Endpunkt.
// Die Implementierung ist in kleine Helfer ausgelagert, um die Komplexität für Linter gering zu halten.
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
        // Nur die spezifische local-sync-Route (exakt oder Subpfade) prüfen
        if ( 1 !== preg_match( '#^/local-sync/v1/sync(?:/.*)?$#', $route ) ) {
            return $result;
        }

        $error = null;
        $auth   = localSyncGetAuthHeader();

        // Client-IP bestimmen (falls verfügbar)
        $ip = isset( $_SERVER['REMOTE_ADDR'] ) ? $_SERVER['REMOTE_ADDR'] : null;

        // Optionale IP-Whitelist: Kommagetrennte Liste (z.B. "127.0.0.1,192.0.2.0/24").
        // Wenn gesetzt, werden nur Anfragen von erlaubten IPs weiter geprüft.
        $whitelist = getenv( 'WP_LOCAL_SYNC_WHITELIST' );
        if ( ! $whitelist && defined( 'WP_LOCAL_SYNC_WHITELIST' ) ) {
            $whitelist = WP_LOCAL_SYNC_WHITELIST;
        }
        if ( $whitelist && $ip ) {
            $allowed = array_map( 'trim', explode( ',', $whitelist ) );
            $ip_allowed = false;
            foreach ( $allowed as $entry ) {
                if ( false !== strpos( $entry, '/' ) ) {
                    // CIDR-Unterstützung
                    list( $subnet, $mask ) = explode( '/', $entry, 2 );
                    if ( filter_var( $subnet, FILTER_VALIDATE_IP ) ) {
                        $ip_long     = sprintf( "%u", ip2long( $ip ) );
                        $subnet_long = sprintf( "%u", ip2long( $subnet ) );
                        $mask = (int) $mask;
                        if ( $mask >=0 && $mask <=32 ) {
                            $mask_long = $mask === 0 ? 0 : (~((1 << (32 - $mask)) - 1) & 0xFFFFFFFF);
                            if ( ( (int) $ip_long & $mask_long ) === ( (int) $subnet_long & $mask_long ) ) {
                                $ip_allowed = true;
                                break;
                            }
                        }
                    }
                } else {
                    if ( $entry === $ip ) {
                        $ip_allowed = true;
                        break;
                    }
                }
            }
            if ( ! $ip_allowed ) {
                // Optionales Debug-Logging
                $debug = getenv( 'WP_LOCAL_SYNC_DEBUG' );
                if ( ! $debug && defined( 'WP_LOCAL_SYNC_DEBUG' ) ) {
                    $debug = WP_LOCAL_SYNC_DEBUG;
                }
                if ( $debug ) {
                    error_log( sprintf( 'local-sync ip not allowed: ip=%s, route=%s', $ip, $route ) );
                }
                return new WP_Error( 'rest_forbidden', 'IP-Adresse nicht in der Whitelist', array( 'status' => 401 ) );
            }
        }

        // Einfaches Rate-Limit pro IP (Anfragen pro Minute)
        $rate_limit = getenv( 'WP_LOCAL_SYNC_RATE_LIMIT' );
        if ( ! $rate_limit && defined( 'WP_LOCAL_SYNC_RATE_LIMIT' ) ) {
            $rate_limit = WP_LOCAL_SYNC_RATE_LIMIT;
        }
        $rate_limit = $rate_limit ? intval( $rate_limit ) : 60; // Standard: 60 Anfragen/Minute
        if ( $ip && $rate_limit > 0 && function_exists( 'get_transient' ) ) {
            $transient_key = 'local_sync_rl_' . md5( $ip );
            $count = get_transient( $transient_key );
            if ( false === $count ) {
                set_transient( $transient_key, 1, 60 );
                $count = 1;
            } else {
                $count = intval( $count ) + 1;
                set_transient( $transient_key, $count, 60 );
            }
            if ( $count > $rate_limit ) {
                if ( getenv( 'WP_LOCAL_SYNC_DEBUG' ) || ( defined( 'WP_LOCAL_SYNC_DEBUG' ) && WP_LOCAL_SYNC_DEBUG ) ) {
                    error_log( sprintf( 'local-sync rate limit exceeded: ip=%s, count=%d, limit=%d', $ip, $count, $rate_limit ) );
                }
                return new WP_Error( 'rest_rate_limit', 'Rate-Limit überschritten', array( 'status' => 429 ) );
            }
        }

        // Optionale Debug-Flag (Umgebung oder Konstante) zur Aktivierung von Error-Logs
        $debug = getenv( 'WP_LOCAL_SYNC_DEBUG' );
        if ( ! $debug && defined( 'WP_LOCAL_SYNC_DEBUG' ) ) {
            $debug = WP_LOCAL_SYNC_DEBUG;
        }

        if ( ! $auth || ! preg_match( '/Bearer\s+(.*)$/i', $auth, $m ) ) {
            $error = new WP_Error( 'rest_forbidden', 'Fehlender oder ungültiger Authorization-Header', array( 'status' => 401 ) );
        } else {
            $token = trim( $m[1] );
            $expected = getenv( 'WP_LOCAL_SYNC_SECRET' );
            if ( ! $expected && defined( 'WP_LOCAL_SYNC_SECRET' ) ) {
                $expected = WP_LOCAL_SYNC_SECRET;
            }
            if ( ! $expected || ! hash_equals( $expected, $token ) ) {
                $error = new WP_Error( 'rest_forbidden', 'Ungültiges Token', array( 'status' => 401 ) );
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
