<?php
/**
 * update_tenant_credentials.php - SaaS Security API
 * Allows Super Admin to force-update the primary Admin login for a tenant.
 */

// 1. Include core database connection and CORS headers
require_once 'db_config.php';

// 2. Get JSON input from the Flutter App
$data = json_decode(file_get_contents("php://input"));

// Check if data was parsed correctly
if (!$data) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Invalid JSON payload."]);
    exit();
}

// 3. Validate required fields
if (!empty($data->tenant_id) && !empty($data->email) && !empty($data->pin)) {
    try {
        /**
         * 4. UPDATE LOGIC
         * We target the user with role 'Admin' for the specific tenant.
         * This updates their Email and security PIN simultaneously.
         */
        $query = "UPDATE users
                  SET email = :email,
                      login_pin = :pin
                  WHERE tenant_id = :tid
                  AND role = 'Admin'";

        $stmt = $conn->prepare($query);

        $success = $stmt->execute([
            'tid'   => $data->tenant_id,
            'email' => $data->email,
            'pin'   => $data->pin
        ]);

        /**
         * 5. VERIFICATION
         * If no rows were affected, it means either the tenant doesn't exist
         * or there is no user with the 'Admin' role for that tenant.
         */
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                "status" => "success",
                "message" => "Login credentials updated for " . $data->tenant_id
            ]);
        } else {
            // Check if user exists at all
            $check = $conn->prepare("SELECT id FROM users WHERE tenant_id = :tid AND role = 'Admin'");
            $check->execute(['tid' => $data->tenant_id]);

            if ($check->rowCount() == 0) {
                echo json_encode([
                    "status" => "error",
                    "message" => "Critical Error: No Admin user found for this tenant in the database."
                ]);
            } else {
                echo json_encode([
                    "status" => "success",
                    "message" => "No changes made (data was already identical)."
                ]);
            }
        }

    } catch (PDOException $e) {
        // Handle database specific errors (e.g. duplicate email)
        http_response_code(500);
        echo json_encode([
            "status" => "error",
            "message" => "Database operation failed. Ensure the email is unique.",
            "technical" => $e->getMessage()
        ]);
    }
} else {
    // Bad request
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Missing data. Tenant ID, Email, and PIN are required."
    ]);
}
?>
