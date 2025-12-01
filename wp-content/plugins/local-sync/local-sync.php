<?php
/**
 * Plugin Name: Local Sync (dev)
 * Description: Simple local sync endpoint for development. POST JSON to `/wp-json/local-sync/v1/sync` with header `X-Local-Sync-Key` or `?key=`.
 * Version: 0.1
 * Author: Assistant
 */

if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

add_action('rest_api_init', function() {
    register_rest_route('local-sync/v1', '/sync', array(
        'methods' => 'POST',
        'callback' => 'local_sync_handle_sync',
        'permission_callback' => '__return_true',
    ));
});

add_action('admin_menu', function() {
    add_options_page('Local Sync', 'Local Sync', 'manage_options', 'local-sync', 'local_sync_options_page');
});

add_action('admin_init', function() {
    register_setting('local_sync_options_group', 'local_sync_secret_key', array('sanitize_callback' => 'sanitize_text_field'));
    add_settings_section('local_sync_main_section', '', '__return_false', 'local-sync');
    add_settings_field('local_sync_secret_key', 'Secret key', 'local_sync_secret_key_field', 'local-sync', 'local_sync_main_section');
    register_setting('local_sync_options_group', 'local_sync_use_hmac', array('sanitize_callback' => 'absint'));
    add_settings_field('local_sync_use_hmac', 'Require HMAC signature', 'local_sync_use_hmac_field', 'local-sync', 'local_sync_main_section');
    register_setting('local_sync_options_group', 'local_sync_whitelist', array('sanitize_callback' => 'sanitize_textarea_field'));
    add_settings_field('local_sync_whitelist', 'IP whitelist (comma-separated)', 'local_sync_whitelist_field', 'local-sync', 'local_sync_main_section');
    register_setting('local_sync_options_group', 'local_sync_enable_file_log', array('sanitize_callback' => 'absint'));
    add_settings_field('local_sync_enable_file_log', 'Enable file logging', 'local_sync_enable_file_log_field', 'local-sync', 'local_sync_main_section');
});

function local_sync_secret_key_field() {
    $val = esc_attr( get_option('local_sync_secret_key', 'localdevsecret') );
    echo '<input type="text" name="local_sync_secret_key" value="' . $val . '" class="regular-text" />';
}

function local_sync_use_hmac_field() {
    $val = get_option('local_sync_use_hmac', 0) ? 'checked' : '';
    echo '<label><input type="checkbox" name="local_sync_use_hmac" value="1" ' . $val . ' /> Require HMAC-SHA256 signature header <code>X-Local-Sync-Signature</code></label>';
}

function local_sync_whitelist_field() {
    $val = esc_textarea( get_option('local_sync_whitelist', '') );
    echo '<textarea name="local_sync_whitelist" rows="3" class="large-text">' . $val . '</textarea>';
}

function local_sync_enable_file_log_field() {
    $val = get_option('local_sync_enable_file_log', 0) ? 'checked' : '';
    echo '<label><input type="checkbox" name="local_sync_enable_file_log" value="1" ' . $val . ' /> Append requests to upload-local-sync log</label>';
}

function local_sync_options_page() {
    if ( ! current_user_can('manage_options') ) {
        return;
    }
    ?>
    <div class="wrap">
        <h1>Local Sync (dev)</h1>
        <form method="post" action="options.php">
            <?php
            settings_fields('local_sync_options_group');
            do_settings_sections('local-sync');
            submit_button();
            ?>
        </form>
        <h2>Usage</h2>
        <p>POST JSON to <code>/wp-json/local-sync/v1/sync</code> with header <code>X-Local-Sync-Key</code> or <code>?key=</code>.</p>
    </div>
    <?php
}

function local_sync_get_key() {
    $key = get_option('local_sync_secret_key');
    if ( ! $key ) {
        // default for local development only — change this in production
        $key = 'localdevsecret';
    }
    return $key;
}

