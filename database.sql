-- WhereIsMyBus / SimTransit Database Schema
-- You can import this file directly into XAMPP (phpMyAdmin) or any MySQL viewer

CREATE DATABASE IF NOT EXISTS `college_bus`;
USE `college_bus`;

-- 1. Core Tables
CREATE TABLE IF NOT EXISTS stops (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ext_stop_id VARCHAR(128),
    name VARCHAR(255) NOT NULL,
    lat DECIMAL(10, 8),
    lng DECIMAL(11, 8),
    stop_code VARCHAR(50),
    is_active TINYINT(1) DEFAULT 1,
    UNIQUE KEY (name)
);

CREATE TABLE IF NOT EXISTS buses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bus_no VARCHAR(50) NOT NULL UNIQUE,
    driver_name VARCHAR(255),
    phone_no VARCHAR(20),
    model VARCHAR(100),
    capacity INT,
    label VARCHAR(255),
    is_active TINYINT(1) DEFAULT 1
);

CREATE TABLE IF NOT EXISTS routes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ext_route_id VARCHAR(128),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(20),
    is_active TINYINT(1) DEFAULT 1,
    UNIQUE KEY (name)
);

CREATE TABLE IF NOT EXISTS trips (
    id INT AUTO_INCREMENT PRIMARY KEY,
    bus_id INT,
    route_id INT,
    service_date DATE,
    status ENUM('scheduled', 'active', 'completed', 'cancelled') DEFAULT 'scheduled',
    ext_trip_id VARCHAR(128),
    FOREIGN KEY (bus_id) REFERENCES buses(id),
    FOREIGN KEY (route_id) REFERENCES routes(id)
);

-- 2. Schedule Tables
CREATE TABLE IF NOT EXISTS trip_stop_times (
    id INT AUTO_INCREMENT PRIMARY KEY,
    trip_id INT NOT NULL,
    stop_id INT NOT NULL,
    stop_order INT NOT NULL,
    sched_arrival TIME,
    sched_departure TIME,
    actual_arrival TIME,
    actual_departure TIME,
    status VARCHAR(50) DEFAULT 'scheduled',
    FOREIGN KEY (trip_id) REFERENCES trips(id),
    FOREIGN KEY (stop_id) REFERENCES stops(id)
);

-- 3. Geometry (Routing)
CREATE TABLE IF NOT EXISTS route_paths (
    id INT AUTO_INCREMENT PRIMARY KEY,
    route_id INT NOT NULL,
    point_order INT NOT NULL,
    lat DECIMAL(10, 8) NOT NULL,
    lng DECIMAL(11, 8) NOT NULL,
    FOREIGN KEY (route_id) REFERENCES routes(id)
);

-- 4. Auth & User State
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reg_no VARCHAR(100) UNIQUE,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    password VARCHAR(255),
    year INT,
    mobile_no VARCHAR(20),
    email VARCHAR(255) UNIQUE,
    college_name VARCHAR(255),
    department VARCHAR(255),
    degree VARCHAR(255) DEFAULT 'N/A',
    location VARCHAR(255),
    bus_stop VARCHAR(255),
    role ENUM('student', 'admin', 'driver') DEFAULT 'student',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS otp_codes (
    target VARCHAR(255) PRIMARY KEY,
    code VARCHAR(10) NOT NULL,
    expires_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS recent_searches (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    from_stop_id INT,
    to_stop_id INT,
    from_name VARCHAR(255),
    to_name VARCHAR(255),
    role VARCHAR(50),
    ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- 5. GPS & Logs
CREATE TABLE IF NOT EXISTS gps_points (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    trip_id INT,
    ext_vehicle_id VARCHAR(128),
    ext_trip_id VARCHAR(128),
    route_id_str VARCHAR(128),
    route_name VARCHAR(255),
    direction VARCHAR(50),
    ts DATETIME NOT NULL,
    lat DECIMAL(10, 8) NOT NULL,
    lng DECIMAL(11, 8) NOT NULL,
    speed FLOAT,
    heading FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX (ts),
    INDEX (ext_vehicle_id, ts),
    INDEX (trip_id, ts)
);


-- ==========================================
-- ================= SEED DATA ==============
-- ==========================================

INSERT IGNORE INTO stops (id, name, lat, lng, is_active) VALUES 
(1, 'Saveetha University', 13.028757, 80.019844, 1),
(2, 'Poonamallee', 13.0473, 80.0945, 1),
(3, 'Madhuravoyal', 13.0673, 80.1645, 1),
(4, 'Koyambedu', 13.0732, 80.1912, 1);

INSERT IGNORE INTO routes (id, name) VALUES 
(1, 'Saveetha University → Koyambedu');

INSERT IGNORE INTO buses (id, bus_no, label) VALUES 
(1, 'Bus 1', 'Saveetha Shuttle');

INSERT IGNORE INTO trips (id, bus_id, route_id, service_date, status) VALUES 
(1, 1, 1, CURRENT_DATE, 'active');

INSERT IGNORE INTO trip_stop_times (trip_id, stop_id, stop_order, sched_arrival, sched_departure) VALUES 
(1, 1, 1, '08:00:00', '08:05:00'),
(1, 2, 2, '08:15:00', '08:17:00'),
(1, 3, 3, '08:30:00', '08:32:00'),
(1, 4, 4, '08:45:00', '08:45:00');
