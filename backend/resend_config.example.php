<?php
if (isset($_SERVER['SCRIPT_FILENAME'])
    && realpath($_SERVER['SCRIPT_FILENAME']) === __FILE__) {
    http_response_code(404);
    exit;
}

return [
    // ############## PASTE YOUR NEW RESEND API KEY BETWEEN THESE QUOTES ##############
    'RESEND_API_KEY' => '##############',
    // ############## USE A SENDER VERIFIED IN RESEND ##############
    'RESEND_FROM_EMAIL' => 'noreply@startupsgo.tech'
];