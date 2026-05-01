import App from './App.svelte';

const target = document.getElementById('app');

if (!target) {
  throw new Error('missing #app target');
}

new App({ target });
