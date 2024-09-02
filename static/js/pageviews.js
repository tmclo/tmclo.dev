const statsUrl = '/stats';

async function fetchStats() {
  try {
    const response = await fetch(statsUrl + window.location.pathname);
    const data = await response.json();
    document.getElementById('stats-count-number').textContent = data.count;
  } catch (error) {
    console.error('Error fetching stats:', error);
  }
}

// Call the fetchStats function when the page is loaded
document.addEventListener('DOMContentLoaded', fetchStats);