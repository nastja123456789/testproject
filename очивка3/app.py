from flask import Flask, request, jsonify
import mysql.connector
import logging
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
app.config["JSON_SORT_KEYS"] = False

# Настройка логирования
logging.basicConfig(filename='app.log', level=logging.DEBUG)

# Настройка подключения к базе данных
db_config = {
    'user': 'root',
    'password': 'user',
    'host': 'db',
    'database': 'test',
    'port': 3306
}

def create_table_if_not_exists():
    conn = mysql.connector.connect(**db_config)
    cursor = conn.cursor()
    try:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS numbers (
                id INT AUTO_INCREMENT PRIMARY KEY,
                number INT UNIQUE NOT NULL
            );
        """)
        conn.commit()
    except Exception as e:
        logging.error(f"Ошибка при создании таблицы: {str(e)}")
    finally:
        cursor.close()
        conn.close()

@app.route('/test-db', methods=['GET'])
def test_db():
    try:
        # Подключение к базе данных
        create_table_if_not_exists()
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()

        # Получение имени базы данных
        cursor.execute("SELECT DATABASE();")
        database_name = cursor.fetchone()[0]

        # Получение последних чисел из таблицы numbers
        cursor.execute("SELECT number FROM numbers ORDER BY number DESC;")
        numbers = cursor.fetchall()

        # Форматирование списка чисел
        numbers_list = [number[0] for number in numbers]

        return jsonify({
            'database': database_name,
            'numbers': numbers_list
        }), 200

    except Exception as e:
        logging.error(f"Ошибка при обращении к базе данных: {str(e)}")
        return jsonify({'error': str(e)}), 500

    finally:
        # Закрытие курсора и соединения
        if cursor:
            cursor.close()
        if conn:
            conn.close()


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
        logging.debug("Проверка на существование числа...")
        cursor.execute("SELECT number FROM numbers WHERE number = %s", (incoming_number,))
        if cursor.fetchone() is not None:
            error_message = f"Ошибка: Число {incoming_number} уже было отправлено."
            logging.error(error_message)
            return jsonify({'error': error_message}), 400
        
        logging.debug("Проверка последнего числа...")
        cursor.execute("SELECT number FROM numbers ORDER BY number DESC LIMIT 1")
        last_number = cursor.fetchone()
        if last_number is not None and incoming_number < last_number[0]:
            error_message = f"Ошибка: Число {incoming_number} меньше чем последнее отправленное число {last_number[0]}."
            logging.error(error_message)
            return jsonify({'error': error_message}), 400
        
        logging.debug("Вставка нового числа...")
        cursor.execute("INSERT INTO numbers (number) VALUES (%s)", (incoming_number,))
        conn.commit()
        
        return jsonify({'result': incoming_number + 1}), 200
    
    except Exception as e:
        logging.error(f"Database error: {str(e)}")
        return jsonify({'error': 'Не может обработать число.'}), 500
    
    finally:
        cursor.close()
        conn.close()


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
