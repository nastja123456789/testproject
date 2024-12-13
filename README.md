# testproject

1. Диаграмма компонентов в PlantUML:
```
@startuml
[Клиент] --> [Веб-сервер]
note right of [Клиент]
  Задать/получить число
end note

[Веб-сервер] ..> [Сервер приложения]
note left of [Веб-сервер]
  Интерфейс для ввода данных и отправки их на сервер
end note
[Сервер приложения] ..> [База данных]
note right of [Сервер приложения]
  Выполнение логики - обращение к БД, отправка ответа веб-серверу
end note
note left of [База данных]
  Хранение чисел
end note
@enduml
```

2. Диаграмма последовательности в PlantUML:
```
@startuml
actor Клиент
participant "Веб-Сервер" as WS
participant "Сервер приложения" as AS
database "База Данных" as DB

Клиент -> WS : HTTP POST (число)
WS -> AS : Отправка числа
AS -> DB : Проверить, существует ли число
DB --> AS : Число существует? (Да/Нет)

alt Число существует
    AS -> WS : Отправить ошибку: "Число уже было отправлено"
    WS -> Клиент : HTTP 400 Bad Request
else Число не существует
    AS -> DB : Проверить последнее отправленное число
    DB --> AS : Последнее отправленное число
    alt Новое число валидно
        AS -> DB : Хранить (число + 1)
        DB --> AS : Число было сохранено
        AS -> WS : Вернуть (число + 1)
        WS -> Клиент : HTTP 200 OK (число + 1)
    else Новое число невалидно
        AS -> WS : Вернуть ошибку: "Невалидное число"
        WS -> Клиент : HTTP 400 Bad Request
    end
end

@enduml
```

3. Дополнение по пункту 3
- Фронтенд JS - фреймворк Vue
```
<template>
  <div id="app">
    <h1>Number Processor</h1>
    <input type="number" v-model="number" placeholder="Enter a natural number" />
    <button @click="sendNumber">Send Number</button>
    <p v-if="response">{{ response }}</p>
    <p v-if="error" style="color:red;">{{ error }}</p>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  data() {
    return {
      number: null,
      response: '',
      error: ''
    };
  },
  methods: {
    async sendNumber() {
      this.error = '';
      this.response = '';

      try {
        const res = await axios.post('http://localhost:5000/number', {
          number: this.number
        });
        this.response = res.data.result;
      } catch (err) {
        if (err.response) {
          this.error = err.response.data.error;
        } else {
          this.error = 'Ошибка отправки числа/получения ответа от сервера.';
        }
      }
    }
  }
};
</script>

<style>
#app {
  text-align: center;
  margin-top: 50px;
}
input {
  margin-right: 10px;
}
</style>
```
- Бекэнд Python - фреймворк Flask
```
from flask import Flask, request, jsonify
import mysql.connector
import logging

app = Flask(__name__)
app.config["JSON_SORT_KEYS"] = False

# Настройка логирования
logging.basicConfig(filename='app.log', level=logging.ERROR)

# Настройка подключения к базе данных
db_config = {
    'user': 'root',
    'password': 'user',
    'host': 'localhost',
    'database': 'test'
}

@app.route('/number', methods=['POST'])
def process_number():
    if not request.json or 'number' not in request.json:
        return jsonify({'error': 'Bad request: Число не указано.'}), 400

    incoming_number = request.json['number']

    if not isinstance(incoming_number, int) or incoming_number < 0:
        return jsonify({'error': 'Неправильный формат ввода числа - число не от 0 до N.'}), 400

    conn = mysql.connector.connect(**db_config)
    cursor = conn.cursor()

    try:
        # Проверка на уже поступившие числа
        cursor.execute("SELECT number FROM numbers WHERE number = %s", (incoming_number,))
        if cursor.fetchone() is not None:
            error_message = f"Ошибка: Число {incoming_number} уже было отправлено."
            logging.error(error_message)
            return jsonify({'error': error_message}), 400

        # Проверка на число на единицу меньше
        cursor.execute("SELECT number FROM numbers ORDER BY number DESC LIMIT 1")
        last_number = cursor.fetchone()

        if last_number is not None and incoming_number < last_number[0]:
            error_message = f"Ошибка: Число {incoming_number} меньше чем последнее отправленное число {last_number[0]}."
            logging.error(error_message)
            return jsonify({'error': error_message}), 400

        # Обработка запроса
        new_number = incoming_number + 1
        cursor.execute("INSERT INTO numbers (number) VALUES (%s)", (incoming_number,))
        conn.commit()

        return jsonify({'result': new_number}), 200

    except Exception as e:
        logging.error(f"Database error: {str(e)}")
        return jsonify({'error': 'Не может обработать число.'}), 500

    finally:
        cursor.close()
        conn.close()


if __name__ == '__main__':
    app.run(debug=True)
```
- БД Mariadb
```
CREATE DATABASE test;

USE test;

CREATE TABLE numbers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  number INT UNIQUE NOT NULL
);
```
