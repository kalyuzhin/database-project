-- Создание таблиц для домена "Джемы" - Шард 2 (нечетные ID)

-- Таблица jams
CREATE TABLE jams (
    id SERIAL PRIMARY KEY,
    name CHAR(30),
    author_id INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    start_date DATE,
    deadline DATE,
    end_date DATE,
    description TEXT,
    CONSTRAINT jams_id_range CHECK (MOD(id, 2)=1)
);

-- Таблица jams_tags
CREATE TABLE jams_tags (
    id SERIAL PRIMARY KEY,
    jam_id INTEGER,
    tag_id INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT jams_tags_jam_id_range CHECK (MOD(jam_id, 2)=1)
);

-- Таблица tags (реплицированная)
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Создание индексов
CREATE INDEX idx_jams_author_id ON jams USING btree (author_id);
CREATE INDEX idx_jams_tags_jam_id ON jams_tags USING btree (jam_id);
CREATE INDEX idx_jams_tags_tag_id ON jams_tags USING btree (tag_id);

-- Вставка тестовых данных для шарда 2 (джемы с нечетными ID)

-- Теги (реплицированные данные)
INSERT INTO tags (id, name, created_at, updated_at) VALUES 
(1, 'Action', NOW(), NOW()),
(2, 'Adventure', NOW(), NOW()),
(3, 'RPG', NOW(), NOW()),
(4, 'Strategy', NOW(), NOW()),
(5, 'Simulation', NOW(), NOW());

-- Джемы
INSERT INTO jams (id, name, author_id, created_at, updated_at, start_date, deadline, end_date, description) VALUES 
(1, 'A', 2, NOW(), NOW(), NOW(), NOW() + INTERVAL '7 days', NOW() + INTERVAL '14 days', 'Game Jam 1'),
(3, 'B', 4, NOW(), NOW(), NOW(), NOW() + INTERVAL '10 days', NOW() + INTERVAL '20 days', 'Game Jam 3'),
(5, 'C', 6, NOW(), NOW(), NOW(), NOW() + INTERVAL '5 days', NOW() + INTERVAL '10 days', 'Game Jam 5');

-- Связи джемов с тегами
INSERT INTO jams_tags (jam_id, tag_id, created_at, updated_at) VALUES 
(1, 1, NOW(), NOW()),
(1, 3, NOW(), NOW()),
(3, 2, NOW(), NOW()),
(3, 4, NOW(), NOW()),
(5, 3, NOW(), NOW()),
(5, 5, NOW(), NOW());

