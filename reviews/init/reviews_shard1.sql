-- Создание таблиц для домена "Отзывы" - Шард 1 (четные ID пользователей)

-- Таблица reviews
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    user_mark DECIMAL(2,1) CHECK (
      user_mark IN (0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5)
    ),
    criterion VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    game_id INTEGER,
    jam_id INTEGER,
    CONSTRAINT reviews_user_id_range CHECK (MOD(user_id, 2)=0)
);

-- Создание индексов
CREATE INDEX idx_reviews_user_id ON reviews USING btree (user_id);
CREATE INDEX idx_reviews_game_id ON reviews USING btree (game_id);
CREATE INDEX idx_reviews_jam_id ON reviews USING btree (jam_id);

-- Вставка тестовых данных для шарда 1 (отзывы пользователей с четными ID)

-- Отзывы
INSERT INTO reviews (user_id, user_mark, criterion, created_at, updated_at, game_id, jam_id) VALUES 
(2, 4.5, 'Gameplay', NOW(), NOW(), 1, NULL),
(2, 4.0, 'Graphics', NOW(), NOW(), 3, NULL),
(4, 4.5, 'Story', NOW(), NOW(), 5, NULL),
(4, 4.5, 'Sound', NOW(), NOW(), NULL, 1),
(6, 3.5, 'Difficulty', NOW(), NOW(), NULL, 3);

