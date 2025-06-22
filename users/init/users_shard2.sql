-- Создание таблиц для домена "Пользователи" - Шард 2 (нечетные ID)

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
    loc VARCHAR(255),
    CONSTRAINT users_id_range CHECK (MOD(id, 2)=1)
);

-- Таблица friendships
CREATE TABLE friendships (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    friend_id INTEGER,
    status VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT friendships_user_id_range CHECK (MOD(user_id, 2)=1)
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
    CONSTRAINT sessions_user_id_range CHECK (MOD(user_id, 2)=1)
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
    CONSTRAINT notifications_recipient_id_range CHECK (MOD(recipient_id, 2)=1)
);

-- Создание индексов
CREATE INDEX idx_friendships_user_id ON friendships USING btree (user_id);
CREATE INDEX idx_friendships_friend_id ON friendships USING btree (friend_id);
CREATE INDEX idx_sessions_user_id ON sessions USING btree (user_id);
CREATE INDEX idx_notifications_recipient_id ON notifications USING btree (recipient_id);
CREATE INDEX idx_notifications_actor_id ON notifications USING btree (actor_id);

-- Вставка тестовых данных для шарда 2 (пользователи с нечетными ID)

-- Пользователи
INSERT INTO users (id, full_name, nickname, email, pswd_hash, created_at, updated_at, birthday, loc) VALUES 
(1, 'Alice Williams', 'alicew', 'alice.williams@example.com', 'hash321', NOW(), NOW(), '1988-03-12', 'Seattle'),
(3, 'Charlie Brown', 'charlieb', 'charlie.brown@example.com', 'hash654', NOW(), NOW(), '1995-07-22', 'Boston'),
(5, 'Diana Miller', 'dianam', 'diana.miller@example.com', 'hash987', NOW(), NOW(), '1991-09-05', 'Miami');

-- Дружеские отношения
INSERT INTO friendships (user_id, friend_id, status, created_at, updated_at) VALUES 
(1, 2, 'accepted', NOW(), NOW()),
(3, 2, 'pending', NOW(), NOW()),
(5, 4, 'accepted', NOW(), NOW()),
(1, 5, 'accepted', NOW(), NOW());

-- Сессии
INSERT INTO sessions (user_id, session_id, ip_address, created_at, updated_at, browser) VALUES 
(1, 'session321', '192.168.1.4', NOW(), NOW(), 'Edge'),
(3, 'session654', '192.168.1.5', NOW(), NOW(), 'Chrome'),
(5, 'session987', '192.168.1.6', NOW(), NOW(), 'Firefox');

-- Уведомления
INSERT INTO notifications (recipient_id, actor_id, action, read, created_at, updated_at) VALUES 
(1, 2, 'friend_request', FALSE, NOW(), NOW()),
(3, 2, 'message', TRUE, NOW(), NOW()),
(5, 4, 'like', FALSE, NOW(), NOW()),
(1, 3, 'comment', TRUE, NOW(), NOW());

