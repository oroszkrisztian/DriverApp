<?php

    require_once 'dbase.php';

    session_start();

    function getPasswordHash($pdo, $username) {
        $stmt = $pdo->prepare("SELECT db_pass FROM users WHERE db_user=?");
        $stmt->execute([$username]);
        $result = $stmt->fetchColumn();

        return $result !== false ? $result : null;
    }

    function checkPassword($pdo, $username, $password, $type) {
        switch ($type) {
            case "fleet_manager":
                $stmt = $pdo->prepare("SELECT password FROM fleet_managers WHERE name=?");
                $stmt->execute([$username]);
                $result = $stmt->fetchColumn();

                return strcmp($password, $result) ? true : false;
            case "driver":
                $stmt = $pdo->prepare("SELECT password FROM drivers WHERE name=?");
                $stmt->execute([$username]);
                $result = $stmt->fetchColumn();

                return strcmp($password, $result) ? true : false;
        }
    }

    function getUserId($pdo, $username) {
        $stmt = $pdo->prepare("SELECT id FROM users WHERE db_user=?");
        $stmt->execute([$username]);
        $result = $stmt->fetchColumn();

        return $result !== false ? $result : null;
    }

    function getId($pdo, $username, $type) {
        switch ($type) {
            case "fleet_manager":
                $stmt = $pdo->prepare("SELECT id FROM fleet_managers WHERE name=?");
                $stmt->execute([$username]);
                $result = $stmt->fetchColumn();

                return $result !== false ? $result : null;
            case "driver":
                $stmt = $pdo->prepare("SELECT id FROM drivers WHERE name=?");
                $stmt->execute([$username]);
                $result = $stmt->fetchColumn();

                return $result !== false ? $result : null;
        }
    }

    function getUserCredentialsById($pdo, $user) {
        $stmt = $pdo->prepare("SELECT db_name, db_user, openssl FROM users WHERE id=?");
        $stmt->execute([$user]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);

        return $result !== false ? $result : null;
    }

    try {
        $pdo = connectToDatabase(HOST, DB, USER, PASS);
    } catch (PDOException $e) {
        die("Connection failed: " . $e->getMessage());
    }

    $fleet_manager = isset($_SESSION['fleet_manager_id']) ? $_SESSION['fleet_manager_id'] : "-1";

    // Execute action
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
        // Create user: database name, user, password
        if ($_POST['action'] === 'createUser' && isset($_POST['dbname']) && isset($_POST['username']) && isset($_POST['password'])) {
            $dbname = filter_var($_POST['dbname'], FILTER_SANITIZE_STRING);
            $username = filter_var($_POST['username'], FILTER_SANITIZE_STRING);
            $password = $_POST['password'];
    
            $options = [
                'cost' => 12, // You can adjust the cost parameter as needed (higher is more secure but slower)
            ];
            $hashedPassword = password_hash($password, PASSWORD_ARGON2I, $options);

            $iv = base64_decode(IV);
            $cipher = ENCRYPTION;
            $key = base64_decode(KEY);

            $encryptedData = openssl_encrypt($password, $cipher, $key, 0, $iv);

            $stmt = $pdo->prepare("INSERT INTO users (db_name, db_user, db_pass, openssl) VALUES (?, ?, ?, ?)");
            $stmt->execute([$dbname, $username, $hashedPassword, $encryptedData]);
    
            // Return a response
            echo json_encode(['success' => true, 'message' => 'User created successfully']);
            exit;
        }

        // Login user: user, password
        if ($_POST['action'] === 'login' && isset($_POST['username']) && isset($_POST['password']) && isset($_POST['type'])) {
            $username = filter_var($_POST['username'], FILTER_SANITIZE_STRING);
            $password = $_POST['password'];
            $type = filter_var($_POST['type'], FILTER_SANITIZE_STRING);

            if ($type == 'superadmin') {
                $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

                $dbname = $credentials['db_name'];
                $db_username = $credentials['db_user'];
                $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

                $stmt = $temppdo->prepare("SELECT masterpassword FROM masterlogin");
                $stmt->execute();
                $result = $stmt->fetchColumn();

                if (strcmp(openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV)), $result) == 0) {
                    echo json_encode(['success' => true, 'message' => 'Logged in successfully'.$db_password]);

                    $_SESSION['superadmin'] = 1;
                } else {
                    echo json_encode(['success' => false, 'message' => 'Login unsuccessful. '.openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV))]);
                }
            }

            if ($type == 'server') {
                $passwordHash = getPasswordHash($pdo, $username);

                if (password_verify($password, $passwordHash)) {
                    echo json_encode(['success' => true, 'message' => 'Logged in successfully']);

                    $_SESSION['user_id'] = getUserId($pdo, $username);
                } else {
                    echo json_encode(['success' => false, 'message' => 'Login unsuccessful']);
                }
            }

            if ($type == 'fleet_manager') {
                $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

                $dbname = $credentials['db_name'];
                $db_username = $credentials['db_user'];
                $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

                if (checkPassword($temppdo, $username, $password, 'fleet_manager')) {
                    echo json_encode(['success' => true, 'message' => 'Logged in successfully']);

                    $_SESSION['fleet_manager_id'] = getId($temppdo, $username, 'fleet_manager');
                } else {
                    echo json_encode(['success' => false, 'message' => 'Login unsuccessful']);
                }
            }

            if ($type == 'driver') {
                $credentials = getUserCredentialsById($pdo, 1);

                $dbname = $credentials['db_name'];
                $db_username = $credentials['db_user'];
                $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

                if (checkPassword($temppdo, $username, $password, 'driver')) {
                    echo json_encode(['success' => true, 'message' => 'Logged in successfully', 'driver_id' => getId($temppdo, $username, 'driver')]);

                    $_SESSION['driver_id'] = getId($temppdo, $username, 'driver');
                } else {
                    echo json_encode(['success' => false, 'message' => 'Login unsuccessful', 'driver_id' => -1]);
                }
            }
            
            exit;
        }

        // Fleet manager: new/set, username, password
        if (($_POST['action'] === 'managers-new' || $_POST['action'] === 'managers-set') && isset($_POST['username']) && isset($_POST['password']) && isset($_POST['telephone']) && isset($_POST['email']) && isset($_POST['id']) && isset($_POST['rights'])) {
            $username = filter_var($_POST['username'], FILTER_SANITIZE_STRING);
            $password = $_POST['password'];
            $telephone = filter_var($_POST['telephone'], FILTER_SANITIZE_STRING);
            $email = filter_var($_POST['email'], FILTER_SANITIZE_EMAIL);
            $rights = $_POST['rights'];
            $id = $_POST['id'];

            if ($_POST['action'] === 'managers-new') {
                $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

                $dbname = $credentials['db_name'];
                $db_username = $credentials['db_user'];
                $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

                $stmt = $temppdo->prepare("INSERT INTO fleet_managers SET name=?, password=?, telephone=?, email=?");
                $stmt->execute([$username, $encrypted_password, $telephone, $email]);

                $id = $temppdo->lastInsertId();

                $stmt = $temppdo->prepare("INSERT INTO fleet_manager_rights SET fleet_managers=?, drivers=?, vehicles=?, fleet_manager_logs=?, driver_logs=?, vehicle_logs=?, expenses=?, categories=?, fleet_manager_id=?");
                $stmt->execute([$rights['managers'], $rights['drivers'], $rights['vehicles'], $rights['manager_logs'], $rights['driver_logs'], $rights['vehicle_logs'], $rights['expenses'], $rights['categories'], $id]);

                $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                $stmt->execute([$fleet_manager, "NEW MANAGER CREATED", "Fleet Manager named '$username' was created", $_SERVER['REMOTE_ADDR']]);

                echo json_encode(['success' => true, 'message' => 'Fleet manager created successfully']);

                closeConnection($temppdo);

                exit;
            }

            if ($_POST['action'] === 'managers-set') {
                $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

                $dbname = $credentials['db_name'];
                $db_username = $credentials['db_user'];
                $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

                $stmt = $temppdo->prepare("UPDATE fleet_managers SET name=?, password=?, telephone=?, email=? WHERE id=?");
                $stmt->execute([$username, $encrypted_password, $telephone, $email, $id]);

                $stmt = $temppdo->prepare("UPDATE fleet_manager_rights SET superadmin=?, fleet_managers=?, drivers=?, vehicles=?, vehicle_data=?, fleet_manager_logs=?, driver_logs=?, vehicle_logs=?, expenses=?, categories=? WHERE fleet_manager_id=?");
                $stmt->execute([$rights['superadmin'], $rights['managers'], $rights['drivers'], $rights['vehicles'], $rights['vehicle_data'], $rights['manager_logs'], $rights['driver_logs'], $rights['vehicle_logs'], $rights['expenses'], $rights['categories'], $id]);

                $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                $stmt->execute([$fleet_manager, "MANAGER UPDATED", "Fleet Manager named '$username' was updated", $_SERVER['REMOTE_ADDR']]);

                echo json_encode(['success' => true, 'message' => 'Fleet manager updated successfully']);

                closeConnection($temppdo);

                exit;
            }
        }

        // Driver: new/set, username, password
        if (($_POST['action'] === 'drivers-new' || $_POST['action'] === 'drivers-set') && isset($_POST['username']) && isset($_POST['password']) && isset($_POST['telephone']) && isset($_POST['email']) && isset($_POST['id']) && isset($_POST['birthdate']) && isset($_POST['driving_licence_validity']) && isset($_POST['categories']) && isset($_POST['active']) && isset($_POST['remarks']) && isset($_POST['vehicle'])) {
            $username = filter_var($_POST['username'], FILTER_SANITIZE_STRING);
            $password = $_POST['password'];
            $telephone = filter_var($_POST['telephone'], FILTER_SANITIZE_STRING);
            $email = filter_var($_POST['email'], FILTER_SANITIZE_EMAIL);
            $id = $_POST['id'];
            $birthdate = $_POST['birthdate'];
            $driving_licence_validity = $_POST['driving_licence_validity'];
            $categories = $_POST['categories'];
            $active = $_POST['active'];
            $remarks = $_POST['remarks'];
            $vehicle = $_POST['vehicle'];

            $isFile = false;

            if (isset($_FILES['driving_licence'])) {
                $file = $_FILES['driving_licence'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];
                
                $stmt = $pdo->prepare("SELECT folder FROM users WHERE id=?");
                $stmt->execute([$_SESSION['user_id']]);

                $folder = $stmt->fetchColumn();

                $file_destination = '../files/'.$folder.'/driving_licences/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = "{$username}_driving_licence.{$file_extension}";
                $file_destination .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination);

                $isFile = true;
            }

            if ($_POST['action'] === 'drivers-new') {
                $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

                $dbname = $credentials['db_name'];
                $db_username = $credentials['db_user'];
                $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

                $stmt = $temppdo->prepare("INSERT INTO drivers SET name=?, password=?, telephone=?, email=?, birthdate=?, driving_licence=?, driving_licence_validity=?, driving_licence_categories=?, active=?, remarks=?, vehicle_id=?");
                $stmt->execute([$username, $encrypted_password, $telephone, $email, $birthdate, $file_destination, $driving_licence_validity, $categories, $active, $remarks, $vehicle]);

                $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                $stmt->execute([$fleet_manager, "NEW DRIVER CREATED", "Driver named '$username' was created", $_SERVER['REMOTE_ADDR']]);

                echo json_encode(['success' => true, 'message' => 'Driver created successfully']);

                closeConnection($temppdo);

                exit;
            }

            if ($_POST['action'] === 'drivers-set') {
                $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

                $dbname = $credentials['db_name'];
                $db_username = $credentials['db_user'];
                $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

                $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

                if ($isFile) {
                    $stmt = $temppdo->prepare("UPDATE drivers SET name=?, password=?, telephone=?, email=?, birthdate=?, driving_licence=?, driving_licence_validity=?, driving_licence_categories=?, active=?, remarks=?, vehicle_id=? WHERE id=?");
                    $stmt->execute([$username, $encrypted_password, $telephone, $email, $birthdate, $file_destination, $driving_licence_validity, $categories, $active, $remarks, $vehicle, $id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "DRIVER UPDATED", "Driver named '$username' was updated. New photo uploaded", $_SERVER['REMOTE_ADDR']]);

                    echo json_encode(['success' => true, 'message' => 'Driver updated successfully']);

                    closeConnection($temppdo);
                } else {
                    $stmt = $temppdo->prepare("UPDATE drivers SET name=?, password=?, telephone=?, email=?, birthdate=?, driving_licence_validity=?, driving_licence_categories=?, active=?, remarks=?, vehicle_id=? WHERE id=?");
                    $stmt->execute([$username, $encrypted_password, $telephone, $email, $birthdate, $driving_licence_validity, $categories, $active, $remarks, $vehicle, $id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "DRIVER UPDATED", "Driver named '$username' was updated", $_SERVER['REMOTE_ADDR']]);

                    echo json_encode(['success' => true, 'message' => 'Driver updated successfully']);

                    closeConnection($temppdo);
                }                

                exit;
            }
        }

        // Vehicles: new/set, many details
        if (($_POST['action'] == "vehicles-new" || $_POST['action'] == "vehicles-set") && isset($_POST['id']) && isset($_POST['vehiclename']) && isset($_POST['numberplate']) && isset($_POST['fuel']) && isset($_POST['start_date']) && isset($_POST['tyre_size']) && isset($_POST['oil'])) {
            $id = $_POST['id'];
            $vehiclename = filter_var($_POST['vehiclename'], FILTER_SANITIZE_STRING);
            $numberplate = filter_var($_POST['numberplate'], FILTER_SANITIZE_STRING);
            $fuel = $_POST['fuel'];
            $start_date = $_POST['start_date'];
            $tyre_size = $_POST['tyre_size'];
            $oil = $_POST['oil'];

            $isFile = false;

            if (isset($_FILES['registration_certificate'])) {
                $file = $_FILES['registration_certificate'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];
                
                $stmt = $pdo->prepare("SELECT folder FROM users WHERE id=?");
                $stmt->execute([$_SESSION['user_id']]);

                $folder = $stmt->fetchColumn();

                $file_destination = '../files/'.$folder.'/vehicles/registration_certificates/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = "{$vehiclename}_{$numberplate}_registration_certificate.{$file_extension}";
                $file_destination .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination);

                $isFile = true;
            }

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            if ($_POST['action'] === 'vehicles-new') {
                $stmt = $temppdo->prepare("INSERT INTO vehicles SET name=?, numberplate=?, fuel=?, registration_certificate=?, start_date=?, tyre_size=?, oil=?");
                $stmt->execute([$vehiclename, $numberplate, $fuel, $file_destination, $start_date, $tyre_size, $oil]);

                $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                $stmt->execute([$fleet_manager, "NEW VEHICLE CREATED", "Vehicle named '$vehiclename ($numberplate)' was created", $_SERVER['REMOTE_ADDR']]);

                echo json_encode(['success' => true, 'message' => 'Vehicle created successfully']);

                closeConnection($temppdo);
            }

            if ($_POST['action'] === 'vehicles-set') {
                if ($isFile) {
                    $stmt = $temppdo->prepare("UPDATE vehicles SET name=?, numberplate=?, fuel=?, registration_certificate=?, start_date=?, tyre_size=?, oil=? WHERE id=?");
                    $stmt->execute([$vehiclename, $numberplate, $fuel, $file_destination, $start_date, $tyre_size, $oil, $id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "VEHICLE UPDATED", "Vehicle named '$vehiclename ($numberplate)' was updated. New photo uploaded", $_SERVER['REMOTE_ADDR']]);

                    echo json_encode(['success' => true, 'message' => 'Vehicle updated successfully']);

                    closeConnection($temppdo);
                } else {
                    $stmt = $temppdo->prepare("UPDATE vehicles SET name=?, numberplate=?, fuel=?, start_date=?, tyre_size=?, oil=? WHERE id=?");
                    $stmt->execute([$vehiclename, $numberplate, $fuel, $start_date, $tyre_size, $oil, $id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "VEHICLE UPDATED", "Vehicle named '$vehiclename ($numberplate)' was updated", $_SERVER['REMOTE_ADDR']]);

                    echo json_encode(['success' => true, 'message' => 'Vehicle updated successfully']);

                    closeConnection($temppdo);
                }
            }
        }

        // Vehicle Data - filter
        if ($_POST['action'] === 'vehicle-data-filter' && isset($_POST['from']) && isset($_POST['to']) && isset($_POST['type']) && isset($_POST['status']) && isset($_POST['vehicle'])) {
            $from = $_POST['from'];
            $to = $_POST['to'];
            $vehicle = $_POST['vehicle'];
            $type = $_POST['type'];
            $status = $_POST['status'];

            if ($vehicle == 'all') {
                $vehicle_condition = "1=1";
            } else {
                $vehicle_condition = "b.vehicle_id='".$vehicle."'";
            }

            if ($type == 'all') {
                $type_condition = "1=1";
            } else {
                $type_condition = "b.type='".$type."'";
            }

            if ($status == 'all') {
                $status_condition = "1=1";
            } else {
                if ($status == 'active') {
                    $status_condition = "b.date_end>=CURDATE()";
                } else {
                    $status_condition = "b.date_end<CURDATE()";
                }
            }

            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT b.id, a.name, a.numberplate, b.type, b.km, b.date_start, b.date_end, b.remarks, b.photo FROM vehicles a JOIN vehicle_data b ON a.id=b.vehicle_id WHERE b.date_start<=? AND b.date_end>=? AND $vehicle_condition AND $type_condition AND $status_condition");
            $stmt->execute([$to, $from]);
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

            header('Content-Type: application/json');
            echo json_encode($data);

            closeConnection($temppdo);
        }

        if ($_POST['action'] === 'vehicle-data-remove-image' && isset($_POST['id'])) {
            $id = $_POST['id'];

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT photo FROM vehicle_data WHERE id=?");
            $stmt->execute([$id]);
            $photo = $stmt->fetchColumn();

            if (file_exists($photo)) {
                // Attempt to delete the file
                if (unlink($photo)) {
                    $stmt = $temppdo->prepare("UPDATE vehicle_data SET photo='' WHERE id=?");
                    $stmt->execute([$id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "VEHICLE DATA - PHOTO REMOVED", "Photo from ID number $id vehicle data removed", $_SERVER['REMOTE_ADDR']]);

                    echo json_encode(['success' => true, 'message' => "Photo has been deleted successfully."]);
                } else {
                    echo json_encode(['success' => false, 'message' => "Error: Unable to delete the file."]);
                }
            } else {
                echo json_encode(['success' => false, 'message' => "Error: File $photo does not exist."]);
            }
        }

        if ($_POST['action'] === 'vehicle-data-remove-record' && isset($_POST['id'])) {
            $id = $_POST['id'];

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT photo FROM vehicle_data WHERE id=?");
            $stmt->execute([$id]);
            $photo = $stmt->fetchColumn();

            if (file_exists($photo)) { unlink($photo); }
            
            $stmt = $temppdo->prepare("DELETE FROM vehicle_data WHERE id=?");
            $stmt->execute([$id]);

            $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
            $stmt->execute([$fleet_manager, "VEHICLE DATA - RECORD REMOVED", "ID number $id vehicle data removed", $_SERVER['REMOTE_ADDR']]);

            echo json_encode(['success' => true, 'message' => "Record removed successfully."]);
        }

        // Vehicle Data - save
        if ($_POST['action'] === 'vehicle-data-save' && isset($_POST['id']) && isset($_POST['vehicle']) && isset($_POST['type']) && isset($_POST['km']) && isset($_POST['date_start']) && isset($_POST['date_end']) && isset($_POST['remarks'])) {
            $id = $_POST['id'];
            $vehicle = $_POST['vehicle'];
            $type = $_POST['type'];
            $km = filter_var($_POST['km'], FILTER_SANITIZE_NUMBER_INT);
            $date_start = $_POST['date_start'];
            $date_end = $_POST['date_end'];
            $remarks = $_POST['remarks'];

            $isFile = false;

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            if (isset($_FILES['file'])) {
                $file = $_FILES['file'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];
                
                $stmt = $pdo->prepare("SELECT folder FROM users WHERE id=?");
                $stmt->execute([$_SESSION['user_id']]);

                $folder = $stmt->fetchColumn();

                $file_destination = '../files/'.$folder.'/vehicle_data/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $stmt = $temppdo->prepare("SELECT name, numberplate FROM vehicles WHERE id=?");
                $stmt->execute([$vehicle]);
                $vehicledata = $stmt->fetch(PDO::FETCH_ASSOC);

                $new_file_name = $vehicledata['name']."_".$vehicledata['numberplate']."_{$type}_{$date_start}.{$file_extension}";
                $file_destination .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination);

                $isFile = true;
            }

            closeConnection($temppdo);

            if ($type == 'all') {
                $type_condition = "1=1";
            } else {
                $type_condition = "type='".$type."'";
            }

            if ($status == 'all') {
                $status_condition = "1=1";
            } else {
                if ($status == 'active') {
                    $status_condition = "date_end<='".$to."'";
                } else {
                    $status_condition = "date_end>'".$to."'";
                }
            }

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            if (intval($id) != -1) {
                // UPDATE

                if ($isFile) {
                    $stmt = $temppdo->prepare("UPDATE vehicle_data SET vehicle_id=?, type=?, km=?, date_start=?, date_end=?, remarks=?, photo=? WHERE id=?");
                    $stmt->execute([$vehicle, $type, $km, $date_start, $date_end, $remarks, $file_destination, $id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "VEHICLE DATA UPDATED", "ID number $id vehicle data updated. New photo uploaded", $_SERVER['REMOTE_ADDR']]);
                } else {
                    $stmt = $temppdo->prepare("UPDATE vehicle_data SET vehicle_id=?, type=?, km=?, date_start=?, date_end=?, remarks=? WHERE id=?");
                    $stmt->execute([$vehicle, $type, $km, $date_start, $date_end, $remarks, $id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "VEHICLE DATA UPDATED", "ID number $id vehicle data updated", $_SERVER['REMOTE_ADDR']]);
                }

                echo json_encode(['success' => true, 'message' => 'Vehicle data updated successfully']);
            } else {
                // INSERT

                if ($isFile) {
                    $stmt = $temppdo->prepare("INSERT INTO vehicle_data SET vehicle_id=?, type=?, km=?, date_start=?, date_end=?, remarks=?, photo=?");
                    $stmt->execute([$vehicle, $type, $km, $date_start, $date_end, $remarks, $file_destination]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "NEW VEHICLE DATA CREATED", "ID number $id vehicle data was created. New photo uploaded", $_SERVER['REMOTE_ADDR']]);
                } else {
                    $stmt = $temppdo->prepare("INSERT INTO vehicle_data SET vehicle_id=?, type=?, km=?, date_start=?, date_end=?, remarks=?");
                    $stmt->execute([$vehicle, $type, $km, $date_start, $date_end, $remarks]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "NEW VEHICLE DATA CREATED", "ID number $id vehicle data was created", $_SERVER['REMOTE_ADDR']]);
                }

                echo json_encode(['success' => true, 'message' => 'Vehicle data created successfully']);
            }

            closeConnection($temppdo);
        }

        // Vehicle login - driver, vehicle, km, photos (FIVE)
        if ($_POST['action'] === "vehicle-login" && isset($_POST['driver']) && isset($_POST['vehicle']) && isset($_POST['km'])) {
            $driver = $_POST['driver'];
            $vehicle = $_POST['vehicle'];
            $km = filter_var($_POST['km'], FILTER_SANITIZE_NUMBER_INT);

            $isFile = false;

            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $pdo->prepare("SELECT folder FROM users WHERE id=?");
            $stmt->execute([1]);

            $folder = $stmt->fetchColumn();

            $stmt = $temppdo->prepare("SELECT name, numberplate FROM vehicles WHERE id=?");
            $stmt->execute([$vehicle]);
            $vehicledata = $stmt->fetch(PDO::FETCH_ASSOC);

            $stmt = $temppdo->prepare("SELECT name, status FROM drivers WHERE id=?");
            $stmt->execute([$driver]);
            $driverdata = $stmt->fetch(PDO::FETCH_ASSOC);

            $type = $driverdata['status'] == "OUT" ? "IN" : "OUT";

            $currentDateTime = date("YmdHis");

            $stmt = $temppdo->prepare("INSERT INTO driver_logs SET time=?, driver_id=?, vehicle_id=?, km=?, action=?");
            $stmt->execute([date("Y-m-d H:i:s"), $driver, $vehicle, $km, $type]);

            if ($type == 'IN') {
                $stmt = $temppdo->prepare("UPDATE drivers SET status='IN' WHERE id=?");
                $stmt->execute([$driver]);
                echo json_encode(["success" => true, "message" => "Logged in successfully"]);
            } else {
                $stmt = $temppdo->prepare("UPDATE drivers SET status='OUT' WHERE id=?");
                $stmt->execute([$driver]);
                echo json_encode(["success" => true, "message" => "Logged out successfully"]);
            }

            closeConnection($temppdo);
        }

        if ($_POST['action'] === 'photo-upload' && isset($_POST['driver']) && isset($_POST['vehicle']) && isset($_POST['km'])) {
            $driver = $_POST['driver'];
            $vehicle = $_POST['vehicle'];
            $km = filter_var($_POST['km'], FILTER_SANITIZE_NUMBER_INT);

            $isFile = false;

            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $pdo->prepare("SELECT folder FROM users WHERE id=?");
            $stmt->execute([1]);

            $folder = $stmt->fetchColumn();

            $stmt = $temppdo->prepare("SELECT name, numberplate FROM vehicles WHERE id=?");
            $stmt->execute([$vehicle]);
            $vehicledata = $stmt->fetch(PDO::FETCH_ASSOC);

            $stmt = $temppdo->prepare("SELECT name, status FROM drivers WHERE id=?");
            $stmt->execute([$driver]);
            $driverdata = $stmt->fetch(PDO::FETCH_ASSOC);

            $type = $driverdata['status'] == "OUT" ? "IN" : "OUT";

            $currentDateTime = date("YmdHis");

            if (isset($_FILES['photo1'])) {
                $file = $_FILES['photo1'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];

                $file_destination1 = '../files/'.$folder.'/vehicle_login/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = $driverdata['name']."_".$vehicledata['name']."_".$vehicledata['numberplate']."_1_{$type}_{$currentDateTime}.{$file_extension}";
                $file_destination1 .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination1);

                $isFile = true;
            }

            if (isset($_FILES['photo2'])) {
                $file = $_FILES['photo2'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];

                $file_destination2 = '../files/'.$folder.'/vehicle_login/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = $driverdata['name']."_".$vehicledata['name']."_".$vehicledata['numberplate']."_2_{$type}_{$currentDateTime}.{$file_extension}";
                $file_destination2 .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination2);

                $isFile = true;
            }

            if (isset($_FILES['photo3'])) {
                $file = $_FILES['photo3'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];

                $file_destination3 = '../files/'.$folder.'/vehicle_login/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = $driverdata['name']."_".$vehicledata['name']."_".$vehicledata['numberplate']."_3_{$type}_{$currentDateTime}.{$file_extension}";
                $file_destination3 .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination3);

                $isFile = true;
            }

            if (isset($_FILES['photo4'])) {
                $file = $_FILES['photo4'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];

                $file_destination4 = '../files/'.$folder.'/vehicle_login/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = $driverdata['name']."_".$vehicledata['name']."_".$vehicledata['numberplate']."_4_{$type}_{$currentDateTime}.{$file_extension}";
                $file_destination4 .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination4);

                $isFile = true;
            }

            if (isset($_FILES['photo5'])) {
                $file = $_FILES['photo5'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];

                $file_destination5 = '../files/'.$folder.'/vehicle_login/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = $driverdata['name']."_".$vehicledata['name']."_".$vehicledata['numberplate']."_5_{$type}_{$currentDateTime}.{$file_extension}";
                $file_destination5 .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination5);

                $isFile = true;
            }
            // Ez felulirja a kepeket ha login ha logout
            $stmt = $temppdo->prepare("UPDATE driver_logs SET photos=? WHERE id = (SELECT id FROM driver_logs WHERE driver_id=? AND vehicle_id=? AND km=? ORDER BY id DESC LIMIT 1)");
            $stmt->execute([$file_destination1 . ", " . $file_destination2 . ", " . $file_destination3 . ", " . $file_destination4 . ", " . $file_destination5, $driver, $vehicle, $km]);

            if ($stmt->rowCount()) {
                echo 'Upload successful';
            } else {
                echo 'Upload failed';
            }
        }

        // Vehicle expense - driver, vehicle, km, photo, remarks, type
        if ($_POST['action'] === "vehicle-expense" && isset($_POST['driver']) && isset($_POST['vehicle']) && isset($_POST['km']) && isset($_POST['type']) && isset($_POST['remarks']) && isset($_POST['cost'])) {
            $driver = $_POST['driver'];
            $vehicle = $_POST['vehicle'];
            $km = filter_var($_POST['km'], FILTER_SANITIZE_NUMBER_INT);
            $type = $_POST['type'];
            $remarks = $_POST['remarks'];
            $cost = filter_var($_POST['cost'], FILTER_SANITIZE_NUMBER_FLOAT);

            $isFile = false;

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $pdo->prepare("SELECT folder FROM users WHERE id=?");
            $stmt->execute([$_SESSION['user_id']]);

            $folder = $stmt->fetchColumn();

            $stmt = $temppdo->prepare("SELECT name, numberplate FROM vehicles WHERE id=?");
            $stmt->execute([$vehicle]);
            $vehicledata = $stmt->fetch(PDO::FETCH_ASSOC);

            $stmt = $temppdo->prepare("SELECT name, status FROM drivers WHERE id=?");
            $stmt->execute([$driver]);
            $driverdata = $stmt->fetch(PDO::FETCH_ASSOC);

            $currentDateTime = date("YmdHis");

            if (isset($_FILES['photo'])) {
                $file = $_FILES['photo'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];

                $file_destination = '../files/'.$folder.'/vehicle_expenses/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = $driverdata['name']."_".$vehicledata['name']."_".$vehicledata['numberplate']."_expenses_{$type}_{$currentDateTime}.{$file_extension}";
                $file_destination .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination);

                $isFile = true;
            }

            $stmt = $temppdo->prepare("INSERT INTO vehicle_expenses SET time=?, driver_id=?, vehicle_id=?, km=?, type=?, cost=?, remarks=?, photo=?");
            $stmt->execute([date("Y-m-d H:i:s"), $driver, $vehicle, $km, $type, $cost, $remarks, $file_destination]);

            echo json_encode(["success" => true, "message" => "Expense saved"]);

            closeConnection($temppdo);
        }

        // Vehicle Logs - filter
        if ($_POST['action'] === 'vehicle-logs-filter' && isset($_POST['from']) && isset($_POST['to']) && isset($_POST['vehicle']) && isset($_POST['driver'])) {
            $from = $_POST['from'];
            $to = $_POST['to'];
            $vehicle = $_POST['vehicle'];
            $driver = $_POST['driver'];

            if ($vehicle == 'all') {
                $vehicle_condition = "1=1";
            } else {
                $vehicle_condition = "IN_shift.vehicle_id='".$vehicle."'";
            }

            if ($driver == 'all') {
                $driver_condition = "1=1";
            } else {
                $driver_condition = "IN_shift.driver_id='".$driver."'";
            }
            
            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT
                IN_shift.id AS inid,
                OUT_shift.id AS outid,
                DATE(IN_shift.time) AS shift_date,
                SUBSTRING(TIME(IN_shift.time), 1, 5) AS shift_start,
                SUBSTRING(TIME(OUT_shift.time), 1, 5) AS shift_end,
                SUBSTRING(TIMEDIFF(OUT_shift.time, IN_shift.time), 1, 5) AS time_spent,
                (SELECT drivers.name FROM drivers WHERE drivers.id=IN_shift.driver_id) AS driver,
                (SELECT CONCAT(vehicles.name, ' (', vehicles.numberplate, ')') FROM vehicles WHERE vehicles.id=IN_shift.vehicle_id) AS vehicle,
                IN_shift.km AS km_start,
                OUT_shift.km AS km_end,
                OUT_shift.km - IN_shift.km AS km_difference,
                CONCAT(IN_shift.photos, ', ', OUT_shift.photos) AS photos
            FROM
                driver_logs AS IN_shift
            LEFT JOIN
                driver_logs AS OUT_shift ON IN_shift.driver_id = OUT_shift.driver_id
                                        AND IN_shift.vehicle_id = OUT_shift.vehicle_id
                                        AND OUT_shift.time = (
                                            SELECT MIN(time)
                                            FROM driver_logs
                                            WHERE action = 'OUT'
                                            AND driver_id = IN_shift.driver_id
                                            AND vehicle_id = IN_shift.vehicle_id
                                            AND time > IN_shift.time
                                            AND time BETWEEN ? AND ?
                                        )
            WHERE
                IN_shift.action = 'IN'
                AND ".$vehicle_condition."
                AND ".$driver_condition."
                AND IN_shift.time BETWEEN ? AND ?;
            ");
            $stmt->execute([$from, $to, $from, $to]);
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

            header('Content-Type: application/json');
            echo json_encode($data);

            closeConnection($temppdo);
        }

        // Vehicle Logs - save
        if ($_POST['action'] === 'vehicle-logs-save' && isset($_POST['inid']) && isset($_POST['outid']) && isset($_POST['date']) && isset($_POST['from']) && isset($_POST['to']) && isset($_POST['vehicle']) && isset($_POST['driver']) && isset($_POST['startkm']) && isset($_POST['endkm'])) {
            $inid = $_POST['inid'];
            $outid = $_POST['outid'];
            $date = $_POST['date'];
            $from = $_POST['from'];
            $to = $_POST['to'];
            $vehicle = $_POST['vehicle'];
            $driver = $_POST['driver'];
            $startkm = filter_var($_POST['startkm'], FILTER_SANITIZE_NUMBER_INT);
            $endkm = filter_var($_POST['endkm'], FILTER_SANITIZE_NUMBER_INT);

            $timein = $date . " " . $from . ":00";
            $timeout = $date . " " . $to . ":00";

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            // UPDATE
            $stmt = $temppdo->prepare("UPDATE driver_logs SET time=?, driver_id=?, vehicle_id=?, km=? WHERE id=?");
            $stmt->execute([$timein, $driver, $vehicle, $startkm, $inid]);
            $stmt = $temppdo->prepare("UPDATE driver_logs SET time=?, driver_id=?, vehicle_id=?, km=? WHERE id=?");
            $stmt->execute([$timeout, $driver, $vehicle, $endkm, $outid]);

            $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
            $stmt->execute([$fleet_manager, "VEHICLE & DRIVER LOG UPDATED", "ID $inid - $outid log was updated", $_SERVER['REMOTE_ADDR']]);

            echo json_encode(['success' => true, 'message' => 'Vehicle log updated successfully']);

            closeConnection($temppdo);
        }

        // Categories - save
        if ($_POST['action'] === 'categories-save' && isset($_POST['id']) && isset($_POST['name'])) {
            $id = $_POST['id'];
            $name = filter_var($_POST['name'], FILTER_SANITIZE_STRING);

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            closeConnection($temppdo);

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            if (intval($id) != -1) {
                // UPDATE

                $stmt = $temppdo->prepare("UPDATE categories SET name=? WHERE id=?");
                $stmt->execute([$name, $id]);

                $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                $stmt->execute([$fleet_manager, "CATEGORY UPDATED", "$name category was updated", $_SERVER['REMOTE_ADDR']]);

                echo json_encode(['success' => true, 'message' => 'Category updated successfully']);
            } else {
                // INSERT

                $stmt = $temppdo->prepare("INSERT INTO categories SET name=?");
                $stmt->execute([$name]);

                $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                $stmt->execute([$fleet_manager, "NEW CATEGORY CREATED", "$name category was created", $_SERVER['REMOTE_ADDR']]);

                echo json_encode(['success' => true, 'message' => 'Category created successfully']);
            }

            closeConnection($temppdo);
        }

        // Expenses filter
        if ($_POST['action'] === 'expenses-filter' && isset($_POST['from']) && isset($_POST['to']) && isset($_POST['type']) && isset($_POST['driver']) && isset($_POST['vehicle'])) {
            $from = $_POST['from'];
            $to = $_POST['to'];
            $vehicle = $_POST['vehicle'];
            $type = $_POST['type'];
            $driver = $_POST['driver'];

            if ($vehicle == 'all') {
                $vehicle_condition = "1=1";
            } else {
                $vehicle_condition = "a.vehicle_id='".$vehicle."'";
            }

            if ($type == 'all') {
                $type_condition = "1=1";
            } else {
                $type_condition = "a.type='".$type."'";
            }

            if ($driver == 'all') {
                $driver_condition = "1=1";
            } else {
                $driver_condition = "a.driver_id='".$driver."'";
            }

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT a.id, a.time, b.name AS driver, c.name AS vehicle, c.numberplate, a.km, a.type, a.cost, a.remarks, a.photo FROM vehicle_expenses a JOIN drivers b ON a.driver_id=b.id JOIN vehicles c ON a.vehicle_id=c.id WHERE DATE(a.time)>=? AND DATE(a.time)<=? AND $vehicle_condition AND $driver_condition AND $type_condition");
            $stmt->execute([$from, $to]);
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

            header('Content-Type: application/json');
            echo json_encode($data);

            closeConnection($temppdo);
        }

        // Expense-save - date, time, driver, vehicle, km, photo, remarks, type
        if ($_POST['action'] === "expense-save" && isset($_POST['id']) && isset($_POST['date']) && isset($_POST['time']) && isset($_POST['driver']) && isset($_POST['vehicle']) && isset($_POST['km']) && isset($_POST['type']) && isset($_POST['remarks']) && isset($_POST['cost'])) {
            $id = $_POST['id'];
            $date = $_POST['date'];
            $time = $_POST['time'];
            $driver = $_POST['driver'];
            $vehicle = $_POST['vehicle'];
            $km = filter_var($_POST['km'], FILTER_SANITIZE_NUMBER_INT);
            $type = $_POST['type'];
            $remarks = $_POST['remarks'];
            $cost = filter_var($_POST['cost'], FILTER_SANITIZE_NUMBER_FLOAT);

            $isFile = false;

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $pdo->prepare("SELECT folder FROM users WHERE id=?");
            $stmt->execute([$_SESSION['user_id']]);

            $folder = $stmt->fetchColumn();

            $stmt = $temppdo->prepare("SELECT name, numberplate FROM vehicles WHERE id=?");
            $stmt->execute([$vehicle]);
            $vehicledata = $stmt->fetch(PDO::FETCH_ASSOC);

            $stmt = $temppdo->prepare("SELECT name, status FROM drivers WHERE id=?");
            $stmt->execute([$driver]);
            $driverdata = $stmt->fetch(PDO::FETCH_ASSOC);

            $currentDateTime = $date . " " . $time . ":00";

            if (isset($_FILES['photo'])) {
                $file = $_FILES['photo'];
                $file_name = $file['name'];
                $file_tmp = $file['tmp_name'];

                $file_destination = '../files/'.$folder.'/vehicle_expenses/';

                $allowed_extensions = array('jpg', 'jpeg', 'png', 'gif');
                $file_extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));
                if (!in_array($file_extension, $allowed_extensions)) {
                    echo json_encode(['success' => false, 'message' => "Invalid file type. Please upload a photo (JPG, JPEG, PNG, GIF)."]);
                    exit;
                }

                $new_file_name = $driverdata['name']."_".$vehicledata['name']."_".$vehicledata['numberplate']."_expenses_{$type}_{$currentDateTime}.{$file_extension}";
                $file_destination .= $new_file_name;

                move_uploaded_file($file_tmp, $file_destination);

                $isFile = true;
            }

            if (intval($id) == -1) {
                if ($isFile) {
                    $stmt = $temppdo->prepare("INSERT INTO vehicle_expenses SET time=?, driver_id=?, vehicle_id=?, km=?, type=?, cost=?, remarks=?, photo=?");
                    $stmt->execute([$currentDateTime, $driver, $vehicle, $km, $type, $cost, $remarks, $file_destination]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "NEW EXPENSE INTRODUCED", "Expense for ".$vehicledata['name']." (".$vehicledata['numberplate'].") was introduced ($type). New photo uploaded", $_SERVER['REMOTE_ADDR']]);
                } else {
                    $stmt = $temppdo->prepare("INSERT INTO vehicle_expenses SET time=?, driver_id=?, vehicle_id=?, km=?, type=?, cost=?, remarks=?");
                    $stmt->execute([$currentDateTime, $driver, $vehicle, $km, $type, $cost, $remarks]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "NEW EXPENSE INTRODUCED", "Expense for ".$vehicledata['name']." (".$vehicledata['numberplate'].") was introduced ($type)", $_SERVER['REMOTE_ADDR']]);
                }
            } else {
                if ($isFile) {
                    $stmt = $temppdo->prepare("UPDATE vehicle_expenses SET time=?, driver_id=?, vehicle_id=?, km=?, type=?, cost=?, remarks=?, photo=? WHERE id=?");
                    $stmt->execute([$currentDateTime, $driver, $vehicle, $km, $type, $cost, $remarks, $file_destination, $id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "EXPENSE UPDATED", "Expense for ".$vehicledata['name']." (".$vehicledata['numberplate'].") was updated ($type). New photo uploaded", $_SERVER['REMOTE_ADDR']]);
                } else {
                    $stmt = $temppdo->prepare("UPDATE vehicle_expenses SET time=?, driver_id=?, vehicle_id=?, km=?, type=?, cost=?, remarks=? WHERE id=?");
                    $stmt->execute([$currentDateTime, $driver, $vehicle, $km, $type, $cost, $remarks, $id]);

                    $stmt = $temppdo->prepare("INSERT INTO logs SET time=NOW(), fleet_manager_id=?, action=?, details=?, ip_address=?");
                    $stmt->execute([$fleet_manager, "EXPENSE UPDATED", "Expense for ".$vehicledata['name']." (".$vehicledata['numberplate'].") was updated ($type)", $_SERVER['REMOTE_ADDR']]);
                }
            }            

            echo json_encode(["success" => true, "message" => "Expense saved"]);

            closeConnection($temppdo);
        }

        // Logs - filter
        if ($_POST['action'] === 'logs-filter' && isset($_POST['from']) && isset($_POST['to']) && isset($_POST['manager'])) {
            $from = $_POST['from'];
            $to = $_POST['to'];
            $manager = $_POST['manager'];

            if ($manager == 'all') {
                $manager_condition = "1=1";
            } else {
                $manager_condition = "fleet_manager_id='".$manager."'";
            }

            $credentials = getUserCredentialsById($pdo, $_SESSION['user_id']);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT SUBSTRING(time, 1, 10) AS date, SUBSTRING(time, 12, 8) AS time, IFNULL(CASE WHEN fleet_manager_id=-1 THEN 'Superadmin' ELSE (SELECT name FROM fleet_managers WHERE fleet_managers.id=logs.fleet_manager_id) END, '-') AS manager, action, details, ip_address FROM logs WHERE DATE(time)<=? AND DATE(time)>=? AND $manager_condition");
            $stmt->execute([$to, $from]);
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

            header('Content-Type: application/json');
            echo json_encode($data);

            closeConnection($temppdo);
        }

        if ($_POST['action'] === 'get-cars') {
            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT id, name, numberplate FROM vehicles ORDER BY name, numberplate");
            $stmt->execute([]);
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

            header('Content-Type: application/json');
            echo json_encode($data);

            closeConnection($temppdo);
        }

        if ($_POST['action'] === 'get-previous-km' && isset($_POST['driver'])) {
            $driverinput = $_POST['driver'];

            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT a.km FROM driver_logs AS a JOIN vehicles AS b ON a.vehicle_id=b.id WHERE a.driver_id=? ORDER BY a.id DESC LIMIT 1");
            $stmt->execute([$driverinput]);
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

            $km = $data['km'];

            echo json_encode($km);

            closeConnection($temppdo);
        }

        if ($_POST['action'] === 'get-vehicle-info' && isset($_POST['vehicle'])) {
            $vehicleinput = $_POST['vehicle'];

            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT id, name, numberplate FROM vehicles WHERE id=?");
            $stmt->execute([$vehicleinput]);
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

            header('Content-Type: application/json');
            echo json_encode($data);

            closeConnection($temppdo);
        }

        // Driver & vehicle data for driver_panel
        if ($_POST['action'] === 'driver-vehicle-data' && isset($_POST['driver'])) {
            $driverinput = $_POST['driver'];

            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT name, status, vehicle_id FROM drivers WHERE id=?");
            $stmt->execute([$driverinput]);
            $driverdata = $stmt->fetch(PDO::FETCH_ASSOC);

            $driver = $driverdata['name'];
            $status = $driverdata['status'];
            $vehicle_id = $driverdata['vehicle_id'];

            if ($status == "IN") {
                $stmt = $temppdo->prepare("SELECT vehicle_id, km FROM driver_logs WHERE driver_id=? ORDER BY id DESC LIMIT 1");
                $stmt->execute([$driverinput]);
                $result = $stmt->fetch(PDO::FETCH_ASSOC);

                $vehicle_id = $result['vehicle_id'];
                $km = $result['km'];

                $stmt = $temppdo->prepare("SELECT name, numberplate FROM vehicles WHERE id=? ORDER BY id DESC LIMIT 1");
                $stmt->execute([$vehicle_id]);
                $vehicledata = $stmt->fetch(PDO::FETCH_ASSOC);

                $name = $vehicledata['name'];
                $numberplate = $vehicledata['numberplate'];

                $response['vehicle'] = [
                    'vehicle_id' => $vehicle_id,
                    'name' => $name,
                    'numberplate' => $numberplate,
                    'km' => $km
                ];

                $stmt = $temppdo->prepare("SELECT date_start, date_end, CASE WHEN date_end<CURDATE() THEN 'EXPIRED' ELSE 'VALID' END AS validity FROM vehicle_data WHERE type='insurance' AND vehicle_id=? ORDER BY date_start DESC LIMIT 1");
                $stmt->execute([$vehicle_id]);
                $result = $stmt->fetch(PDO::FETCH_ASSOC);

                $insurance_from = $result['date_start'];
                $insurance_to = $result['date_end'];
                $insurance_validity = $result['validity'];

                $response['insurance'] = [
                    'date_start' => $insurance_from,
                    'date_end' => $insurance_to,
                    'validity' => $insurance_validity
                ];

                $response['tuv'] = [
                    'date_start' => $tuv_from,
                    'date_end' => $tuv_to,
                    'validity' => $tuv_validity
                ];

                $stmt = $temppdo->prepare("SELECT date_start, date_end, CASE WHEN date_end<CURDATE() THEN 'EXPIRED' ELSE 'VALID' END AS validity FROM vehicle_data WHERE type='tuv' AND vehicle_id=? ORDER BY date_start DESC LIMIT 1");
                $stmt->execute([$vehicle_id]);
                $result = $stmt->fetch(PDO::FETCH_ASSOC);

                $tuv_from = $result['date_start'];
                $tuv_to = $result['date_end'];
                $tuv_validity = $result['validity'];

                $stmt = $temppdo->prepare("SELECT date_start, km+remarks AS until, CASE WHEN km+remarks < ? THEN 'EXPIRED' ELSE 'VALID' END AS validity FROM vehicle_data WHERE type='oil' AND vehicle_id=? ORDER BY date_start DESC LIMIT 1");
                $stmt->execute([$km, $vehicle_id]);
                $result = $stmt->fetch(PDO::FETCH_ASSOC);

                $oil_from = $result['date_start'];
                $oil_to = $result['until'];
                $oil_validity = $result['validity'];

                $response['oil'] = [
                    'date_start' => $oil_from,
                    'until' => $oil_to,
                    'validity' => $oil_validity
                ];

                header('Content-Type: application/json');
                echo json_encode($response);
            }

            closeConnection($temppdo);
        }

        if ($_POST['action'] === 'get-last-km' && isset($_POST['driver_id']) && isset($_POST['vehicle_id'])) {
            $driver_id = $_POST['driver_id'];
            $vehicle_id = $POST['vehicle_id'];

            $credentials = getUserCredentialsById($pdo, 1);

            $dbname = $credentials['db_name'];
            $db_username = $credentials['db_user'];
            $db_password = openssl_decrypt($credentials['openssl'], ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $encrypted_password = openssl_encrypt($password, ENCRYPTION, base64_decode(KEY), 0, base64_decode(IV));

            $temppdo = connectToDatabase(HOST, PREFIX.$dbname, PREFIX.$db_username, $db_password);

            $stmt = $temppdo->prepare("SELECT km FROM driver_logs WHERE driver_id=? AND vehicle_id=? ORDER BY time DESC");
            $stmt->execute([$driver_id, $vehicle_id]);
            $km = $stmt->fetchColumn();

            echo json_encode($km);

            closeConnection($temppdo);
        }
    }

    closeConnection($pdo);

?>