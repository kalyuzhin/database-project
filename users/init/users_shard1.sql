-- Создание таблиц для домена "Пользователи" - Шард 1 (четные ID)

-- Таблица users
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255),
    nickname VARCHAR(255),
    email VARCHAR(255),
    pswd_hash TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    birthday DATE,
    phone_number CHAR(1),
    location VARCHAR(255),
    CONSTRAINT users_id_range CHECK (MOD(id, 2)=0)
);

-- Таблица friendships
CREATE TABLE friendships (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    friend_id INTEGER,
    status VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT friendships_user_id_range CHECK (MOD(user_id, 2)=0)
);

-- Таблица sessions
CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    session_id VARCHAR(255),
    ip_address VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    browser VARCHAR(255),
    CONSTRAINT sessions_user_id_range CHECK (MOD(user_id, 2)=0)
);

-- Таблица notifications
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    recipient_id INTEGER,
    actor_id INTEGER,
    action VARCHAR(255),
    read BOOLEAN,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT notifications_recipient_id_range CHECK (MOD(recipient_id, 2)=0)
);

-- Создание индексов
CREATE INDEX idx_friendships_user_id ON friendships USING btree (user_id);
CREATE INDEX idx_friendships_friend_id ON friendships USING btree (friend_id);
CREATE INDEX idx_sessions_user_id ON sessions USING btree (user_id);
CREATE INDEX idx_notifications_recipient_id ON notifications USING btree (recipient_id);
CREATE INDEX idx_notifications_actor_id ON notifications USING btree (actor_id);

-- Вставка тестовых данных для шарда 1 (пользователи с четными ID)

-- Пользователи
INSERT INTO users (id, full_name, nickname, email, pswd_hash, created_at, updated_at, birthday, location) VALUES 
(2, 'John Doe', 'johndoe', 'john.doe@example.com', 'hash123', NOW(), NOW(), '1990-01-01', 'New York'),
(4, 'Jane Smith', 'janesmith', 'jane.smith@example.com', 'hash456', NOW(), NOW(), '1992-05-15', 'Los Angeles'),
(6, 'Bob Johnson', 'bobjohnson', 'bob.johnson@example.com', 'hash789', NOW(), NOW(), '1985-11-30', 'Chicago');

-- Дружеские отношения
INSERT INTO friendships (user_id, friend_id, status, created_at, updated_at) VALUES 
(2, 1, 'accepted', NOW(), NOW()),
(2, 3, 'pending', NOW(), NOW()),
(4, 5, 'accepted', NOW(), NOW()),
(6, 7, 'accepted', NOW(), NOW());

-- Сессии
INSERT INTO sessions (user_id, session_id, ip_address, created_at, updated_at, browser) VALUES 
(2, 'session123', '192.168.1.1', NOW(), NOW(), 'Chrome'),
(4, 'session456', '192.168.1.2', NOW(), NOW(), 'Firefox'),
(6, 'session789', '192.168.1.3', NOW(), NOW(), 'Safari');

-- Уведомления
INSERT INTO notifications (recipient_id, actor_id, action, read, created_at, updated_at) VALUES 
(2, 1, 'friend_request', FALSE, NOW(), NOW()),
(2, 3, 'message', TRUE, NOW(), NOW()),
(4, 5, 'like', FALSE, NOW(), NOW()),
(6, 7, 'comment', TRUE, NOW(), NOW());

