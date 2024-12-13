# Use a slim base image to reduce image size
FROM python:3.9-slim-buster

# Set environment variables (better than hardcoding in the app)
ENV MYSQL_USER=root
ENV MYSQL_PASSWORD=user
ENV MYSQL_HOST=localhost
ENV MYSQL_DATABASE=test
ENV MYSQL_PORT=3306

# Set working directory
WORKDIR /app

# Copy the requirements file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY . .

# Expose the port the app listens on
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]