function local_sync_handle_sync( $request ) {
    $provided = '';
    $headers = $request->get_headers();
    if ( isset($headers['x-local-sync-key'][0]) ) {
        $provided = $headers['x-local-sync-key'][0];
    }
    if ( ! $provided ) {
        $params = $request->get_param('key');
        if ( $params ) {
            $provided = $params;
        }
    }
    // Support Authorization: Bearer <token> as an alternative to X-Local-Sync-Key
    if ( empty($provided) && isset($headers['authorization'][0]) ) {
        $authVal = trim($headers['authorization'][0]);
        if ( stripos($authVal, 'bearer ') === 0 ) {
            $provided = trim( substr($authVal, 7) );
        }
    }

    // Rate limiting: simple per-IP transient counter
    $remoteIp = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'unknown';
    $rl_key = 'local_sync_rl_' . md5($remoteIp);
    $rl_count = (int) get_transient($rl_key);
    $rl_count++;
    // allow 30 requests per minute per IP by default
    if ( $rl_count > 30 ) {
        return new WP_REST_Response(array('ok'=>false,'message'=>'rate_limited'), 429);
    }
    set_transient($rl_key, $rl_count, 60);

    // IP whitelist check
    $whitelist = get_option('local_sync_whitelist', '');
    if ( $whitelist ) {
        $allowed = array_map('trim', explode(',', $whitelist));
        $remote = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '';
        if ( $remote && ! in_array($remote, $allowed, true) ) {
            return new WP_REST_Response(array('ok'=>false,'message'=>'remote_not_allowed','remote'=>$remote), 403);
        }
    }

    // HMAC verification (optional)
    $use_hmac = get_option('local_sync_use_hmac', 0);
    $body = $request->get_body();
    if ( $use_hmac ) {
        $sigHeader = isset($headers['x-local-sync-signature'][0]) ? $headers['x-local-sync-signature'][0] : '';
        if ( empty($sigHeader) && isset($headers['authorization'][0]) ) {
            // Support sending the signature in the Authorization header (LocalSync <sig>) or raw signature
            $auth = trim($headers['authorization'][0]);
            if ( stripos($auth, 'localsync ') === 0 ) {
                $sigHeader = trim(substr($auth, 10));
            } else {
                $sigHeader = $auth;
            }
        }
        // Also accept signature in query param for environments that strip custom headers
        if ( empty($sigHeader) ) {
            $q = $request->get_param('sig');
            if ( $q ) {
                $sigHeader = $q;
            } else {
                $q2 = $request->get_param('signature');
                if ( $q2 ) {
                    $sigHeader = $q2;
                }
            }
        }
        $expected = hash_hmac('sha256', $body, local_sync_get_key());
        // (debug logging removed for production)
        if ( ! hash_equals($expected, $sigHeader) ) {
            return new WP_REST_Response(array('ok'=>false,'message'=>'invalid_signature'), 403);
        }
    } else {
        if ( $provided !== local_sync_get_key() ) {
            return new WP_REST_Response(array('ok'=>false,'message'=>'Unauthorized'), 401);
        }
    }

    $data = json_decode($body, true);

    // Logging
    if ( get_option('local_sync_enable_file_log', 0) ) {
        local_sync_append_log(array(
            'time' => gmdate('c'),
            'remote' => isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : null,
            'headers' => array_change_key_case($headers, CASE_LOWER),
            'body' => $data,
        ));
    }

    if ( function_exists('error_log') ) {
        // error_log removed for production
    }

    // Example sync actions (safe, minimal): support get_option/set_option/ping
    if ( ! is_array($data) || ! isset($data['action']) ) {
        return new WP_REST_Response(array('ok'=>false,'message'=>'invalid_payload'), 400);
    }

    $action = $data['action'];
    if ( $action === 'set_option' ) {
        if ( empty($data['option_name']) ) {
            return new WP_REST_Response(array('ok'=>false,'message'=>'missing_option_name'), 400);
        }
        update_option( $data['option_name'], isset($data['value']) ? $data['value'] : '' );
        return new WP_REST_Response(array('ok'=>true,'message'=>'option_updated','option'=>$data['option_name']), 200);
    }

    if ( $action === 'get_option' ) {
        if ( empty($data['option_name']) ) {
            return new WP_REST_Response(array('ok'=>false,'message'=>'missing_option_name'), 400);
        }
        $val = get_option( $data['option_name'], null );
        return new WP_REST_Response(array('ok'=>true,'option'=>$data['option_name'],'value'=>$val), 200);
    }

    if ( $action === 'ping' ) {
        return new WP_REST_Response(array('ok'=>true,'message'=>'pong'), 200);
    }

    return new WP_REST_Response(array('ok'=>false,'message'=>'unknown_action'), 400);
}

function local_sync_append_log( $entry ) {
    $uploads = wp_get_upload_dir();
    $dir = isset($uploads['basedir']) ? $uploads['basedir'] : WP_CONTENT_DIR . '/uploads';
    $file = $dir . DIRECTORY_SEPARATOR . 'local-sync.log';
    $line = json_encode($entry, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . PHP_EOL;
    @file_put_contents($file, $line, FILE_APPEND | LOCK_EX);
}

