-- Создание таблиц для домена "Игры" - Шард 2 (нечетные ID)

-- Таблица games
CREATE TABLE games (
    id SERIAL PRIMARY KEY,
    name VARCHAR(60),
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    author_id INTEGER,
    CONSTRAINT games_id_range CHECK (MOD(id, 2)=1)
);

-- Таблица game_tags
CREATE TABLE game_tags (
    id SERIAL PRIMARY KEY,
    game_id INTEGER,
    tag_id INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT game_tags_game_id_range CHECK (MOD(game_id, 2)=1)
);

-- Таблица tags (реплицированная)
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Создание индексов
CREATE INDEX idx_games_author_id ON games USING btree (author_id);
CREATE INDEX idx_game_tags_game_id ON game_tags USING btree (game_id);
CREATE INDEX idx_game_tags_tag_id ON game_tags USING btree (tag_id);

-- Вставка тестовых данных для шарда 2 (игры с нечетными ID)

-- Теги (реплицированные данные)
INSERT INTO tags (id, name, created_at, updated_at) VALUES 
(1, 'Action', NOW(), NOW()),
(2, 'Adventure', NOW(), NOW()),
(3, 'RPG', NOW(), NOW()),
(4, 'Strategy', NOW(), NOW()),
(5, 'Simulation', NOW(), NOW());

-- Игры
INSERT INTO games (id, name, description, created_at, updated_at, author_id) VALUES 
(1, 'Dragon Slayer', 'Slay dragons and save the kingdom', NOW(), NOW(), 2),
(3, 'Racing Champions', 'Become the ultimate racing champion', NOW(), NOW(), 4),
(5, 'Puzzle Master', 'Solve challenging puzzles', NOW(), NOW(), 6);

-- Связи игр с тегами
INSERT INTO game_tags (game_id, tag_id, created_at, updated_at) VALUES 
(1, 1, NOW(), NOW()),
(1, 3, NOW(), NOW()),
(3, 1, NOW(), NOW()),
(3, 5, NOW(), NOW()),
(5, 2, NOW(), NOW()),
(5, 4, NOW(), NOW());

