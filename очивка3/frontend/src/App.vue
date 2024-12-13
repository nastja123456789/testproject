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