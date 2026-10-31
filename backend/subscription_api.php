<?php
/**
 * subscription_api.php - Real-Time Multi-Tenant Subscription & Package Lifecycle API
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';
require_once 'super_admin_api.php';
require_once 'email_notification_common.php';

// Auto-run schema migrations
try {
    @$conn->query("ALTER TABLE tenants ADD COLUMN subscription_status VARCHAR(50) DEFAULT 'Trial'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN trial_start DATETIME DEFAULT NULL");
    @$conn->query("ALTER TABLE tenants ADD COLUMN trial_end DATETIME DEFAULT NULL");
    @$conn->query("ALTER TABLE tenants ADD COLUMN subscription_start DATETIME DEFAULT NULL");
    @$conn->query("ALTER TABLE tenants ADD COLUMN subscription_end DATETIME DEFAULT NULL");
} catch (Throwable $e) {}

try {
    @$conn->query("CREATE TABLE IF NOT EXISTS subscription_packages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        duration_days INT NOT NULL DEFAULT 30,
        price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        perks TEXT DEFAULT NULL,
        is_active TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    // Seed defaults if empty
    $check_pkg = $conn->query("SELECT id FROM subscription_packages LIMIT 1");
    if ($check_pkg && $check_pkg->num_rows === 0) {
        $conn->query("INSERT INTO subscription_packages (id, name, duration_days, price, perks, is_active) VALUES
            (1, '3 Days Free Trial', 3, 0.00, 'Full Access • Auto Activated', 1),
            (2, 'Monthly Starter', 28, 799.00, 'Standard Features • 1 Store', 1),
            (3, '3 Months Pro', 84, 2396.52, 'Priority Support • Advanced Analytics', 1),
            (4, '6 Months Enterprise', 168, 4793.04, 'Unlimited Access • Multi-Store Ready', 1)");
    }
} catch (Throwable $e) {}

try {
    @$conn->query("CREATE TABLE IF NOT EXISTS subscription_requests (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        package_id INT NOT NULL,
        status VARCHAR(50) NOT NULL DEFAULT 'Pending',
        rejection_note TEXT DEFAULT NULL,
        requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        approved_by VARCHAR(100) DEFAULT NULL,
        approved_at TIMESTAMP NULL DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
} catch (Throwable $e) {}

$action = $_GET['action'] ?? '';

try {
    switch ($action) {
        // ==========================================
        // 1. PUBLIC / TENANT ENDPOINTS
        // ==========================================

        case 'get_packages':
            $tenant_id = trim((string)($_GET['tenant_id'] ?? ''));
            $stmt = $conn->prepare("SELECT * FROM subscription_packages WHERE is_active = 1 ORDER BY price ASC");
            $stmt->execute();
            $res = $stmt->get_result();
            $packages = [];

            $has_used_trial = false;
            if (!empty($tenant_id)) {
                $trial_chk = $conn->prepare("
                    SELECT r.id FROM subscription_requests r
                    JOIN subscription_packages p ON p.id = r.package_id
                    WHERE r.tenant_id = ? AND (LOWER(p.name) LIKE '%trial%' OR p.duration_days <= 3 OR p.price = 0.00)
                    LIMIT 1
                ");
                $trial_chk->bind_param("s", $tenant_id);
                $trial_chk->execute();
                if ($trial_chk->get_result()->num_rows > 0) {
                    $has_used_trial = true;
                }
            }

            while ($row = $res->fetch_assoc()) {
                $is_trial = (stripos($row['name'], 'trial') !== false || (int)$row['duration_days'] <= 3 || (float)$row['price'] == 0.00);
                if ($is_trial && $has_used_trial) {
                    continue; // Hide trial if already used/requested
                }
                $packages[] = $row;
            }
            echo json_encode(["status" => "success", "data" => $packages]);
            break;

        case 'request_package':
            $json = file_get_contents('php://input');
            $data = json_decode($json);

            $tenant_id = trim((string)($data->tenant_id ?? ''));
            $package_id = (int)($data->package_id ?? 0);

            if (empty($tenant_id) || $package_id <= 0) {
                http_response_code(400);
                echo json_encode(["status" => "error", "message" => "Tenant ID and Package ID are required."]);
                exit;
            }

            // STRICT SINGLE PENDING REQUEST RULE: Tenant can only have 1 pending request at a time
            $any_pending = $conn->prepare("SELECT id FROM subscription_requests WHERE tenant_id = ? AND status = 'Pending' LIMIT 1");
            $any_pending->bind_param("s", $tenant_id);
            $any_pending->execute();
            if ($any_pending->get_result()->num_rows > 0) {
                echo json_encode(["status" => "error", "message" => "You already have a pending subscription request. Please wait for Super Admin approval or cancel your existing pending request first."]);
                exit;
            }

            // SERVER-SIDE PACKAGE VALIDATION: Ensure package exists in DB
            $pkg_stmt = $conn->prepare("SELECT id, name, duration_days, price FROM subscription_packages WHERE id = ? AND is_active = 1 LIMIT 1");
            $pkg_stmt->bind_param("i", $package_id);
            $pkg_stmt->execute();
            $pkg_res = $pkg_stmt->get_result();

            if ($pkg_res->num_rows === 0) {
                http_response_code(404);
                echo json_encode(["status" => "error", "message" => "Invalid or inactive subscription package selected."]);
                exit;
            }

            $package = $pkg_res->fetch_assoc();

            // ONE-TIME 3-DAY FREE TRIAL RULE: A restaurant can only claim the trial once
            $is_trial_pkg = (stripos($package['name'], 'trial') !== false || $package['duration_days'] <= 3 || (float)$package['price'] == 0.00);
            if ($is_trial_pkg) {
                $trial_check = $conn->prepare("
                    SELECT r.id FROM subscription_requests r
                    JOIN subscription_packages p ON p.id = r.package_id
                    WHERE r.tenant_id = ? AND (LOWER(p.name) LIKE '%trial%' OR p.duration_days <= 3 OR p.price = 0.00)
                    LIMIT 1
                ");
                $trial_check->bind_param("s", $tenant_id);
                $trial_check->execute();
                if ($trial_check->get_result()->num_rows > 0) {
                    echo json_encode(["status" => "error", "message" => "The 3-Day Free Trial can only be claimed once per restaurant. You have already used or requested your free trial."]);
                    exit;
                }
            }

            $req_stmt = $conn->prepare("INSERT INTO subscription_requests (tenant_id, package_id, status) VALUES (?, ?, 'Pending')");
            $req_stmt->bind_param("si", $tenant_id, $package_id);
            if ($req_stmt->execute()) {
                echo json_encode([
                    "status" => "success",
                    "message" => "Subscription request submitted! Awaiting Super Admin approval.",
                    "request_id" => $conn->insert_id,
                    "package" => $package
                ]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to save request."]);
            }
            break;

        case 'cancel_request':
            $json = file_get_contents('php://input');
            $data = json_decode($json);
            $request_id = (int)($data->request_id ?? 0);
            $tenant_id = trim((string)($data->tenant_id ?? ''));

            if ($request_id <= 0 || empty($tenant_id)) {
                echo json_encode(["status" => "error", "message" => "Request ID and Tenant ID are required."]);
                exit;
            }

            $del = $conn->prepare("DELETE FROM subscription_requests WHERE id = ? AND tenant_id = ? AND status = 'Pending'");
            $del->bind_param("is", $request_id, $tenant_id);
            if ($del->execute() && $del->affected_rows > 0) {
                echo json_encode(["status" => "success", "message" => "Subscription request cancelled successfully."]);
            } else {
                echo json_encode(["status" => "error", "message" => "Request not found, already processed, or unauthorized."]);
            }
            break;

        case 'get_my_requests':
            $tenant_id = trim((string)($_GET['tenant_id'] ?? ''));
            if (empty($tenant_id)) {
                echo json_encode(["status" => "error", "message" => "Tenant ID is required"]);
                exit;
            }

            $stmt = $conn->prepare("
                SELECT r.*, p.name AS package_name, p.duration_days, p.price, p.perks
                FROM subscription_requests r
                JOIN subscription_packages p ON p.id = r.package_id
                WHERE r.tenant_id = ?
                ORDER BY r.requested_at DESC
            ");
            $stmt->bind_param("s", $tenant_id);
            $stmt->execute();
            $res = $stmt->get_result();
            $requests = [];
            while ($row = $res->fetch_assoc()) {
                $requests[] = $row;
            }

            echo json_encode(["status" => "success", "data" => $requests]);
            break;

        // ==========================================
        // 2. PROTECTED SUPER ADMIN ENDPOINTS
        // ==========================================

        case 'get_pending_requests':
            $admin = verifySuperAdminSession($conn);
            if (!$admin) {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Unauthorized. Real Super Admin login required."]);
                exit;
            }

            $stmt = $conn->prepare("
                SELECT r.*, p.name AS package_name, p.duration_days, p.price,
                       t.restaurant_name, t.custom_domain, t.plan AS current_plan, t.subscription_end
                FROM subscription_requests r
                JOIN subscription_packages p ON p.id = r.package_id
                LEFT JOIN tenants t ON t.tenant_id = r.tenant_id OR t.custom_domain = r.tenant_id
                WHERE r.status = 'Pending'
                ORDER BY r.requested_at ASC
            ");
            $stmt->execute();
            $res = $stmt->get_result();
            $requests = [];
            while ($row = $res->fetch_assoc()) {
                $requests[] = $row;
            }

            echo json_encode(["status" => "success", "data" => $requests]);
            break;

        case 'approve_request':
            $admin = verifySuperAdminSession($conn);
            if (!$admin) {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Unauthorized. Real Super Admin session required."]);
                exit;
            }

            $json = file_get_contents('php://input');
            $data = json_decode($json);
            $request_id = (int)($data->request_id ?? 0);

            if ($request_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Request ID is required."]);
                exit;
            }

            // IDEMPOTENCY CHECK: Ensure request exists AND is still 'Pending'
            $req_stmt = $conn->prepare("
                SELECT r.*, p.name AS package_name, p.duration_days
                FROM subscription_requests r
                JOIN subscription_packages p ON p.id = r.package_id
                WHERE r.id = ? LIMIT 1
            ");
            $req_stmt->bind_param("i", $request_id);
            $req_stmt->execute();
            $req_res = $req_stmt->get_result();

            if ($req_res->num_rows === 0) {
                echo json_encode(["status" => "error", "message" => "Subscription request not found."]);
                exit;
            }

            $req = $req_res->fetch_assoc();
            if ($req['status'] !== 'Pending') {
                echo json_encode([
                    "status" => "error",
                    "message" => "Idempotency Warning: Request #$request_id has already been processed (Current status: {$req['status']})."
                ]);
                exit;
            }

            $tenant_id = $req['tenant_id'];
            $duration_days = (int)$req['duration_days'];
            $package_name = $req['package_name'];
            $admin_user = $admin['username'];

            $conn->begin_transaction();

            try {
                // 1. Mark request as Approved
                $upd_req = $conn->prepare("UPDATE subscription_requests SET status = 'Approved', approved_by = ?, approved_at = NOW() WHERE id = ?");
                $upd_req->bind_param("si", $admin_user, $request_id);
                $upd_req->execute();

                // 2. Extend or set Tenant subscription_end date & active plan
                // Formula: IF existing subscription_end is in future, add duration to it. Else, set NOW() + duration.
                $upd_tenant = $conn->prepare("
                    UPDATE tenants
                    SET plan = ?,
                        subscription_status = 'Active',
                        is_active = 1,
                        subscription_start = COALESCE(subscription_start, NOW()),
                        subscription_end = IF(subscription_end IS NOT NULL AND subscription_end > NOW(),
                                               DATE_ADD(subscription_end, INTERVAL ? DAY),
                                               DATE_ADD(NOW(), INTERVAL ? DAY))
                    WHERE tenant_id = ? OR custom_domain = ?
                ");
                $upd_tenant->bind_param("siiss", $package_name, $duration_days, $duration_days, $tenant_id, $tenant_id);
                $upd_tenant->execute();

                $conn->commit();

                // Send notification to tenant about subscription approval
                $tenant_stmt = $conn->prepare("SELECT primary_email, contact_email, restaurant_name FROM tenants WHERE tenant_id = ? OR custom_domain = ? LIMIT 1");
                $tenant_stmt->bind_param("ss", $tenant_id, $tenant_id);
                $tenant_stmt->execute();
                $tenant_res = $tenant_stmt->get_result();
                $admin_email = $tenant_id;
                $restaurant_name = $tenant_id;
                if ($tenant_row = $tenant_res->fetch_assoc()) {
                    $admin_email = !empty($tenant_row['contact_email']) ? $tenant_row['contact_email'] :
                                  (!empty($tenant_row['primary_email']) ? $tenant_row['primary_email'] : $tenant_id);
                    $restaurant_name = $tenant_row['restaurant_name'] ?? $tenant_id;
                }

                $notif = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'subscription')");
                $title = "Subscription Approved!";
                $notif_msg = "Your subscription to '$package_name' has been approved. Valid for $duration_days days.";
                $notif->bind_param("ssss", $tenant_id, $admin_email, $title, $notif_msg);
                $notif->execute();
                queueEmailNotification($conn, $tenant_id, $admin_email, $conn->insert_id, 'subscription');

                echo json_encode([
                    "status" => "success",
                    "message" => "Subscription request #$request_id approved successfully. Plan '$package_name' (+ $duration_days days) activated for $tenant_id."
                ]);
            } catch (Throwable $ex) {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Failed to approve subscription: " . $ex->getMessage()]);
            }
            break;

        case 'reject_request':
            $admin = verifySuperAdminSession($conn);
            if (!$admin) {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Unauthorized. Real Super Admin session required."]);
                exit;
            }

            $json = file_get_contents('php://input');
            $data = json_decode($json);
            $request_id = (int)($data->request_id ?? 0);
            $note = trim((string)($data->rejection_note ?? $data->note ?? 'Request rejected by Super Admin.'));

            if ($request_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Request ID is required."]);
                exit;
            }

            // IDEMPOTENCY CHECK
            $req_stmt = $conn->prepare("SELECT status FROM subscription_requests WHERE id = ? LIMIT 1");
            $req_stmt->bind_param("i", $request_id);
            $req_stmt->execute();
            $req_res = $req_stmt->get_result();

            if ($req_res->num_rows === 0) {
                echo json_encode(["status" => "error", "message" => "Request not found."]);
                exit;
            }

            $req = $req_res->fetch_assoc();
            if ($req['status'] !== 'Pending') {
                echo json_encode(["status" => "error", "message" => "Request has already been processed."]);
                exit;
            }

            $admin_user = $admin['username'];
            $upd = $conn->prepare("UPDATE subscription_requests SET status = 'Rejected', rejection_note = ?, approved_by = ?, approved_at = NOW() WHERE id = ?");
            $upd->bind_param("ssi", $note, $admin_user, $request_id);

            if ($upd->execute()) {
                // Send notification to tenant about subscription rejection
                $tenant_stmt = $conn->prepare("SELECT primary_email, contact_email FROM tenants WHERE tenant_id = ? OR custom_domain = ? LIMIT 1");
                $tenant_stmt->bind_param("ss", $tenant_id, $tenant_id);
                $tenant_stmt->execute();
                $tenant_res = $tenant_stmt->get_result();
                $admin_email = $tenant_id;
                if ($tenant_row = $tenant_res->fetch_assoc()) {
                    $admin_email = !empty($tenant_row['contact_email']) ? $tenant_row['contact_email'] :
                                  (!empty($tenant_row['primary_email']) ? $tenant_row['primary_email'] : $tenant_id);
                }

                $notif = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'subscription')");
                $title = "Subscription Request Rejected";
                $notif_msg = "Your subscription request has been rejected. Note: $note";
                $notif->bind_param("ssss", $tenant_id, $admin_email, $title, $notif_msg);
                $notif->execute();
                queueEmailNotification($conn, $tenant_id, $admin_email, $conn->insert_id, 'subscription');

                echo json_encode(["status" => "success", "message" => "Subscription request #$request_id rejected."]);
            } else {
                echo json_encode(["status" => "error", "message" => "Database error."]);
            }
            break;

        case 'save_package':
            $admin = verifySuperAdminSession($conn);
            if (!$admin) {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Unauthorized. Real Super Admin session required."]);
                exit;
            }

            $json = file_get_contents('php://input');
            $data = json_decode($json);

            $pkg_id = (int)($data->id ?? 0);
            $name = trim((string)($data->name ?? $data->title ?? ''));
            $duration_days = (int)($data->duration_days ?? 30);
            $price = (float)($data->price ?? 0.00);
            $perks = trim((string)($data->perks ?? ''));

            if (empty($name) || $duration_days <= 0) {
                echo json_encode(["status" => "error", "message" => "Package title and valid duration in days are required."]);
                exit;
            }

            if ($pkg_id > 0) {
                $stmt = $conn->prepare("UPDATE subscription_packages SET name = ?, duration_days = ?, price = ?, perks = ? WHERE id = ?");
                $stmt->bind_param("sidsi", $name, $duration_days, $price, $perks, $pkg_id);
            } else {
                $stmt = $conn->prepare("INSERT INTO subscription_packages (name, duration_days, price, perks) VALUES (?, ?, ?, ?)");
                $stmt->bind_param("sids", $name, $duration_days, $price, $perks);
            }

            if ($stmt->execute()) {
                echo json_encode(["status" => "success", "message" => "Subscription package saved successfully."]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to save package."]);
            }
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid subscription API action"]);
            break;
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "System error: " . $e->getMessage()]);
}

$conn->close();
?>
