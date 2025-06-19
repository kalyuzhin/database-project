-- Настройка прокси для домена "Пользователи"
-- Создание расширения для работы с внешними данными
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Создание серверов для каждого шарда
CREATE SERVER users_shard1 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'users_shard1', port '5432', dbname 'users');

CREATE SERVER users_shard2 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'users_shard2', port '5432', dbname 'users');

-- Создание пользовательских маппингов
CREATE USER MAPPING FOR postgres SERVER users_shard1
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR postgres SERVER users_shard2
    OPTIONS (user 'postgres', password 'postgres');

-- Создание внешних таблиц для каждого шарда
CREATE FOREIGN TABLE users_shard1 (
    id INTEGER,
    full_name VARCHAR(255),
    nickname VARCHAR(255),
    email VARCHAR(255),
    pswd_hash TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    birthday DATE,
    phone_number CHAR(1),
    location VARCHAR(255)
) SERVER users_shard1 OPTIONS (schema_name 'public', table_name 'users');

CREATE FOREIGN TABLE users_shard2 (
    id INTEGER,
    full_name VARCHAR(255),
    nickname VARCHAR(255),
    email VARCHAR(255),
    pswd_hash TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    birthday DATE,
    phone_number CHAR(1),
    location VARCHAR(255)
) SERVER users_shard2 OPTIONS (schema_name 'public', table_name 'users');

-- Создание представления, объединяющего все шарды
CREATE VIEW users AS
    SELECT * FROM users_shard1
    UNION ALL
    SELECT * FROM users_shard2;

-- Создание внешних таблиц для friendships
CREATE FOREIGN TABLE friendships_shard1 (
    id INTEGER,
    user_id INTEGER,
    friend_id INTEGER,
    status VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER users_shard1 OPTIONS (schema_name 'public', table_name 'friendships');

CREATE FOREIGN TABLE friendships_shard2 (
    id INTEGER,
    user_id INTEGER,
    friend_id INTEGER,
    status VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER users_shard2 OPTIONS (schema_name 'public', table_name 'friendships');

CREATE VIEW friendships AS
    SELECT * FROM friendships_shard1
    UNION ALL
    SELECT * FROM friendships_shard2;

-- Создание внешних таблиц для sessions
CREATE FOREIGN TABLE sessions_shard1 (
    id INTEGER,
    user_id INTEGER,
    session_id VARCHAR(255),
    ip_address VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    browser VARCHAR(255)
) SERVER users_shard1 OPTIONS (schema_name 'public', table_name 'sessions');

CREATE FOREIGN TABLE sessions_shard2 (
    id INTEGER,
    user_id INTEGER,
    session_id VARCHAR(255),
    ip_address VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    browser VARCHAR(255)
) SERVER users_shard2 OPTIONS (schema_name 'public', table_name 'sessions');

CREATE VIEW sessions AS
    SELECT * FROM sessions_shard1
    UNION ALL
    SELECT * FROM sessions_shard2;

-- Создание внешних таблиц для notifications
CREATE FOREIGN TABLE notifications_shard1 (
    id INTEGER,
    recipient_id INTEGER,
    actor_id INTEGER,
    action VARCHAR(255),
    read BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER users_shard1 OPTIONS (schema_name 'public', table_name 'notifications');

CREATE FOREIGN TABLE notifications_shard2 (
    id INTEGER,
    recipient_id INTEGER,
    actor_id INTEGER,
    action VARCHAR(255),
    read BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER users_shard2 OPTIONS (schema_name 'public', table_name 'notifications');

CREATE VIEW notifications AS
    SELECT * FROM notifications_shard1
    UNION ALL
    SELECT * FROM notifications_shard2;

-- Функция для определения шарда по ID пользователя
CREATE OR REPLACE FUNCTION get_user_shard(user_id INTEGER)
RETURNS TEXT AS $$
BEGIN
    IF MOD(user_id, 2)=0 THEN
        RETURN 'users_shard1';
    ELSIF MOD(user_id, 2)=1 THEN
        RETURN 'users_shard2';
    ELSE
        RAISE EXCEPTION 'Invalid user_id: %', user_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция для вставки пользователя в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_users_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
BEGIN
  IF NEW.id IS NULL THEN
    RAISE EXCEPTION 'id must be specified for insertion';
  END IF;

  target_shard := get_user_shard(NEW.id);

  IF target_shard = 'users_shard1' THEN
    INSERT INTO users_shard1(full_name, nickname, email, pswd_hash, created_at, updated_at, birthday, phone_number, location)
    VALUES (NEW.full_name, NEW.nickname, NEW.email, NEW.pswd_hash, NEW.created_at, NEW.updated_at, NEW.birthday, NEW.phone_number, NEW.location);
  ELSIF target_shard = 'users_shard2' THEN
    INSERT INTO users_shard2(full_name, nickname, email, pswd_hash, created_at, updated_at, birthday, phone_number, location)
    VALUES (NEW.full_name, NEW.nickname, NEW.email, NEW.pswd_hash, NEW.created_at, NEW.updated_at, NEW.birthday, NEW.phone_number, NEW.location);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки пользователя
CREATE TRIGGER trg_insert_users
INSTEAD OF INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION insert_into_users_view();

-- Функция для вставки дружеских отношений в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_friendships_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
BEGIN
  IF NEW.user_id IS NULL THEN
    RAISE EXCEPTION 'user_id must be specified for insertion';
  END IF;

  target_shard := get_user_shard(NEW.user_id);

  IF target_shard = 'users_shard1' THEN
    INSERT INTO friendships_shard1 VALUES (NEW.*);
  ELSIF target_shard = 'users_shard2' THEN
    INSERT INTO friendships_shard2 VALUES (NEW.*);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки дружеских отношений
CREATE TRIGGER trg_insert_friendships
INSTEAD OF INSERT ON friendships
FOR EACH ROW
EXECUTE FUNCTION insert_into_friendships_view();

-- Функция для вставки сессий в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_sessions_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
BEGIN
  IF NEW.user_id IS NULL THEN
    RAISE EXCEPTION 'user_id must be specified for insertion';
  END IF;

  target_shard := get_user_shard(NEW.user_id);

  IF target_shard = 'users_shard1' THEN
    INSERT INTO sessions_shard1 VALUES (NEW.*);
  ELSIF target_shard = 'users_shard2' THEN
    INSERT INTO sessions_shard2 VALUES (NEW.*);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки сессий
CREATE TRIGGER trg_insert_sessions
INSTEAD OF INSERT ON sessions
FOR EACH ROW
EXECUTE FUNCTION insert_into_sessions_view();

-- Функция для вставки уведомлений в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_notifications_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
BEGIN
  IF NEW.recipient_id IS NULL THEN
    RAISE EXCEPTION 'recipient_id must be specified for insertion';
  END IF;

  target_shard := get_user_shard(NEW.recipient_id);

  IF target_shard = 'users_shard1' THEN
    INSERT INTO notifications_shard1 VALUES (NEW.*);
  ELSIF target_shard = 'users_shard2' THEN
    INSERT INTO notifications_shard2 VALUES (NEW.*);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки уведомлений
CREATE TRIGGER trg_insert_notifications
INSTEAD OF INSERT ON notifications
FOR EACH ROW
EXECUTE FUNCTION insert_into_notifications_view();

