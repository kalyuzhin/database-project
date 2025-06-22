-- Настройка прокси для домена "Джемы"
-- Создание расширения для работы с внешними данными
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Создание серверов для каждого шарда
CREATE SERVER jams_shard1 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'jams_shard1', port '5432', dbname 'jams');

CREATE SERVER jams_shard2 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'jams_shard2', port '5432', dbname 'jams');

CREATE SERVER users_proxy_server FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS(
      host 'users_proxy',
      port '5432',
      dbname 'users'
  );

CREATE SERVER reviews_proxy_server FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS(
      host 'reviews_proxy',
      port '5432',
      dbname 'reviews'
  );

CREATE SERVER games_proxy_server FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS(
      host 'games_proxy',
      port '5432',
      dbname 'games'
  );

-- Создание пользовательских маппингов
CREATE USER MAPPING FOR postgres SERVER jams_shard1
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR postgres SERVER jams_shard2
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR CURRENT_USER SERVER users_proxy_server
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR CURRENT_USER SERVER reviews_proxy_server
    OPTIONS (user 'postgres', password 'postgres');

CREATE USER MAPPING FOR CURRENT_USER SERVER games_proxy_server
    OPTIONS (user 'postgres', password 'postgres');

-- Создание внешних таблиц для каждого шарда
CREATE FOREIGN TABLE jams_shard1 (
    id INTEGER,
    name CHAR(30),
    author_id INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    start_date DATE,
    deadline DATE,
    end_date DATE,
    description TEXT
) SERVER jams_shard1 OPTIONS (schema_name 'public', table_name 'jams');

CREATE FOREIGN TABLE jams_shard2 (
    id INTEGER,
    name CHAR(30),
    author_id INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    start_date TIMESTAMP,
    deadline TIMESTAMP,
    end_date TIMESTAMP,
    description TEXT
) SERVER jams_shard2 OPTIONS (schema_name 'public', table_name 'jams');

CREATE FOREIGN TABLE users (
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
) SERVER users_proxy_server OPTIONS (schema_name 'public', table_name 'users');

CREATE FOREIGN TABLE reviews (
    id SERIAL,
    user_id INTEGER,
    user_mark DECIMAL(2,1) CHECK (
      user_mark IN (0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5)
    ),
    criterion VARCHAR(255),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    game_id INTEGER,
    jam_id INTEGER
) SERVER reviews_proxy_server OPTIONS (schema_name 'public', table_name 'reviews');

CREATE FOREIGN TABLE games (
    id INTEGER,
    name VARCHAR(60),
    description TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    author_id INTEGER
) SERVER games_proxy_server OPTIONS (schema_name 'public', table_name 'games');

-- Создание представления, объединяющего все шарды
CREATE VIEW jams AS
    SELECT * FROM jams_shard1
    UNION ALL
    SELECT * FROM jams_shard2;

-- Создание внешних таблиц для jams_tags
CREATE FOREIGN TABLE jams_participants_shard1 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    jam_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role VARCHAR(50),
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (jam_id) REFERENCES jams(id) ON DELETE CASCADE
) SERVER jams_shard1 OPTIONS (schema_name 'public', table_name 'jams_participants');

CREATE FOREIGN TABLE jams_participants_shard2 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    jam_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role VARCHAR(50),
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (jam_id) REFERENCES jams(id) ON DELETE CASCADE
) SERVER jams_shard1 OPTIONS (schema_name 'public', table_name 'jams_participants');

CREATE VIEW jams_participants AS
    SELECT * FROM jams_participants_shard1
    UNION ALL
    SELECT * FROM jams_participants_shard2;

CREATE FOREIGN TABLE jams_tags_shard1 (
    id INTEGER,
    jam_id INTEGER,
    tag_id INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER jams_shard1 OPTIONS (schema_name 'public', table_name 'jams_tags');

CREATE FOREIGN TABLE jams_tags_shard2 (
    id INTEGER,
    jam_id INTEGER,
    tag_id INTEGER,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER jams_shard2 OPTIONS (schema_name 'public', table_name 'jams_tags');

CREATE VIEW jams_tags AS
    SELECT * FROM jams_tags_shard1
    UNION ALL
    SELECT * FROM jams_tags_shard2;

-- Импорт справочных таблиц из первого шарда (они идентичны на всех шардах)
CREATE FOREIGN TABLE tags (
    id INTEGER,
    name TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) SERVER jams_shard1 OPTIONS (schema_name 'public', table_name 'tags');

-- Функция для определения шарда по ID джема
CREATE OR REPLACE FUNCTION get_jam_shard(jam_id INTEGER)
RETURNS TEXT AS $$
BEGIN
    IF MOD(jam_id, 2)=0 THEN
        RETURN 'jams_shard1';
    ELSIF MOD(jam_id, 2)=1 THEN
        RETURN 'jams_shard2';
    ELSE
        RAISE EXCEPTION 'Invalid jam_id: %', jam_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция для вставки джема в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_jams_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
BEGIN
  IF NEW.id IS NULL THEN
    RAISE EXCEPTION 'id must be specified for insertion';
  END IF;

  target_shard := get_jam_shard(NEW.id);

  IF target_shard = 'jams_shard1' THEN
    INSERT INTO jams_shard1(name, author_id, created_at, updated_at, start_date, deadline, end_date, description)
    VALUES (NEW.name, NEW.author_id, NEW.created_at, NEW.updated_at, NEW.start_date, NEW.deadline, NEW.end_date, NEW.description);
  ELSIF target_shard = 'jams_shard2' THEN
    INSERT INTO jams_shard2(name, author_id, created_at, updated_at, start_date, deadline, end_date, description)
    VALUES (NEW.name, NEW.author_id, NEW.created_at, NEW.updated_at, NEW.start_date, NEW.deadline, NEW.end_date, NEW.description);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки джема
CREATE TRIGGER trg_insert_jams
INSTEAD OF INSERT ON jams
FOR EACH ROW
EXECUTE FUNCTION insert_into_jams_view();

-- Функция для вставки связи джема с тегом в соответствующий шард
CREATE OR REPLACE FUNCTION insert_into_jams_tags_view()
RETURNS TRIGGER AS $$
DECLARE
  target_shard TEXT;
BEGIN
  IF NEW.jam_id IS NULL THEN
    RAISE EXCEPTION 'jam_id must be specified for insertion';
  END IF;

  target_shard := get_jam_shard(NEW.jam_id);

  IF target_shard = 'jams_shard1' THEN
    INSERT INTO jams_tags_shard1 VALUES (NEW.*);
  ELSIF target_shard = 'jams_shard2' THEN
    INSERT INTO jams_tags_shard2 VALUES (NEW.*);
  ELSE
    RAISE EXCEPTION 'Unknown shard: %', target_shard;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Триггер для вставки связи джема с тегом
CREATE TRIGGER trg_insert_jams_tags
INSTEAD OF INSERT ON jams_tags
FOR EACH ROW
EXECUTE FUNCTION insert_into_jams_tags_view();

