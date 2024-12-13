# Установка узлового образа
FROM node:14

# Установка рабочей директории
WORKDIR /app

# Копирование package.json и package-lock.json
COPY package.json package-lock.json ./

# Установка зависимостей
RUN npm install

# Копирование остальных файлов
COPY . .

# Установка и запуск приложения
CMD ["npm", "run", "serve"]