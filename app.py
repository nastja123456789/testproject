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
